import pytest
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.anomaly_detector import AnomalyDetector
from src.log_generator import LogGenerator
import numpy as np
from datetime import datetime

class TestAnomalyDetector:
    def setup_method(self):
        self.detector = AnomalyDetector()
        self.generator = LogGenerator()
    
    def test_feature_extraction(self):
        """Test feature extraction from log entries"""
        log = self.generator.generate_normal_log()
        features = self.detector.extract_features(log)
        
        assert features.shape == (1, 9)  # Expected 9 features
        assert all(isinstance(f, (int, float)) for f in features[0])
    
    def test_zscore_detection(self):
        """Test z-score anomaly detection"""
        # Generate normal logs to build baseline
        for _ in range(20):
            log = self.generator.generate_normal_log()
            features = self.detector.extract_features(log)
            self.detector.sliding_window.append(features[0])
        
        # Test normal log
        normal_log = self.generator.generate_normal_log()
        normal_features = self.detector.extract_features(normal_log)
        is_anomaly, confidence = self.detector.z_score_detection(normal_features)
        
        assert isinstance(is_anomaly, bool)
        assert 0 <= confidence <= 1
    
    def test_model_training(self):
        """Test model training with historical data"""
        historical_data = []
        for _ in range(100):
            log = self.generator.generate_normal_log()
            historical_data.append(log)
        
        self.detector.train_models(historical_data)
        
        assert self.detector.models_trained
        assert len(self.detector.sliding_window) > 0
    
    def test_anomaly_detection_ensemble(self):
        """Test ensemble anomaly detection"""
        # Train with normal data
        historical_data = []
        for _ in range(100):
            log = self.generator.generate_normal_log()
            historical_data.append(log)
        
        self.detector.train_models(historical_data)
        
        # Test normal log
        normal_log = self.generator.generate_normal_log()
        result = self.detector.detect_anomaly(normal_log)
        
        assert 'is_anomaly' in result
        assert 'confidence' in result
        assert 'methods' in result
        assert isinstance(result['is_anomaly'], bool)
        assert 0 <= result['confidence'] <= 1
    
    def test_temporal_pattern_detection(self):
        """Test temporal pattern anomaly detection"""
        # Generate logs for pattern building
        for _ in range(10):
            log = self.generator.generate_normal_log()
            self.detector.temporal_pattern_detection(log)
        
        # Test with normal log
        normal_log = self.generator.generate_normal_log()
        is_anomaly, confidence = self.detector.temporal_pattern_detection(normal_log)
        
        assert isinstance(is_anomaly, bool)
        assert 0 <= confidence <= 1

if __name__ == '__main__':
    pytest.main([__file__])
