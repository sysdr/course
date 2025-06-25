import asyncio
import json
from typing import Dict, List, Any, Callable
import structlog

logger = structlog.get_logger()

class AggregationCoordinator:
    def __init__(self, window_manager, redis_client):
        self.window_manager = window_manager
        self.redis = redis_client
        self.aggregation_functions: Dict[str, Callable] = {}
        self.subscribers = []
        self.dashboard = None  # Reference to dashboard for real-time updates
        
    def set_dashboard(self, dashboard):
        """Set dashboard reference for real-time updates"""
        self.dashboard = dashboard
        
    def register_aggregation(self, name: str, func: Callable):
        """Register custom aggregation function"""
        self.aggregation_functions[name] = func
        logger.info("Registered aggregation function", name=name)
        
    async def start(self):
        """Start aggregation coordinator"""
        # Subscribe to window completion events
        pubsub = self.redis.pubsub()
        await pubsub.subscribe('window_completed')
        
        asyncio.create_task(self._handle_window_completions(pubsub))
        logger.info("AggregationCoordinator started")
        
    async def process_log_event(self, log_data: Dict[str, Any]):
        """Process log event through windowing system"""
        timestamp = log_data.get('extracted_timestamp', log_data.get('timestamp'))
        if not timestamp:
            logger.warning("No timestamp in log event", log_data=log_data)
            return
            
        # Add to different window types
        for window_type in ['5min', '1hour']:
            await self.window_manager.add_event_to_window(
                timestamp, log_data, window_type
            )
            
        # Send real-time update to dashboard
        if self.dashboard:
            await self._send_realtime_update()
            
    async def _handle_window_completions(self, pubsub):
        """Handle completed windows and run additional aggregations"""
        async for message in pubsub.listen():
            if message['type'] == 'message':
                try:
                    completion_data = json.loads(message['data'])
                    await self._run_custom_aggregations(completion_data)
                    await self._notify_subscribers(completion_data)
                except Exception as e:
                    logger.error("Error handling window completion", error=str(e))
                    
    async def _run_custom_aggregations(self, completion_data: Dict):
        """Run custom aggregation functions on completed window"""
        for name, func in self.aggregation_functions.items():
            try:
                result = await func(completion_data)
                if result:
                    # Store custom aggregation result
                    key = f"custom_agg:{name}:{completion_data['window_id']}"
                    await self.redis.set(key, json.dumps(result), ex=3600)
            except Exception as e:
                logger.error("Error in custom aggregation", name=name, error=str(e))
                
    async def _notify_subscribers(self, completion_data: Dict):
        """Notify subscribers of window completion"""
        for subscriber in self.subscribers:
            try:
                await subscriber(completion_data)
            except Exception as e:
                logger.error("Error notifying subscriber", error=str(e))
                
    def add_subscriber(self, callback: Callable):
        """Add window completion subscriber"""
        self.subscribers.append(callback)
        
    async def get_windowed_metrics(self, window_type: str = "5min", 
                                 limit: int = 20) -> List[Dict]:
        """Get recent windowed metrics"""
        windows = await self.window_manager.get_window_results(window_type, limit)
        
        metrics = []
        for window in windows:
            if 'aggregations' in window['data']:
                agg = window['data']['aggregations']
                
                # Calculate error rate if not present
                if 'error_rate' not in agg and 'error_count' in agg and 'count' in agg:
                    total_count = agg.get('count', 0)
                    error_count = agg.get('error_count', 0)
                    agg['error_rate'] = (error_count / total_count) if total_count > 0 else 0
                
                metric = {
                    'window_id': window['window_id'],
                    'start_time': window['start_time'],
                    'end_time': window['end_time'],
                    'window_type': window['window_type'],
                    'metrics': agg
                }
                metrics.append(metric)
                
        return sorted(metrics, key=lambda x: x['start_time'], reverse=True)

    async def _send_realtime_update(self):
        """Send real-time update to dashboard"""
        try:
            metrics_5min = await self.get_windowed_metrics("5min", 10)
            metrics_1hour = await self.get_windowed_metrics("1hour", 5)
            
            update = {
                "type": "metrics_update",
                "data": {
                    "5min": metrics_5min,
                    "1hour": metrics_1hour,
                    "active_windows": len(self.window_manager.active_windows)
                }
            }
            
            await self.dashboard.broadcast_update(update)
        except Exception as e:
            logger.error("Error sending real-time update", error=str(e))

# Custom aggregation functions
async def calculate_throughput_metrics(completion_data: Dict) -> Dict:
    """Calculate throughput metrics for window"""
    agg = completion_data.get('aggregations', {})
    window_duration = completion_data['end_time'] - completion_data['start_time']
    
    total_events = agg.get('count', 0)
    throughput = total_events / window_duration if window_duration > 0 else 0
    
    return {
        'throughput_per_second': throughput,
        'total_events': total_events,
        'window_duration': window_duration
    }

async def calculate_sla_metrics(completion_data: Dict) -> Dict:
    """Calculate SLA metrics for window"""
    agg = completion_data.get('aggregations', {})
    
    total_requests = agg.get('count', 0)
    error_count = agg.get('error_count', 0)
    
    availability = ((total_requests - error_count) / total_requests * 100) if total_requests > 0 else 100
    
    return {
        'availability_percentage': availability,
        'total_requests': total_requests,
        'successful_requests': total_requests - error_count,
        'failed_requests': error_count
    }
