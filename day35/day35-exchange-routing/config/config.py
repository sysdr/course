import os

class Config:
    RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'localhost')
    RABBITMQ_PORT = int(os.getenv('RABBITMQ_PORT', 5672))
    RABBITMQ_USER = os.getenv('RABBITMQ_USER', 'guest')
    RABBITMQ_PASSWORD = os.getenv('RABBITMQ_PASSWORD', 'guest')
    RABBITMQ_VHOST = os.getenv('RABBITMQ_VHOST', '/')
    
    # Exchange configurations
    DIRECT_EXCHANGE = 'logs_direct'
    TOPIC_EXCHANGE = 'logs_topic'
    FANOUT_EXCHANGE = 'logs_fanout'
    
    # Queue names
    QUEUES = {
        'database_logs': 'database.logs',
        'api_logs': 'api.logs',
        'security_logs': 'security.logs',
        'analytics_logs': 'analytics.logs',
        'monitoring_logs': 'monitoring.logs',
        'broadcast_logs': 'broadcast.logs'
    }
    
    # Routing patterns
    ROUTING_PATTERNS = {
        'database.*': 'database_logs',
        'api.*': 'api_logs',
        'security.*': 'security_logs',
        'analytics.*': 'analytics_logs',
        'monitoring.*': 'monitoring_logs'
    }
