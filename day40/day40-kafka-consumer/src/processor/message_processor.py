import json
import time
import redis
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
from collections import defaultdict, deque
import structlog

logger = structlog.get_logger()

class MessageProcessor:
    """Process and analyze log messages"""
    
    def __init__(self):
        self.redis_client = redis.Redis(host='localhost', port=6379, db=0)
        self.processed_count = 0
        self.error_count = 0
        self.start_time = time.time()
        
        # In-memory analytics (sliding windows)
        self.request_rates = deque(maxlen=300)  # 5 minutes of 1-second buckets
        self.response_times = deque(maxlen=1000)  # Recent response times
        self.error_rates = defaultdict(int)
        self.endpoint_stats = defaultdict(lambda: {'count': 0, 'total_time': 0, 'errors': 0})
        
        # Geographic tracking
        self.geo_stats = defaultdict(int)
        
    def process_log_entry(self, log_data: Dict[str, Any]) -> bool:
        """Process a single log entry"""
        try:
            log_type = log_data.get('type', 'unknown')
            
            if log_type == 'web_access':
                self._process_web_access_log(log_data)
            elif log_type == 'application':
                self._process_application_log(log_data)
            elif log_type == 'error':
                self._process_error_log(log_data)
            else:
                self._process_generic_log(log_data)
                
            self.processed_count += 1
            
            # Update real-time metrics
            self._update_realtime_metrics(log_data)
            
            return True
            
        except Exception as e:
            logger.error("Log processing failed", error=str(e), log_data=log_data)
            self.error_count += 1
            return False
            
    def _process_web_access_log(self, log_data: Dict[str, Any]):
        """Process web server access logs"""
        endpoint = log_data.get('endpoint', 'unknown')
        status_code = log_data.get('status_code', 0)
        response_time = log_data.get('response_time', 0)
        client_ip = log_data.get('client_ip', 'unknown')
        
        # Update endpoint statistics
        stats = self.endpoint_stats[endpoint]
        stats['count'] += 1
        stats['total_time'] += response_time
        
        if status_code >= 400:
            stats['errors'] += 1
            self.error_rates[f"{status_code}"] += 1
            
        # Track response times
        if response_time > 0:
            self.response_times.append(response_time)
            
        # Geographic analysis (simplified)
        if client_ip.startswith('192.168'):
            geo = 'internal'
        elif client_ip.startswith('10.'):
            geo = 'vpn'
        else:
            geo = 'external'
        self.geo_stats[geo] += 1
        
        # Store in Redis for persistence
        timestamp = int(time.time())
        redis_key = f"web_access:{timestamp // 60}"  # Minute-level aggregation
        
        pipeline = self.redis_client.pipeline()
        pipeline.hincrby(redis_key, f"endpoint:{endpoint}", 1)
        pipeline.hincrby(redis_key, f"status:{status_code}", 1)
        pipeline.expire(redis_key, 3600)  # 1 hour TTL
        pipeline.execute()
        
    def _process_application_log(self, log_data: Dict[str, Any]):
        """Process application logs"""
        level = log_data.get('level', 'INFO')
        service = log_data.get('service', 'unknown')
        message = log_data.get('message', '')
        
        # Track log levels
        redis_key = f"app_logs:{int(time.time() // 60)}"
        pipeline = self.redis_client.pipeline()
        pipeline.hincrby(redis_key, f"level:{level}", 1)
        pipeline.hincrby(redis_key, f"service:{service}", 1)
        pipeline.expire(redis_key, 3600)
        pipeline.execute()
        
    def _process_error_log(self, log_data: Dict[str, Any]):
        """Process error logs with special handling"""
        error_type = log_data.get('error_type', 'unknown')
        severity = log_data.get('severity', 'medium')
        service = log_data.get('service', 'unknown')
        
        # Critical errors need immediate attention
        if severity == 'critical':
            self._alert_critical_error(log_data)
            
        # Track error patterns
        redis_key = f"errors:{int(time.time() // 60)}"
        pipeline = self.redis_client.pipeline()
        pipeline.hincrby(redis_key, f"type:{error_type}", 1)
        pipeline.hincrby(redis_key, f"service:{service}", 1)
        pipeline.hincrby(redis_key, f"severity:{severity}", 1)
        pipeline.expire(redis_key, 7200)  # 2 hours TTL
        pipeline.execute()
        
    def _process_generic_log(self, log_data: Dict[str, Any]):
        """Process generic log types"""
        log_level = log_data.get('level', 'INFO')
        source = log_data.get('source', 'unknown')
        
        # Basic counting
        redis_key = f"generic:{int(time.time() // 60)}"
        pipeline = self.redis_client.pipeline()
        pipeline.hincrby(redis_key, f"level:{log_level}", 1)
        pipeline.hincrby(redis_key, f"source:{source}", 1)
        pipeline.expire(redis_key, 1800)  # 30 minutes TTL
        pipeline.execute()
        
    def _update_realtime_metrics(self, log_data: Dict[str, Any]):
        """Update real-time analytics"""
        current_second = int(time.time())
        
        # Request rate (simplified)
        if len(self.request_rates) == 0 or self.request_rates[-1][0] != current_second:
            self.request_rates.append([current_second, 1])
        else:
            self.request_rates[-1][1] += 1
            
    def _alert_critical_error(self, log_data: Dict[str, Any]):
        """Handle critical error alerting"""
        alert_data = {
            'timestamp': datetime.now().isoformat(),
            'service': log_data.get('service', 'unknown'),
            'error_type': log_data.get('error_type', 'unknown'),
            'message': log_data.get('message', ''),
            'severity': 'critical'
        }
        
        # Store in Redis alerts list
        self.redis_client.lpush('critical_alerts', json.dumps(alert_data))
        self.redis_client.ltrim('critical_alerts', 0, 100)  # Keep last 100 alerts
        
        logger.error("Critical error detected", alert=alert_data)
        
    def get_analytics(self) -> Dict[str, Any]:
        """Get current analytics results"""
        current_time = time.time()
        uptime = current_time - self.start_time
        
        # Calculate request rate (last minute)
        recent_requests = [rate[1] for rate in self.request_rates if current_time - rate[0] <= 60]
        requests_per_second = sum(recent_requests) / max(len(recent_requests), 1)
        
        # Calculate response time percentiles
        if self.response_times:
            sorted_times = sorted(self.response_times)
            p50 = sorted_times[len(sorted_times) // 2]
            p95 = sorted_times[int(len(sorted_times) * 0.95)]
            p99 = sorted_times[int(len(sorted_times) * 0.99)]
        else:
            p50 = p95 = p99 = 0
            
        # Calculate error rates by endpoint
        endpoint_error_rates = {}
        for endpoint, stats in self.endpoint_stats.items():
            if stats['count'] > 0:
                error_rate = (stats['errors'] / stats['count']) * 100
                avg_response_time = stats['total_time'] / stats['count']
                endpoint_error_rates[endpoint] = {
                    'error_rate': error_rate,
                    'avg_response_time': avg_response_time,
                    'total_requests': stats['count']
                }
        
        return {
            'uptime_seconds': uptime,
            'requests_per_second': requests_per_second,
            'response_time_percentiles': {
                'p50': p50,
                'p95': p95, 
                'p99': p99
            },
            'endpoint_stats': dict(endpoint_error_rates),
            'geographic_distribution': dict(self.geo_stats),
            'total_errors': dict(self.error_rates),
            'processed_count': self.processed_count,
            'error_count': self.error_count
        }
        
    def get_stats(self) -> Dict[str, Any]:
        """Get processor statistics"""
        return {
            'processed_count': self.processed_count,
            'error_count': self.error_count,
            'success_rate': (self.processed_count / (self.processed_count + self.error_count)) * 100 
                           if (self.processed_count + self.error_count) > 0 else 0,
            'uptime_seconds': time.time() - self.start_time
        }
