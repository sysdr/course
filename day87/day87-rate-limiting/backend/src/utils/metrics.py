import time
import structlog
from collections import defaultdict, deque
from typing import Dict, List
import asyncio

logger = structlog.get_logger()

class MetricsCollector:
    def __init__(self):
        self.request_counts = defaultdict(int)
        self.request_durations = defaultdict(deque)
        self.error_counts = defaultdict(int)
        self.quota_violations = defaultdict(int)
        self.rate_limit_violations = defaultdict(int)
        self.start_time = time.time()
        
        # Keep only last 1000 duration measurements per user
        self.max_duration_samples = 1000
    
    async def record_request(self, user_id: str, weight: int, 
                           duration: float, status_code: int):
        """Record request metrics"""
        self.request_counts[user_id] += weight
        
        # Track duration (keep only recent samples)
        durations = self.request_durations[user_id]
        durations.append(duration)
        if len(durations) > self.max_duration_samples:
            durations.popleft()
        
        # Track errors
        if status_code >= 400:
            self.error_counts[user_id] += 1
            
            if status_code == 429:
                self.rate_limit_violations[user_id] += 1
            elif status_code == 402:
                self.quota_violations[user_id] += 1
    
    async def get_all_metrics(self) -> Dict:
        """Get comprehensive metrics"""
        uptime = time.time() - self.start_time
        
        # Calculate aggregated stats
        total_requests = sum(self.request_counts.values())
        total_errors = sum(self.error_counts.values())
        total_rate_limits = sum(self.rate_limit_violations.values())
        total_quota_violations = sum(self.quota_violations.values())
        
        # Calculate average response times
        all_durations = []
        for durations in self.request_durations.values():
            all_durations.extend(durations)
        
        avg_duration = sum(all_durations) / len(all_durations) if all_durations else 0
        
        return {
            "system": {
                "uptime_seconds": uptime,
                "total_requests": total_requests,
                "requests_per_second": total_requests / uptime if uptime > 0 else 0,
                "error_rate": total_errors / total_requests if total_requests > 0 else 0,
                "avg_response_time_ms": avg_duration * 1000
            },
            "rate_limiting": {
                "total_violations": total_rate_limits,
                "violations_by_user": dict(self.rate_limit_violations)
            },
            "quotas": {
                "total_violations": total_quota_violations,
                "violations_by_user": dict(self.quota_violations)
            },
            "users": {
                "active_users": len(self.request_counts),
                "requests_by_user": dict(self.request_counts),
                "errors_by_user": dict(self.error_counts)
            }
        }
    
    def reset_metrics(self):
        """Reset all metrics (useful for testing)"""
        self.request_counts.clear()
        self.request_durations.clear()
        self.error_counts.clear()
        self.quota_violations.clear()
        self.rate_limit_violations.clear()
        self.start_time = time.time()
