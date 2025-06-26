import asyncio
import time
import json
from collections import deque, defaultdict
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass, asdict
import structlog
import numpy as np

logger = structlog.get_logger()

@dataclass
class Event:
    timestamp: float
    value: float
    metadata: Dict[str, Any]
    event_id: str

@dataclass
class WindowResult:
    window_start: float
    window_end: float
    count: int
    sum: float
    average: float
    min_value: float
    max_value: float
    std_dev: float

class SlidingWindow:
    """Memory-efficient sliding window with O(1) operations"""
    
    def __init__(self, window_size: float, slide_interval: float, max_size: int = 10000):
        self.window_size = window_size
        self.slide_interval = slide_interval
        self.max_size = max_size
        
        # Ring buffer for efficient memory management
        self.events = deque(maxlen=max_size)
        self.window_stats = {}
        
        # Incremental statistics
        self.current_sum = 0.0
        self.current_count = 0
        self.current_min = float('inf')
        self.current_max = float('-inf')
        self.values_for_std = deque(maxlen=max_size)
        
        self.last_slide_time = time.time()
        
    def add_event(self, event: Event) -> None:
        """Add new event with O(1) complexity"""
        current_time = time.time()
        
        # Remove expired events
        self._remove_expired_events(current_time)
        
        # Add new event
        self.events.append(event)
        self._update_incremental_stats(event.value, add=True)
        
        # Slide window if interval elapsed
        if current_time - self.last_slide_time >= self.slide_interval:
            self._slide_window(current_time)
            
        logger.info("Event added", event_id=event.event_id, window_size=len(self.events))
    
    def _remove_expired_events(self, current_time: float) -> None:
        """Remove events outside window boundary"""
        window_start = current_time - self.window_size
        
        while self.events and self.events[0].timestamp < window_start:
            expired_event = self.events.popleft()
            self._update_incremental_stats(expired_event.value, add=False)
    
    def _update_incremental_stats(self, value: float, add: bool) -> None:
        """Update statistics incrementally"""
        if add:
            self.current_sum += value
            self.current_count += 1
            self.current_min = min(self.current_min, value)
            self.current_max = max(self.current_max, value)
            self.values_for_std.append(value)
        else:
            self.current_sum -= value
            self.current_count -= 1
            if self.current_count == 0:
                self.current_min = float('inf')
                self.current_max = float('-inf')
                self.values_for_std.clear()
    
    def _slide_window(self, current_time: float) -> WindowResult:
        """Create window result and slide to next position"""
        if self.current_count == 0:
            return None
            
        # Calculate statistics
        average = self.current_sum / self.current_count
        std_dev = np.std(list(self.values_for_std)) if len(self.values_for_std) > 1 else 0.0
        
        result = WindowResult(
            window_start=current_time - self.window_size,
            window_end=current_time,
            count=self.current_count,
            sum=self.current_sum,
            average=average,
            min_value=self.current_min if self.current_min != float('inf') else 0,
            max_value=self.current_max if self.current_max != float('-inf') else 0,
            std_dev=std_dev
        )
        
        # Store result with timestamp key
        self.window_stats[current_time] = result
        self.last_slide_time = current_time
        
        logger.info("Window slid", 
                   window_start=result.window_start,
                   average=result.average,
                   count=result.count)
        
        return result
    
    def get_current_stats(self) -> Optional[WindowResult]:
        """Get current window statistics"""
        current_time = time.time()
        self._remove_expired_events(current_time)
        
        if self.current_count == 0:
            return None
            
        average = self.current_sum / self.current_count
        std_dev = np.std(list(self.values_for_std)) if len(self.values_for_std) > 1 else 0.0
        
        return WindowResult(
            window_start=current_time - self.window_size,
            window_end=current_time,
            count=self.current_count,
            sum=self.current_sum,
            average=average,
            min_value=self.current_min if self.current_min != float('inf') else 0,
            max_value=self.current_max if self.current_max != float('-inf') else 0,
            std_dev=std_dev
        )
    
    def get_recent_windows(self, count: int = 10) -> List[WindowResult]:
        """Get recent window results"""
        sorted_times = sorted(self.window_stats.keys(), reverse=True)
        return [self.window_stats[t] for t in sorted_times[:count]]

class SlidingWindowManager:
    """Manages multiple sliding windows for different metrics"""
    
    def __init__(self, window_size: float, slide_interval: float):
        self.windows: Dict[str, SlidingWindow] = {}
        self.window_size = window_size
        self.slide_interval = slide_interval
        
    def get_or_create_window(self, metric_name: str) -> SlidingWindow:
        """Get existing window or create new one"""
        if metric_name not in self.windows:
            self.windows[metric_name] = SlidingWindow(
                self.window_size, 
                self.slide_interval
            )
        return self.windows[metric_name]
    
    def add_metric(self, metric_name: str, value: float, metadata: Dict = None) -> None:
        """Add metric value to appropriate sliding window"""
        window = self.get_or_create_window(metric_name)
        event = Event(
            timestamp=time.time(),
            value=value,
            metadata=metadata or {},
            event_id=f"{metric_name}_{int(time.time() * 1000)}"
        )
        window.add_event(event)
    
    def get_all_current_stats(self) -> Dict[str, WindowResult]:
        """Get current statistics for all windows"""
        stats = {}
        for metric_name, window in self.windows.items():
            result = window.get_current_stats()
            if result:
                stats[metric_name] = result
        return stats
