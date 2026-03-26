#!/bin/bash

set -e

echo "🚀 Day 158: User Behavior Analytics System - Complete Setup"
echo "=========================================================="

PROJECT_DIR="uba-system"

# Clean previous installation
if [ -d "$PROJECT_DIR" ]; then
    echo "📁 Removing existing project directory..."
    rm -rf "$PROJECT_DIR"
fi

# Create project structure
echo "📁 Creating project structure..."
mkdir -p "$PROJECT_DIR"/{src/{feature_extraction,detection,api,web},tests,config,docker,data,logs}
cd "$PROJECT_DIR"

# Create requirements.txt
cat > requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn==0.30.1
scikit-learn==1.5.0
numpy==1.26.4
pandas==2.2.2
redis==5.0.4
psycopg2-binary==2.9.9
pydantic==2.7.3
pytest==8.2.2
pytest-asyncio==0.23.7
httpx==0.27.0
python-dateutil==2.9.0
faker==25.3.0
aiofiles==23.2.1
requests==2.31.0
EOF

# Create config
cat > config/config.yaml << 'EOF'
uba:
  baseline_days: 14
  risk_threshold_warning: 60
  risk_threshold_critical: 80
  
detection:
  zscore_threshold: 3.0
  isolation_forest_contamination: 0.1
  ensemble_weights:
    zscore: 0.4
    isolation_forest: 0.4
    temporal: 0.2

features:
  - login_frequency
  - access_count
  - data_volume
  - failed_attempts
  - session_duration
  - geographic_entropy
  - time_of_day_score
  - resource_diversity

database:
  host: localhost
  port: 5432
  name: uba_db
  
redis:
  host: localhost
  port: 6379
  db: 0
EOF

# Create feature extraction - log parser
cat > src/feature_extraction/log_parser.py << 'EOF'
"""Parse security logs and extract raw events"""
import json
from datetime import datetime
from typing import Dict, Any, List
import re

class LogParser:
    """Parse authentication and access logs"""
    
    def __init__(self):
        self.event_types = {
            'login': r'user\s+(\w+)\s+logged\s+in',
            'access': r'user\s+(\w+)\s+accessed\s+(\S+)',
            'download': r'user\s+(\w+)\s+downloaded\s+(\d+)\s+bytes',
            'failed_login': r'failed\s+login\s+for\s+user\s+(\w+)'
        }
    
    def parse(self, log_entry: str) -> Dict[str, Any]:
        """Parse a single log entry"""
        timestamp = datetime.now()
        user = None
        event_type = 'unknown'
        details = {}
        
        # Try to match known patterns
        for evt_type, pattern in self.event_types.items():
            match = re.search(pattern, log_entry, re.IGNORECASE)
            if match:
                event_type = evt_type
                user = match.group(1)
                
                if evt_type == 'access':
                    details['resource'] = match.group(2)
                elif evt_type == 'download':
                    details['bytes'] = int(match.group(2))
                
                break
        
        return {
            'timestamp': timestamp.isoformat(),
            'user': user,
            'event_type': event_type,
            'details': details,
            'raw': log_entry
        }
    
    def parse_structured(self, log_dict: Dict[str, Any]) -> Dict[str, Any]:
        """Parse structured log entry"""
        return {
            'timestamp': log_dict.get('timestamp', datetime.now().isoformat()),
            'user': log_dict.get('user'),
            'event_type': log_dict.get('event_type', 'unknown'),
            'details': log_dict.get('details', {}),
            'ip_address': log_dict.get('ip_address'),
            'session_id': log_dict.get('session_id')
        }
EOF

# Create feature engine
cat > src/feature_extraction/feature_engine.py << 'EOF'
"""Extract behavioral features from parsed logs"""
from typing import Dict, Any, List
from datetime import datetime, timedelta
from collections import Counter, defaultdict
import numpy as np

class FeatureEngine:
    """Extract user behavioral features"""
    
    def __init__(self):
        self.user_history = defaultdict(list)
        
    def add_event(self, user: str, event: Dict[str, Any]):
        """Add event to user history"""
        self.user_history[user].append(event)
        
        # Keep only last 30 days
        cutoff = datetime.now() - timedelta(days=30)
        self.user_history[user] = [
            e for e in self.user_history[user]
            if datetime.fromisoformat(e['timestamp']) > cutoff
        ]
    
    def extract_features(self, user: str, current_event: Dict[str, Any]) -> Dict[str, float]:
        """Extract behavioral feature vector"""
        history = self.user_history.get(user, [])
        
        features = {
            'login_frequency': self._login_frequency(history),
            'access_count': self._access_count(history),
            'data_volume': self._data_volume(history),
            'failed_attempts': self._failed_attempts(history),
            'session_duration': self._session_duration(current_event, history),
            'geographic_entropy': self._geographic_entropy(history),
            'time_of_day_score': self._time_of_day_score(current_event),
            'resource_diversity': self._resource_diversity(history),
            'hourly_access_rate': self._hourly_access_rate(history),
            'weekend_activity': self._weekend_activity(history)
        }
        
        return features
    
    def _login_frequency(self, history: List[Dict]) -> float:
        """Count logins per day"""
        logins = [e for e in history if e['event_type'] == 'login']
        if not logins:
            return 0.0
        
        days = (datetime.now() - datetime.fromisoformat(logins[0]['timestamp'])).days + 1
        return len(logins) / max(days, 1)
    
    def _access_count(self, history: List[Dict]) -> float:
        """Count resource accesses per day"""
        accesses = [e for e in history if e['event_type'] == 'access']
        if not accesses:
            return 0.0
        
        days = (datetime.now() - datetime.fromisoformat(accesses[0]['timestamp'])).days + 1
        return len(accesses) / max(days, 1)
    
    def _data_volume(self, history: List[Dict]) -> float:
        """Average bytes downloaded per day"""
        downloads = [e for e in history if e['event_type'] == 'download']
        if not downloads:
            return 0.0
        
        total_bytes = sum(e['details'].get('bytes', 0) for e in downloads)
        days = (datetime.now() - datetime.fromisoformat(downloads[0]['timestamp'])).days + 1
        return total_bytes / max(days, 1)
    
    def _failed_attempts(self, history: List[Dict]) -> float:
        """Count failed login attempts"""
        failed = [e for e in history if e['event_type'] == 'failed_login']
        return float(len(failed))
    
    def _session_duration(self, current_event: Dict, history: List[Dict]) -> float:
        """Estimate session duration in minutes"""
        if current_event.get('session_id'):
            session_events = [
                e for e in history 
                if e.get('session_id') == current_event['session_id']
            ]
            if len(session_events) >= 2:
                start = datetime.fromisoformat(session_events[0]['timestamp'])
                end = datetime.fromisoformat(session_events[-1]['timestamp'])
                return (end - start).total_seconds() / 60
        return 30.0  # Default 30 minutes
    
    def _geographic_entropy(self, history: List[Dict]) -> float:
        """Calculate geographic diversity (entropy)"""
        ips = [e.get('ip_address') for e in history if e.get('ip_address')]
        if not ips:
            return 0.0
        
        # Simple entropy calculation
        ip_counts = Counter(ips)
        total = len(ips)
        entropy = -sum((count/total) * np.log2(count/total) for count in ip_counts.values())
        return entropy
    
    def _time_of_day_score(self, event: Dict) -> float:
        """Score based on time of day (0-23 hours)"""
        timestamp = datetime.fromisoformat(event['timestamp'])
        hour = timestamp.hour
        
        # Normal business hours (9-17) score lower
        if 9 <= hour <= 17:
            return 10.0
        # Evening (18-22) slightly higher
        elif 18 <= hour <= 22:
            return 30.0
        # Late night (23-5) high score
        else:
            return 80.0
    
    def _resource_diversity(self, history: List[Dict]) -> float:
        """Count unique resources accessed"""
        resources = set()
        for e in history:
            if e['event_type'] == 'access':
                resource = e['details'].get('resource')
                if resource:
                    resources.add(resource)
        return float(len(resources))
    
    def _hourly_access_rate(self, history: List[Dict]) -> float:
        """Accesses per hour (recent 24 hours)"""
        cutoff = datetime.now() - timedelta(hours=24)
        recent = [
            e for e in history
            if datetime.fromisoformat(e['timestamp']) > cutoff
        ]
        return float(len(recent))
    
    def _weekend_activity(self, history: List[Dict]) -> float:
        """Percentage of activity on weekends"""
        if not history:
            return 0.0
        
        weekend_events = sum(
            1 for e in history
            if datetime.fromisoformat(e['timestamp']).weekday() >= 5
        )
        return (weekend_events / len(history)) * 100
EOF

# Create baseline manager
cat > src/feature_extraction/baseline_manager.py << 'EOF'
"""Manage user behavioral baselines"""
from typing import Dict, Any, List
import numpy as np
from collections import defaultdict
import json

class BaselineManager:
    """Manage and update user baselines"""
    
    def __init__(self):
        self.baselines = defaultdict(lambda: {
            'mean': {},
            'std': {},
            'min': {},
            'max': {},
            'sample_count': 0
        })
    
    def update_baseline(self, user: str, features: Dict[str, float]):
        """Update baseline with new feature observation"""
        baseline = self.baselines[user]
        n = baseline['sample_count']
        
        for feature, value in features.items():
            if feature not in baseline['mean']:
                baseline['mean'][feature] = value
                baseline['std'][feature] = 0.0
                baseline['min'][feature] = value
                baseline['max'][feature] = value
            else:
                # Online mean and variance update
                old_mean = baseline['mean'][feature]
                baseline['mean'][feature] = old_mean + (value - old_mean) / (n + 1)
                
                # Welford's online algorithm for variance
                if n > 0:
                    old_std = baseline['std'][feature]
                    baseline['std'][feature] = np.sqrt(
                        (n * old_std**2 + (value - old_mean) * (value - baseline['mean'][feature])) / (n + 1)
                    )
                
                baseline['min'][feature] = min(baseline['min'][feature], value)
                baseline['max'][feature] = max(baseline['max'][feature], value)
        
        baseline['sample_count'] = n + 1
    
    def get_baseline(self, user: str) -> Dict[str, Any]:
        """Get baseline statistics for user"""
        return self.baselines.get(user, {})
    
    def is_trained(self, user: str, min_samples: int = 100) -> bool:
        """Check if baseline is sufficiently trained"""
        baseline = self.baselines.get(user)
        return baseline and baseline['sample_count'] >= min_samples
    
    def save(self, filepath: str):
        """Save baselines to file"""
        with open(filepath, 'w') as f:
            json.dump(dict(self.baselines), f, indent=2)
    
    def load(self, filepath: str):
        """Load baselines from file"""
        try:
            with open(filepath, 'r') as f:
                loaded = json.load(f)
                self.baselines = defaultdict(lambda: {
                    'mean': {}, 'std': {}, 'min': {}, 'max': {}, 'sample_count': 0
                }, loaded)
        except FileNotFoundError:
            pass
EOF

# Create Z-score detector
cat > src/detection/zscore_detector.py << 'EOF'
"""Statistical anomaly detection using Z-scores"""
from typing import Dict, Any, List, Tuple
import numpy as np

class ZScoreDetector:
    """Detect anomalies using statistical Z-scores"""
    
    def __init__(self, threshold: float = 3.0):
        self.threshold = threshold
    
    def detect(self, features: Dict[str, float], baseline: Dict[str, Any]) -> Tuple[float, List[str]]:
        """
        Detect anomalies in features
        Returns: (anomaly_score, list_of_anomalous_features)
        """
        if not baseline or not baseline.get('mean'):
            return 0.0, []
        
        anomalies = []
        z_scores = []
        
        for feature, value in features.items():
            mean = baseline['mean'].get(feature, value)
            std = baseline['std'].get(feature, 0.0)
            
            if std > 0:
                z_score = abs((value - mean) / std)
                z_scores.append(z_score)
                
                if z_score > self.threshold:
                    anomalies.append(f"{feature} (z={z_score:.2f})")
        
        # Aggregate score: percentage of anomalous features
        if z_scores:
            # Max Z-score normalized to 0-100
            max_z = max(z_scores)
            score = min(100, (max_z / self.threshold) * 50)
            return score, anomalies
        
        return 0.0, []
    
    def get_details(self, features: Dict[str, float], baseline: Dict[str, Any]) -> Dict[str, Any]:
        """Get detailed Z-score analysis"""
        details = {}
        
        for feature, value in features.items():
            mean = baseline['mean'].get(feature, value)
            std = baseline['std'].get(feature, 0.0)
            
            z_score = abs((value - mean) / std) if std > 0 else 0.0
            
            details[feature] = {
                'value': value,
                'mean': mean,
                'std': std,
                'z_score': z_score,
                'is_anomaly': z_score > self.threshold
            }
        
        return details
EOF

# Create Isolation Forest detector
cat > src/detection/isolation_forest_detector.py << 'EOF'
"""Anomaly detection using Isolation Forest algorithm"""
from typing import Dict, Any, List, Tuple
import numpy as np
from sklearn.ensemble import IsolationForest

class IsolationForestDetector:
    """Detect multi-dimensional anomalies using Isolation Forest"""
    
    def __init__(self, contamination: float = 0.1):
        self.contamination = contamination
        self.models = {}  # Per-user models
        self.feature_names = []
    
    def train(self, user: str, historical_features: List[Dict[str, float]]):
        """Train isolation forest on historical data"""
        if len(historical_features) < 10:
            return  # Need minimum data
        
        # Extract feature matrix
        self.feature_names = list(historical_features[0].keys())
        X = np.array([
            [f.get(fname, 0.0) for fname in self.feature_names]
            for f in historical_features
        ])
        
        # Train model
        model = IsolationForest(
            contamination=self.contamination,
            random_state=42,
            n_estimators=100
        )
        model.fit(X)
        self.models[user] = model
    
    def detect(self, user: str, features: Dict[str, float]) -> Tuple[float, List[str]]:
        """
        Detect anomaly for user
        Returns: (anomaly_score, affected_features)
        """
        if user not in self.models:
            return 0.0, []
        
        model = self.models[user]
        
        # Prepare feature vector
        X = np.array([[features.get(fname, 0.0) for fname in self.feature_names]])
        
        # Get prediction (-1 for anomaly, 1 for normal)
        prediction = model.predict(X)[0]
        
        # Get anomaly score (lower is more anomalous)
        decision_score = model.decision_function(X)[0]
        
        # Normalize to 0-100 scale
        # decision_score ranges roughly from -0.5 to 0.5
        # Anomalies have negative scores
        if prediction == -1:
            score = min(100, abs(decision_score) * 100)
            
            # Identify most anomalous features
            anomalous_features = self._identify_anomalous_features(features)
            return score, anomalous_features
        
        return 0.0, []
    
    def _identify_anomalous_features(self, features: Dict[str, float]) -> List[str]:
        """Identify which features contribute most to anomaly"""
        # Simplified: return top 3 extreme features
        sorted_features = sorted(
            features.items(),
            key=lambda x: abs(x[1]),
            reverse=True
        )
        return [f[0] for f in sorted_features[:3]]
EOF

# Create temporal detector
cat > src/detection/temporal_detector.py << 'EOF'
"""Temporal pattern anomaly detection"""
from typing import Dict, Any, List, Tuple
from datetime import datetime
from collections import defaultdict
import numpy as np

class TemporalDetector:
    """Detect time-based behavioral anomalies"""
    
    def __init__(self):
        self.temporal_patterns = defaultdict(lambda: {
            'hourly_counts': defaultdict(int),
            'daily_counts': defaultdict(int),
            'weekday_counts': defaultdict(int)
        })
    
    def learn_pattern(self, user: str, timestamp: str):
        """Learn user's temporal access patterns"""
        dt = datetime.fromisoformat(timestamp)
        patterns = self.temporal_patterns[user]
        
        patterns['hourly_counts'][dt.hour] += 1
        patterns['daily_counts'][dt.day] += 1
        patterns['weekday_counts'][dt.weekday()] += 1
    
    def detect(self, user: str, timestamp: str) -> Tuple[float, List[str]]:
        """
        Detect temporal anomalies
        Returns: (anomaly_score, reasons)
        """
        if user not in self.temporal_patterns:
            return 0.0, []
        
        dt = datetime.fromisoformat(timestamp)
        patterns = self.temporal_patterns[user]
        
        anomalies = []
        scores = []
        
        # Check hour anomaly
        hour_score = self._check_hour_anomaly(dt.hour, patterns['hourly_counts'])
        if hour_score > 50:
            anomalies.append(f"Unusual hour: {dt.hour}:00")
            scores.append(hour_score)
        
        # Check weekday anomaly
        weekday_score = self._check_weekday_anomaly(dt.weekday(), patterns['weekday_counts'])
        if weekday_score > 50:
            day_name = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday()]
            anomalies.append(f"Unusual day: {day_name}")
            scores.append(weekday_score)
        
        # Return max score
        final_score = max(scores) if scores else 0.0
        return final_score, anomalies
    
    def _check_hour_anomaly(self, hour: int, hourly_counts: Dict[int, int]) -> float:
        """Check if hour is anomalous"""
        if not hourly_counts:
            return 0.0
        
        count = hourly_counts.get(hour, 0)
        avg_count = np.mean(list(hourly_counts.values()))
        
        # If this hour has never been seen before
        if count == 0:
            return 90.0
        
        # If significantly below average
        if count < avg_count * 0.1:
            return 70.0
        
        return 0.0
    
    def _check_weekday_anomaly(self, weekday: int, weekday_counts: Dict[int, int]) -> float:
        """Check if weekday is anomalous"""
        if not weekday_counts:
            return 0.0
        
        count = weekday_counts.get(weekday, 0)
        avg_count = np.mean(list(weekday_counts.values()))
        
        # Weekend vs weekday pattern
        is_weekend = weekday >= 5
        weekend_avg = np.mean([weekday_counts.get(5, 0), weekday_counts.get(6, 0)])
        weekday_avg = np.mean([weekday_counts.get(i, 0) for i in range(5)])
        
        if count == 0:
            return 80.0
        
        if is_weekend and weekday_avg > 0 and weekend_avg < weekday_avg * 0.1:
            return 70.0
        
        return 0.0
EOF

# Create ensemble scorer
cat > src/detection/ensemble_scorer.py << 'EOF'
"""Ensemble scoring combining multiple detectors"""
from typing import Dict, Any, List, Tuple

class EnsembleScorer:
    """Combine multiple detector outputs into final risk score"""
    
    def __init__(self, weights: Dict[str, float] = None):
        self.weights = weights or {
            'zscore': 0.4,
            'isolation_forest': 0.4,
            'temporal': 0.2
        }
    
    def compute_score(self, detector_scores: Dict[str, Tuple[float, List[str]]]) -> Dict[str, Any]:
        """
        Combine detector scores
        detector_scores: {'detector_name': (score, anomalies)}
        """
        weighted_score = 0.0
        all_anomalies = []
        details = {}
        
        for detector, (score, anomalies) in detector_scores.items():
            weight = self.weights.get(detector, 0.33)
            weighted_score += score * weight
            all_anomalies.extend(anomalies)
            
            details[detector] = {
                'score': score,
                'weight': weight,
                'anomalies': anomalies
            }
        
        # Determine risk level
        risk_level = self._classify_risk(weighted_score)
        
        return {
            'final_score': round(weighted_score, 2),
            'risk_level': risk_level,
            'anomalies': all_anomalies,
            'detector_details': details
        }
    
    def _classify_risk(self, score: float) -> str:
        """Classify risk level based on score"""
        if score >= 80:
            return 'critical'
        elif score >= 60:
            return 'high'
        elif score >= 40:
            return 'medium'
        elif score >= 20:
            return 'low'
        return 'normal'
EOF

# Create UBA service
cat > src/api/uba_service.py << 'EOF'
"""Main UBA service API"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Dict, Any, Optional, List
from datetime import datetime
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from feature_extraction.log_parser import LogParser
from feature_extraction.feature_engine import FeatureEngine
from feature_extraction.baseline_manager import BaselineManager
from detection.zscore_detector import ZScoreDetector
from detection.isolation_forest_detector import IsolationForestDetector
from detection.temporal_detector import TemporalDetector
from detection.ensemble_scorer import EnsembleScorer

app = FastAPI(title="User Behavior Analytics Service")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize components
log_parser = LogParser()
feature_engine = FeatureEngine()
baseline_manager = BaselineManager()
zscore_detector = ZScoreDetector(threshold=3.0)
isolation_detector = IsolationForestDetector(contamination=0.1)
temporal_detector = TemporalDetector()
ensemble_scorer = EnsembleScorer()

# Storage
user_risk_scores = {}
alerts = []

class LogEntry(BaseModel):
    user: str
    event_type: str
    timestamp: Optional[str] = None
    details: Optional[Dict[str, Any]] = {}
    ip_address: Optional[str] = None
    session_id: Optional[str] = None

class AnomalyResult(BaseModel):
    user: str
    risk_score: float
    risk_level: str
    anomalies: List[str]
    timestamp: str

@app.get("/")
async def root():
    return {
        "service": "User Behavior Analytics",
        "version": "1.0.0",
        "status": "operational"
    }

@app.post("/api/analyze")
async def analyze_behavior(log_entry: LogEntry):
    """Analyze user behavior from log entry"""
    
    # Parse log
    event = log_parser.parse_structured(log_entry.dict())
    user = event['user']
    
    if not user:
        raise HTTPException(status_code=400, detail="User required")
    
    # Add to history
    feature_engine.add_event(user, event)
    
    # Learn temporal patterns
    temporal_detector.learn_pattern(user, event['timestamp'])
    
    # Extract features
    features = feature_engine.extract_features(user, event)
    
    # Update baseline (in training mode)
    baseline_manager.update_baseline(user, features)
    baseline = baseline_manager.get_baseline(user)
    
    # Run detectors if baseline is trained
    if baseline_manager.is_trained(user, min_samples=50):
        # Z-score detection
        zscore_score, zscore_anomalies = zscore_detector.detect(features, baseline)
        
        # Temporal detection
        temporal_score, temporal_anomalies = temporal_detector.detect(user, event['timestamp'])
        
        # Combine scores
        detector_scores = {
            'zscore': (zscore_score, zscore_anomalies),
            'temporal': (temporal_score, temporal_anomalies)
        }
        
        result = ensemble_scorer.compute_score(detector_scores)
        
        # Store risk score
        user_risk_scores[user] = result
        
        # Generate alert if high risk
        if result['risk_level'] in ['high', 'critical']:
            alert = {
                'timestamp': datetime.now().isoformat(),
                'user': user,
                'risk_score': result['final_score'],
                'risk_level': result['risk_level'],
                'anomalies': result['anomalies']
            }
            alerts.append(alert)
        
        return {
            "user": user,
            "risk_score": result['final_score'],
            "risk_level": result['risk_level'],
            "anomalies": result['anomalies'],
            "features": features,
            "baseline_trained": True
        }
    else:
        # Still in baseline learning phase
        return {
            "user": user,
            "risk_score": 0,
            "risk_level": "learning",
            "message": f"Building baseline ({baseline['sample_count']}/50 samples)",
            "features": features,
            "baseline_trained": False
        }

@app.get("/api/users/{user}/risk-score")
async def get_user_risk(user: str):
    """Get current risk score for user"""
    if user in user_risk_scores:
        return user_risk_scores[user]
    return {"user": user, "risk_score": 0, "risk_level": "unknown"}

@app.get("/api/alerts")
async def get_alerts(limit: int = 10):
    """Get recent alerts"""
    return {"alerts": alerts[-limit:], "total": len(alerts)}

@app.get("/api/stats")
async def get_stats():
    """Get system statistics"""
    return {
        "total_users": len(baseline_manager.baselines),
        "trained_users": sum(1 for u in baseline_manager.baselines if baseline_manager.is_trained(u)),
        "total_alerts": len(alerts),
        "high_risk_users": sum(1 for s in user_risk_scores.values() if s['risk_level'] in ['high', 'critical'])
    }

@app.post("/api/simulate-anomaly")
async def simulate_anomaly(data: Dict[str, Any]):
    """Simulate anomalous behavior for testing"""
    user = data.get('user', 'test_user')
    anomaly_type = data.get('anomaly_type', 'unusual_access')
    
    # Create anomalous log entry
    if anomaly_type == 'unusual_access':
        log_entry = LogEntry(
            user=user,
            event_type='access',
            details={'resource': '/sensitive/database', 'count': 1000},
            timestamp=datetime.now().isoformat()
        )
    elif anomaly_type == 'unusual_time':
        # 3 AM access
        dt = datetime.now().replace(hour=3, minute=0)
        log_entry = LogEntry(
            user=user,
            event_type='login',
            timestamp=dt.isoformat()
        )
    else:
        log_entry = LogEntry(
            user=user,
            event_type='download',
            details={'bytes': 10000000000},  # 10GB
            timestamp=datetime.now().isoformat()
        )
    
    return await analyze_behavior(log_entry)

@app.get("/dashboard")
async def dashboard():
    """Serve dashboard HTML"""
    html_path = os.path.join(os.path.dirname(__file__), '..', 'web', 'index.html')
    if os.path.exists(html_path):
        return FileResponse(html_path)
    else:
        raise HTTPException(status_code=404, detail="Dashboard not found")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Create web dashboard (simplified React component)
cat > src/web/dashboard.jsx << 'EOF'
import React, { useState, useEffect } from 'react';

function UBADashboard() {
  const [stats, setStats] = useState({});
  const [alerts, setAlerts] = useState([]);
  const [users, setUsers] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      const statsRes = await fetch('/api/stats');
      const statsData = await statsRes.json();
      setStats(statsData);

      const alertsRes = await fetch('/api/alerts');
      const alertsData = await alertsRes.json();
      setAlerts(alertsData.alerts || []);
    };

    fetchData();
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial' }}>
      <h1>🔍 User Behavior Analytics Dashboard</h1>
      
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '20px' }}>
        <div style={{ padding: '20px', background: '#e3f2fd', borderRadius: '8px' }}>
          <h3>Total Users</h3>
          <p style={{ fontSize: '2em' }}>{stats.total_users || 0}</p>
        </div>
        <div style={{ padding: '20px', background: '#f3e5f5', borderRadius: '8px' }}>
          <h3>Trained Users</h3>
          <p style={{ fontSize: '2em' }}>{stats.trained_users || 0}</p>
        </div>
        <div style={{ padding: '20px', background: '#ffebee', borderRadius: '8px' }}>
          <h3>High Risk Users</h3>
          <p style={{ fontSize: '2em' }}>{stats.high_risk_users || 0}</p>
        </div>
      </div>

      <h2 style={{ marginTop: '40px' }}>🚨 Recent Alerts</h2>
      <div>
        {alerts.length === 0 ? (
          <p>No alerts</p>
        ) : (
          alerts.map((alert, i) => (
            <div key={i} style={{ 
              padding: '15px', 
              background: alert.risk_level === 'critical' ? '#ffcdd2' : '#fff9c4',
              margin: '10px 0',
              borderRadius: '8px',
              borderLeft: `4px solid ${alert.risk_level === 'critical' ? '#f44336' : '#ff9800'}`
            }}>
              <strong>{alert.user}</strong> - Risk: {alert.risk_score} ({alert.risk_level})
              <br/>
              <small>{new Date(alert.timestamp).toLocaleString()}</small>
              <br/>
              Anomalies: {alert.anomalies.join(', ')}
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export default UBADashboard;
EOF

# Create HTML wrapper
cat > src/web/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UBA Dashboard</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #1976d2;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .stat-card {
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-card h3 {
            margin: 0 0 10px 0;
            font-size: 14px;
            text-transform: uppercase;
            color: #666;
        }
        .stat-card p {
            margin: 0;
            font-size: 2.5em;
            font-weight: bold;
        }
        .alert-item {
            padding: 15px;
            margin: 10px 0;
            border-radius: 8px;
            border-left: 4px solid;
        }
        .alert-critical {
            background: #ffcdd2;
            border-color: #f44336;
        }
        .alert-high {
            background: #fff9c4;
            border-color: #ff9800;
        }
        .refresh-btn {
            padding: 10px 20px;
            background: #1976d2;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
        }
        .refresh-btn:hover {
            background: #1565c0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 User Behavior Analytics Dashboard</h1>
        
        <button class="refresh-btn" onclick="loadData()">Refresh Data</button>
        
        <div class="stats-grid" id="stats">
            <div class="stat-card" style="background: #e3f2fd;">
                <h3>Total Users</h3>
                <p id="total-users">0</p>
            </div>
            <div class="stat-card" style="background: #f3e5f5;">
                <h3>Trained Users</h3>
                <p id="trained-users">0</p>
            </div>
            <div class="stat-card" style="background: #ffebee;">
                <h3>High Risk Users</h3>
                <p id="high-risk-users">0</p>
            </div>
            <div class="stat-card" style="background: #fff3e0;">
                <h3>Total Alerts</h3>
                <p id="total-alerts">0</p>
            </div>
        </div>

        <h2>🚨 Recent Alerts</h2>
        <div id="alerts">
            <p>Loading alerts...</p>
        </div>
    </div>

    <script>
        async function loadData() {
            try {
                // Load stats
                const statsRes = await fetch('/api/stats');
                const stats = await statsRes.json();
                
                document.getElementById('total-users').textContent = stats.total_users || 0;
                document.getElementById('trained-users').textContent = stats.trained_users || 0;
                document.getElementById('high-risk-users').textContent = stats.high_risk_users || 0;
                document.getElementById('total-alerts').textContent = stats.total_alerts || 0;

                // Load alerts
                const alertsRes = await fetch('/api/alerts');
                const alertsData = await alertsRes.json();
                const alerts = alertsData.alerts || [];

                const alertsDiv = document.getElementById('alerts');
                if (alerts.length === 0) {
                    alertsDiv.innerHTML = '<p>No alerts found</p>';
                } else {
                    alertsDiv.innerHTML = alerts.map(alert => `
                        <div class="alert-item alert-${alert.risk_level}">
                            <strong>${alert.user}</strong> - Risk Score: ${alert.risk_score} (${alert.risk_level})
                            <br>
                            <small>${new Date(alert.timestamp).toLocaleString()}</small>
                            <br>
                            Anomalies: ${alert.anomalies.join(', ')}
                        </div>
                    `).join('');
                }
            } catch (error) {
                console.error('Error loading data:', error);
            }
        }

        // Load data on page load
        loadData();

        // Auto-refresh every 5 seconds
        setInterval(loadData, 5000);
    </script>
</body>
</html>
EOF

# Create test file
cat > tests/test_uba.py << 'EOF'
"""Test UBA components"""
import pytest
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

from feature_extraction.feature_engine import FeatureEngine
from feature_extraction.baseline_manager import BaselineManager
from detection.zscore_detector import ZScoreDetector
from detection.temporal_detector import TemporalDetector
from detection.ensemble_scorer import EnsembleScorer
from datetime import datetime

def test_feature_extraction():
    """Test feature extraction from events"""
    engine = FeatureEngine()
    
    # Add some events
    user = "test_user"
    event = {
        'timestamp': datetime.now().isoformat(),
        'event_type': 'login',
        'user': user,
        'details': {}
    }
    
    engine.add_event(user, event)
    features = engine.extract_features(user, event)
    
    assert isinstance(features, dict)
    assert 'login_frequency' in features
    assert 'time_of_day_score' in features

def test_baseline_manager():
    """Test baseline learning"""
    manager = BaselineManager()
    
    user = "test_user"
    features = {
        'login_frequency': 5.0,
        'access_count': 20.0
    }
    
    manager.update_baseline(user, features)
    baseline = manager.get_baseline(user)
    
    assert baseline['sample_count'] == 1
    assert baseline['mean']['login_frequency'] == 5.0

def test_zscore_detector():
    """Test Z-score anomaly detection"""
    detector = ZScoreDetector(threshold=3.0)
    
    baseline = {
        'mean': {'access_count': 50.0},
        'std': {'access_count': 10.0}
    }
    
    # Normal value
    normal_features = {'access_count': 52.0}
    score, anomalies = detector.detect(normal_features, baseline)
    assert score < 50
    
    # Anomalous value
    anomalous_features = {'access_count': 200.0}
    score, anomalies = detector.detect(anomalous_features, baseline)
    assert score > 50

def test_temporal_detector():
    """Test temporal pattern detection"""
    detector = TemporalDetector()
    
    user = "test_user"
    
    # Learn normal pattern (business hours)
    for hour in range(9, 18):
        for _ in range(10):
            dt = datetime.now().replace(hour=hour)
            detector.learn_pattern(user, dt.isoformat())
    
    # Test normal time
    normal_time = datetime.now().replace(hour=10).isoformat()
    score, reasons = detector.detect(user, normal_time)
    assert score < 50
    
    # Test anomalous time (3 AM)
    anomalous_time = datetime.now().replace(hour=3).isoformat()
    score, reasons = detector.detect(user, anomalous_time)
    assert score > 50

def test_ensemble_scorer():
    """Test ensemble scoring"""
    scorer = EnsembleScorer()
    
    detector_scores = {
        'zscore': (75.0, ['high access_count']),
        'temporal': (60.0, ['unusual hour'])
    }
    
    result = scorer.compute_score(detector_scores)
    
    assert 'final_score' in result
    assert 'risk_level' in result
    assert result['final_score'] > 0

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
EOF

# Create demo script
cat > demo_uba.py << 'EOF'
"""Demonstration of UBA system"""
import requests
import time
import json
from datetime import datetime, timedelta
import random

BASE_URL = "http://localhost:8000"

def generate_normal_behavior(user: str, count: int = 50):
    """Generate normal user behavior for baseline"""
    print(f"\n📊 Generating {count} normal events for {user}...")
    
    for i in range(count):
        # Normal business hours
        hour = random.choice(range(9, 18))
        dt = (datetime.now() - timedelta(days=random.randint(0, 14))).replace(hour=hour)
        
        event = {
            "user": user,
            "event_type": random.choice(['login', 'access', 'download']),
            "timestamp": dt.isoformat(),
            "details": {
                "resource": random.choice(['/api/users', '/api/reports', '/api/data']),
                "bytes": random.randint(1000, 100000)
            }
        }
        
        response = requests.post(f"{BASE_URL}/api/analyze", json=event)
        if response.status_code == 200:
            result = response.json()
            if i % 10 == 0:
                print(f"  Event {i+1}/{count}: Risk={result.get('risk_score', 0)} ({result.get('risk_level', 'learning')})")
        
        time.sleep(0.1)
    
    print(f"✅ Baseline established for {user}")

def simulate_anomaly(user: str, anomaly_type: str):
    """Simulate anomalous behavior"""
    print(f"\n🚨 Simulating {anomaly_type} for {user}...")
    
    response = requests.post(
        f"{BASE_URL}/api/simulate-anomaly",
        json={"user": user, "anomaly_type": anomaly_type}
    )
    
    if response.status_code == 200:
        result = response.json()
        print(f"  Risk Score: {result.get('risk_score', 0)}")
        print(f"  Risk Level: {result.get('risk_level', 'unknown')}")
        print(f"  Anomalies: {', '.join(result.get('anomalies', []))}")
    
    return response.json()

def main():
    print("=" * 60)
    print("🔍 User Behavior Analytics - System Demonstration")
    print("=" * 60)
    
    # Wait for service to be ready
    print("\n⏳ Waiting for UBA service...")
    for _ in range(30):
        try:
            response = requests.get(f"{BASE_URL}/")
            if response.status_code == 200:
                print("✅ Service is ready!")
                break
        except:
            pass
        time.sleep(1)
    else:
        print("❌ Service not available")
        return
    
    # Generate normal behavior for users
    users = ['alice', 'bob', 'charlie']
    
    for user in users:
        generate_normal_behavior(user, count=60)
    
    # Get stats
    print("\n📈 Current System Stats:")
    response = requests.get(f"{BASE_URL}/api/stats")
    if response.status_code == 200:
        stats = response.json()
        print(f"  Total Users: {stats.get('total_users', 0)}")
        print(f"  Trained Users: {stats.get('trained_users', 0)}")
        print(f"  Total Alerts: {stats.get('total_alerts', 0)}")
    
    # Simulate anomalies
    print("\n" + "=" * 60)
    print("Testing Anomaly Detection")
    print("=" * 60)
    
    time.sleep(2)
    simulate_anomaly('alice', 'unusual_access')
    
    time.sleep(2)
    simulate_anomaly('bob', 'unusual_time')
    
    time.sleep(2)
    simulate_anomaly('charlie', 'large_download')
    
    # Get alerts
    print("\n📋 Recent Alerts:")
    response = requests.get(f"{BASE_URL}/api/alerts")
    if response.status_code == 200:
        data = response.json()
        alerts = data.get('alerts', [])
        
        if alerts:
            for alert in alerts[-5:]:
                print(f"\n  🚨 {alert['user']} - Risk: {alert['risk_score']} ({alert['risk_level']})")
                print(f"     Time: {alert['timestamp']}")
                print(f"     Anomalies: {', '.join(alert.get('anomalies', []))}")
        else:
            print("  No alerts found")
    
    print("\n" + "=" * 60)
    print("✅ Demonstration Complete!")
    print(f"🌐 Dashboard: {BASE_URL}/dashboard")
    print("=" * 60)

if __name__ == '__main__':
    main()
EOF

# Create Docker files
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY config/ ./config/
COPY tests/ ./tests/

EXPOSE 8000

CMD ["python", "src/api/uba_service.py"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  uba-service:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    environment:
      - PYTHONUNBUFFERED=1
EOF

cat > .dockerignore << 'EOF'
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.pytest_cache/
.coverage
htmlcov/
dist/
build/
*.egg-info/
.git/
.env
EOF

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting UBA System"
echo "📁 Working directory: $SCRIPT_DIR"

# Check for duplicate services
if pgrep -f "uba_service.py" > /dev/null; then
    echo "⚠️  Found existing UBA service, stopping it..."
    pkill -f "uba_service.py" || true
    pkill -f "uvicorn.*uba" || true
    sleep 2
fi

# Create and activate virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3.11 -m venv venv || python3 -m venv venv
fi

echo "🔧 Activating virtual environment..."
source venv/bin/activate

echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "🧪 Running tests..."
python -m pytest tests/ -v || echo "⚠️  Some tests may have failed, continuing..."

echo "🌐 Starting UBA service..."
python src/api/uba_service.py &
UBA_PID=$!

echo "⏳ Waiting for service to start..."
for i in {1..30}; do
    if curl -s http://localhost:8000/ > /dev/null 2>&1; then
        echo "✅ Service is ready!"
        break
    fi
    sleep 1
done

echo "🎬 Running demonstration..."
python demo_uba.py || echo "⚠️  Demo script had issues, but service may still be running"

echo ""
echo "✅ UBA System is running!"
echo "📊 Dashboard: http://localhost:8000/dashboard"
echo "📡 API: http://localhost:8000/docs"
echo "🆔 Service PID: $UBA_PID"
echo ""
echo "Press Ctrl+C to stop"

wait $UBA_PID
EOF

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping UBA System..."

# Kill Python processes related to UBA
pkill -f "uba_service.py" || true
pkill -f "uvicorn.*uba" || true

# Check if any are still running
if pgrep -f "uba_service.py" > /dev/null; then
    echo "⚠️  Force killing remaining processes..."
    pkill -9 -f "uba_service.py" || true
fi

# Deactivate virtual environment
deactivate 2>/dev/null || true

echo "✅ UBA System stopped"
EOF

chmod +x start.sh stop.sh

# Static routes are now included directly in uba_service.py

echo ""
echo "✅ Project structure created successfully!"
echo ""

# Check for duplicate services
echo "🔍 Checking for existing UBA services..."
if pgrep -f "uba_service.py" > /dev/null; then
    echo "⚠️  Found existing UBA service, stopping it..."
    pkill -f "uba_service.py" || true
    pkill -f "uvicorn.*uba" || true
    sleep 2
fi

# Run tests
echo "🧪 Running unit tests..."
if [ ! -d "venv" ]; then
    python3.11 -m venv venv || python3 -m venv venv
fi
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
python -m pytest tests/ -v || echo "⚠️  Some tests may have failed, continuing..."

echo ""
echo "🌐 Starting UBA service..."
cd "$(pwd)"  # Ensure we're in the right directory
python src/api/uba_service.py &
UBA_PID=$!

echo "⏳ Waiting for service to start..."
for i in {1..30}; do
    if curl -s http://localhost:8000/ > /dev/null 2>&1; then
        echo "✅ Service is ready!"
        break
    fi
    sleep 1
done

echo "🎬 Running demonstration..."
python demo_uba.py || echo "⚠️  Demo script had issues, but service may still be running"

echo ""
echo "============================================================"
echo "✅ Setup Complete! UBA System is Running"
echo "============================================================"
echo "📊 Dashboard: http://localhost:8000/dashboard"
echo "📡 API Docs: http://localhost:8000/docs"
echo "🧪 Test API: curl http://localhost:8000/api/stats"
echo ""
echo "To stop: ./stop.sh or kill $UBA_PID"
echo "=" * 60