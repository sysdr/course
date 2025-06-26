import asyncio
import random
import time
import json
from typing import Dict, Any, AsyncGenerator
from faker import Faker
import structlog

logger = structlog.get_logger()
fake = Faker()

class LogEventGenerator:
    """Generates realistic log events for testing sliding windows"""
    
    def __init__(self):
        self.services = ['api-gateway', 'user-service', 'payment-service', 'notification-service']
        self.endpoints = ['/users', '/orders', '/payments', '/notifications', '/health']
        self.methods = ['GET', 'POST', 'PUT', 'DELETE']
        
    def generate_response_time_event(self) -> Dict[str, Any]:
        """Generate realistic API response time event"""
        # Simulate different response time patterns
        base_time = random.uniform(10, 200)
        
        # Add occasional spikes
        if random.random() < 0.1:  # 10% chance of spike
            base_time *= random.uniform(2, 5)
        
        # Add service-specific variance
        service = random.choice(self.services)
        if service == 'payment-service':
            base_time *= random.uniform(1.5, 2.0)  # Payment slower
        elif service == 'notification-service':
            base_time *= random.uniform(0.5, 0.8)  # Notifications faster
            
        return {
            'timestamp': time.time(),
            'metric': 'response_time_ms',
            'value': base_time,
            'service': service,
            'endpoint': random.choice(self.endpoints),
            'method': random.choice(self.methods),
            'status_code': random.choices([200, 201, 400, 404, 500], [0.7, 0.1, 0.1, 0.05, 0.05])[0],
            'user_id': fake.uuid4()
        }
    
    def generate_throughput_event(self) -> Dict[str, Any]:
        """Generate request throughput event"""
        return {
            'timestamp': time.time(),
            'metric': 'requests_per_second',
            'value': random.uniform(50, 500),
            'service': random.choice(self.services),
            'region': random.choice(['us-east-1', 'us-west-2', 'eu-west-1'])
        }
    
    def generate_error_rate_event(self) -> Dict[str, Any]:
        """Generate error rate event"""
        return {
            'timestamp': time.time(),
            'metric': 'error_rate_percent',
            'value': random.uniform(0, 15),
            'service': random.choice(self.services),
            'error_type': random.choice(['timeout', 'validation', 'database', 'external_api'])
        }
    
    async def generate_continuous_events(self, events_per_second: int = 10) -> AsyncGenerator[Dict[str, Any], None]:
        """Generate continuous stream of events"""
        interval = 1.0 / events_per_second
        
        while True:
            # Generate mix of different event types
            event_type = random.choices(
                ['response_time', 'throughput', 'error_rate'],
                [0.6, 0.3, 0.1]  # 60% response time, 30% throughput, 10% error rate
            )[0]
            
            if event_type == 'response_time':
                event = self.generate_response_time_event()
            elif event_type == 'throughput':
                event = self.generate_throughput_event()
            else:
                event = self.generate_error_rate_event()
            
            yield event
            await asyncio.sleep(interval)
