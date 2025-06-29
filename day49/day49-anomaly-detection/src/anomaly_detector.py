import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from scipy import stats
from datetime import datetime, timedelta
import json
import logging
from typing import Dict, List, Tuple, Optional
import threading
import time

class AnomalyDetector:
    def __init__(self):
        self.isolation_forest = IsolationForest(contamination=0.1, random_state=42)
        self.scaler = StandardScaler()
        self.models_trained = False
        self.baseline_stats = {}
        self.temporal_patterns = {}
        self.confidence_threshold = 0.7
        self.sliding_window = []
        self.window_size = 100
        self.lock = threading.Lock()
        
    def extract_features(self, log_entry: Dict) -> np.ndarray:
        """Extract numerical features from log entry for anomaly detection"""
        features = []
        
        # Temporal features
        timestamp = datetime.fromisoformat(log_entry.get('timestamp', datetime.now().isoformat()))
        features.extend([
            timestamp.hour,
            timestamp.weekday(),
            timestamp.minute
        ])
        
        # Numerical features
        features.append(log_entry.get('response_time', 0))
        features.append(log_entry.get('status_code', 200))
        features.append(log_entry.get('bytes_sent', 0))
        features.append(len(log_entry.get('user_agent', '')))
        features.append(len(log_entry.get('ip_address', '').split('.')))
        
        # Session features (if available from previous sessionization)
        features.append(log_entry.get('session_duration', 0))
        features.append(log_entry.get('page_views', 1))
        
        # Ensure exactly 9 features
        features = features[:9]
        while len(features) < 9:
            features.append(0)
        
        return np.array(features).reshape(1, -1)
    
    def z_score_detection(self, features: np.ndarray) -> Tuple[bool, float]:
        """Detect anomalies using z-score method"""
        if len(self.sliding_window) < 10:
            return False, 0.0
            
        window_data = np.array(self.sliding_window)
        mean = np.mean(window_data, axis=0)
        std = np.std(window_data, axis=0)
        
        # Avoid division by zero
        std = np.where(std == 0, 1, std)
        z_scores = np.abs((features[0] - mean) / std)
        max_z_score = np.max(z_scores)
        
        is_anomaly = bool(max_z_score > 3.0)
        confidence = min(max_z_score / 3.0, 1.0)
        
        return is_anomaly, confidence
    
    def isolation_forest_detection(self, features: np.ndarray) -> Tuple[bool, float]:
        """Detect anomalies using Isolation Forest"""
        if not self.models_trained:
            return False, 0.0
            
        try:
            scaled_features = self.scaler.transform(features)
            anomaly_score = self.isolation_forest.decision_function(scaled_features)[0]
            prediction = self.isolation_forest.predict(scaled_features)[0]
            
            is_anomaly = prediction == -1
            confidence = abs(anomaly_score)
            
            return is_anomaly, confidence
        except Exception as e:
            logging.error(f"Isolation forest detection error: {e}")
            return False, 0.0
    
    def temporal_pattern_detection(self, log_entry: Dict) -> Tuple[bool, float]:
        """Detect temporal anomalies based on historical patterns"""
        timestamp = datetime.fromisoformat(log_entry.get('timestamp', datetime.now().isoformat()))
        hour_key = timestamp.hour
        weekday_key = timestamp.weekday()
        
        pattern_key = f"{weekday_key}_{hour_key}"
        
        if pattern_key not in self.temporal_patterns:
            self.temporal_patterns[pattern_key] = []
        
        response_time = log_entry.get('response_time', 0)
        
        if len(self.temporal_patterns[pattern_key]) < 5:
            self.temporal_patterns[pattern_key].append(response_time)
            return False, 0.0
        
        historical_times = self.temporal_patterns[pattern_key]
        mean_time = np.mean(historical_times)
        std_time = np.std(historical_times)
        
        if std_time == 0:
            return False, 0.0
        
        z_score = abs((response_time - mean_time) / std_time)
        is_anomaly = bool(z_score > 2.5)
        confidence = min(z_score / 2.5, 1.0)
        
        # Update patterns (keep last 50 entries)
        self.temporal_patterns[pattern_key].append(response_time)
        if len(self.temporal_patterns[pattern_key]) > 50:
            self.temporal_patterns[pattern_key].pop(0)
        
        return is_anomaly, confidence
    
    def train_models(self, historical_data: List[Dict]):
        """Train anomaly detection models on historical data"""
        if len(historical_data) < 50:
            logging.warning("Insufficient data for model training")
            return
        
        with self.lock:
            features_list = []
            for entry in historical_data:
                features = self.extract_features(entry)
                features_list.append(features[0])
            
            X = np.array(features_list)
            
            # Train scaler
            self.scaler.fit(X)
            X_scaled = self.scaler.transform(X)
            
            # Train isolation forest
            self.isolation_forest.fit(X_scaled)
            
            # Initialize sliding window
            self.sliding_window = features_list[-self.window_size:]
            
            self.models_trained = True
            logging.info(f"Models trained on {len(historical_data)} samples")
    
    def detect_anomaly(self, log_entry: Dict) -> Dict:
        """Detect anomalies using ensemble of methods"""
        features = self.extract_features(log_entry)
        
        with self.lock:
            # Z-score detection
            zscore_anomaly, zscore_confidence = self.z_score_detection(features)
            
            # Isolation forest detection
            isolation_anomaly, isolation_confidence = self.isolation_forest_detection(features)
            
            # Temporal pattern detection
            temporal_anomaly, temporal_confidence = self.temporal_pattern_detection(log_entry)
            
            # Ensemble decision
            anomaly_indicators = [zscore_anomaly, isolation_anomaly, temporal_anomaly]
            confidences = [zscore_confidence, isolation_confidence, temporal_confidence]
            
            # Weighted ensemble (isolation forest gets higher weight)
            weights = [0.3, 0.5, 0.2]
            ensemble_confidence = sum(w * c for w, c in zip(weights, confidences))
            ensemble_anomaly = bool(sum(anomaly_indicators) >= 2 or ensemble_confidence > self.confidence_threshold)
            
            # Update sliding window
            if len(self.sliding_window) >= self.window_size:
                self.sliding_window.pop(0)
            self.sliding_window.append(features[0])
            
            result = {
                'is_anomaly': ensemble_anomaly,
                'confidence': ensemble_confidence,
                'methods': {
                    'zscore': {'anomaly': zscore_anomaly, 'confidence': zscore_confidence},
                    'isolation_forest': {'anomaly': isolation_anomaly, 'confidence': isolation_confidence},
                    'temporal': {'anomaly': temporal_anomaly, 'confidence': temporal_confidence}
                },
                'timestamp': log_entry.get('timestamp'),
                'log_entry': log_entry
            }
            
            return result

# Global detector instance
detector = AnomalyDetector()
