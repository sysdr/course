import asyncio
import json
import time
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Set
from dataclasses import dataclass, asdict
import redis.asyncio as redis
import structlog

logger = structlog.get_logger()

@dataclass
class Window:
    window_id: str
    start_time: int
    end_time: int
    window_type: str
    state: str  # active, grace_period, closed
    event_count: int = 0
    data: Dict = None
    
    def __post_init__(self):
        if self.data is None:
            self.data = {}

class WindowManager:
    def __init__(self, redis_client, config):
        self.redis = redis_client
        self.config = config
        self.active_windows: Dict[str, Window] = {}
        self.window_types = {wt['name']: wt for wt in config['window_types']}
        
    async def start(self):
        """Start window manager background tasks"""
        asyncio.create_task(self._window_lifecycle_manager())
        asyncio.create_task(self._cleanup_expired_windows())
        logger.info("WindowManager started")
        
    def align_timestamp_to_window(self, timestamp: int, window_size: int) -> int:
        """Align timestamp to window boundary"""
        return (timestamp // window_size) * window_size
        
    def create_window_id(self, window_start: int, window_type: str) -> str:
        """Create unique window identifier"""
        return f"{window_type}_{window_start}"
        
    async def get_or_create_window(self, timestamp: int, window_type: str = "5min") -> Window:
        """Get existing window or create new one"""
        window_config = self.window_types[window_type]
        window_start = self.align_timestamp_to_window(timestamp, window_config['size'])
        window_end = window_start + window_config['size']
        window_id = self.create_window_id(window_start, window_type)
        
        # Check active windows first
        if window_id in self.active_windows:
            return self.active_windows[window_id]
            
        # Check Redis for existing window
        window_data = await self.redis.get(f"window:{window_id}")
        if window_data:
            window_dict = json.loads(window_data)
            window = Window(**window_dict)
            self.active_windows[window_id] = window
            return window
            
        # Create new window
        window = Window(
            window_id=window_id,
            start_time=window_start,
            end_time=window_end,
            window_type=window_type,
            state="active"
        )
        
        self.active_windows[window_id] = window
        await self._persist_window(window)
        
        logger.info("Created new window", window_id=window_id, start=window_start, end=window_end)
        return window
        
    async def add_event_to_window(self, timestamp: int, event_data: Dict, window_type: str = "5min"):
        """Add event to appropriate window"""
        window = await self.get_or_create_window(timestamp, window_type)
        
        # Check if window is still accepting events
        current_time = int(time.time())
        grace_period = self.config['windowing']['grace_period']
        
        if current_time > window.end_time + grace_period:
            logger.warning("Event too late for window", 
                         window_id=window.window_id, 
                         event_time=timestamp,
                         current_time=current_time)
            return False
            
        # Add event to window
        window.event_count += 1
        
        # Update window aggregations
        await self._update_window_aggregations(window, event_data)
        await self._persist_window(window)
        
        return True
        
    async def _update_window_aggregations(self, window: Window, event_data: Dict):
        """Update window aggregations with new event"""
        # Initialize aggregations if needed
        if 'aggregations' not in window.data:
            window.data['aggregations'] = {
                'count': 0,
                'levels': {},
                'services': {},
                'response_times': [],
                'error_count': 0
            }
            
        agg = window.data['aggregations']
        agg['count'] += 1
        
        # Level aggregation
        level = event_data.get('level', 'unknown')
        agg['levels'][level] = agg['levels'].get(level, 0) + 1
        
        # Service aggregation  
        service = event_data.get('service', 'unknown')
        agg['services'][service] = agg['services'].get(service, 0) + 1
        
        # Response time tracking
        if 'response_time' in event_data:
            agg['response_times'].append(event_data['response_time'])
            
        # Error counting
        if level == 'ERROR':
            agg['error_count'] += 1
            
    async def _persist_window(self, window: Window):
        """Persist window to Redis"""
        window_data = json.dumps(asdict(window))
        await self.redis.set(f"window:{window.window_id}", window_data, 
                           ex=self.window_types[window.window_type]['retention'])
        
    async def _window_lifecycle_manager(self):
        """Manage window state transitions"""
        while True:
            current_time = int(time.time())
            windows_to_close = []
            
            for window_id, window in self.active_windows.items():
                # Transition to grace period
                if window.state == "active" and current_time >= window.end_time:
                    window.state = "grace_period"
                    await self._persist_window(window)
                    logger.info("Window entered grace period", window_id=window_id)
                    
                # Close window after grace period
                elif (window.state == "grace_period" and 
                      current_time >= window.end_time + self.config['windowing']['grace_period']):
                    window.state = "closed"
                    await self._finalize_window(window)
                    windows_to_close.append(window_id)
                    
            # Remove closed windows from active memory
            for window_id in windows_to_close:
                del self.active_windows[window_id]
                
            await asyncio.sleep(10)  # Check every 10 seconds
            
    async def _finalize_window(self, window: Window):
        """Finalize window calculations and publish results"""
        # Calculate final statistics
        agg = window.data.get('aggregations', {})
        
        if agg.get('response_times'):
            import numpy as np
            response_times = agg['response_times']
            agg['avg_response_time'] = float(np.mean(response_times))
            agg['p95_response_time'] = float(np.percentile(response_times, 95))
            agg['p99_response_time'] = float(np.percentile(response_times, 99))
            
        # Calculate error rate
        total_count = agg.get('count', 0)
        error_count = agg.get('error_count', 0)
        agg['error_rate'] = (error_count / total_count) if total_count > 0 else 0
        
        await self._persist_window(window)
        
        # Publish window completion event
        completion_event = {
            'window_id': window.window_id,
            'start_time': window.start_time,
            'end_time': window.end_time,
            'aggregations': agg,
            'completed_at': int(time.time())
        }
        
        await self.redis.publish('window_completed', json.dumps(completion_event))
        logger.info("Window finalized", window_id=window.window_id, event_count=window.event_count)
        
    async def get_window_results(self, window_type: str = "5min", limit: int = 20) -> List[Dict]:
        """Get recent window results"""
        pattern = f"window:{window_type}_*"
        keys = await self.redis.keys(pattern)
        
        results = []
        for key in sorted(keys, reverse=True)[:limit]:
            window_data = await self.redis.get(key)
            if window_data:
                window_dict = json.loads(window_data)
                results.append(window_dict)
                
        return results
        
    async def _cleanup_expired_windows(self):
        """Clean up expired windows from memory"""
        while True:
            # Keep memory usage under control
            if len(self.active_windows) > self.config['windowing']['max_active_windows']:
                # Remove oldest windows
                current_time = int(time.time())
                expired = [(wid, w) for wid, w in self.active_windows.items() 
                          if current_time > w.end_time + 300]  # 5 min buffer
                
                for window_id, _ in expired[:10]:  # Remove 10 at a time
                    if window_id in self.active_windows:
                        del self.active_windows[window_id]
                        
            await asyncio.sleep(60)  # Check every minute
