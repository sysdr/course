from app import db
from datetime import datetime
import json

class LogEntry(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    level = db.Column(db.String(20), nullable=False)
    service = db.Column(db.String(100), nullable=False)
    message = db.Column(db.Text, nullable=False)
    log_metadata = db.Column(db.Text)  # JSON string
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
            'level': self.level,
            'service': self.service,
            'message': self.message,
            'metadata': json.loads(self.log_metadata) if self.log_metadata else {},
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
    
    @classmethod
    def from_dict(cls, data):
        return cls(
            timestamp=datetime.fromisoformat(data.get('timestamp', datetime.utcnow().isoformat())),
            level=data.get('level', 'INFO'),
            service=data.get('service', 'unknown'),
            message=data.get('message', ''),
            log_metadata=json.dumps(data.get('metadata', {}))
        )
