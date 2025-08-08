import os
import json
from datetime import datetime, timedelta
from app.models import LogEntry
from app import db

def load_sample_logs():
    """Load sample log data for demonstration"""
    sample_logs = [
        {
            'timestamp': '2025-05-20T10:30:00Z',
            'level': 'INFO',
            'service': 'api-gateway',
            'message': 'Request processed successfully',
            'metadata': {'response_time': 45, 'status_code': 200}
        },
        {
            'timestamp': '2025-05-20T10:31:15Z',
            'level': 'ERROR',
            'service': 'user-service',
            'message': 'Database connection timeout',
            'metadata': {'error_code': 'DB_TIMEOUT', 'retry_count': 3}
        },
        {
            'timestamp': '2025-05-20T10:32:30Z',
            'level': 'WARN',
            'service': 'payment-service',
            'message': 'High memory usage detected',
            'metadata': {'memory_usage': '85%', 'threshold': '80%'}
        },
        {
            'timestamp': '2025-05-20T10:33:45Z',
            'level': 'DEBUG',
            'service': 'auth-service',
            'message': 'Token validation successful',
            'metadata': {'user_id': '12345', 'token_type': 'JWT'}
        },
        {
            'timestamp': '2025-05-20T10:34:00Z',
            'level': 'ERROR',
            'service': 'api-gateway',
            'message': 'Rate limit exceeded for IP 192.168.1.100',
            'metadata': {'ip': '192.168.1.100', 'limit': 1000, 'current': 1001}
        }
    ]
    
    # Clear existing data
    LogEntry.query.delete()
    
    # Add sample logs
    for log_data in sample_logs:
        log_entry = LogEntry.from_dict(log_data)
        db.session.add(log_entry)
    
    # Generate more sample data
    services = ['api-gateway', 'user-service', 'payment-service', 'auth-service', 'notification-service']
    levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
    
    base_time = datetime.now() - timedelta(hours=2)
    
    for i in range(95):  # Add 95 more logs for total of 100
        log_entry = LogEntry(
            timestamp=base_time + timedelta(minutes=i),
            level=levels[i % len(levels)],
            service=services[i % len(services)],
            message=f'Sample log message {i+6}',
            log_metadata=json.dumps({'sample_id': i+6, 'batch': 'generated'})
        )
        db.session.add(log_entry)
    
    db.session.commit()
    return len(sample_logs) + 95

def parse_query_filters(request_args):
    """Parse query parameters for log filtering"""
    filters = {}
    
    if 'level' in request_args and request_args.get('level'):
        filters['level'] = request_args.get('level')
    
    if 'service' in request_args and request_args.get('service'):
        filters['service'] = request_args.get('service')
    
    if 'search' in request_args and request_args.get('search'):
        filters['search'] = request_args.get('search')
    
    if 'start_date' in request_args:
        try:
            start_date = request_args.get('start_date')
            if start_date:
                filters['start_date'] = datetime.fromisoformat(start_date)
        except ValueError:
            pass
    
    if 'end_date' in request_args:
        try:
            end_date = request_args.get('end_date')
            if end_date:
                filters['end_date'] = datetime.fromisoformat(end_date)
        except ValueError:
            pass
    
    return filters

def apply_log_filters(query, filters):
    """Apply filters to log query"""
    if 'level' in filters:
        query = query.filter(LogEntry.level == filters['level'])
    
    if 'service' in filters:
        query = query.filter(LogEntry.service == filters['service'])
    
    if 'search' in filters:
        search_term = f"%{filters['search']}%"
        query = query.filter(LogEntry.message.like(search_term))
    
    if 'start_date' in filters:
        query = query.filter(LogEntry.timestamp >= filters['start_date'])
    
    if 'end_date' in filters:
        query = query.filter(LogEntry.timestamp <= filters['end_date'])
    
    return query
