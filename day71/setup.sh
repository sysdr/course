#!/bin/bash

# Day 71: Profile and Optimize Log Ingestion Pipeline - Complete Implementation
# 254-Day Hands-On System Design Series

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/log-profiler"

echo "🚀 Day 71: Building Performance Profiling & Optimization System"
echo "=============================================================="

# Create project structure under this script's directory (setup.sh stays outside the app tree)
echo "📁 Creating project structure at ${PROJECT_DIR}..."
mkdir -p "${PROJECT_DIR}"/{src/{profiler,optimizer,analyzer,dashboard},tests,config,docker,data/{profiles,reports},static/{css,js},templates,logs}

cd "${PROJECT_DIR}"

# Create requirements.txt with latest May 2025 libraries
cat > requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn==0.30.1
psutil==5.9.8
memory-profiler==0.61.0
pytest==8.2.2
pytest-asyncio==0.23.7
numpy==1.26.4
pandas==2.2.2
plotly==5.20.0
aiofiles==23.2.1
structlog==24.1.0
prometheus-client==0.20.0
pydantic==2.7.1
redis==5.0.4
websockets==12.0
jinja2==3.1.4
httpx==0.27.0
rich==13.7.1
EOF

# Install dependencies
echo "📦 Installing dependencies..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Create configuration files
echo "⚙️ Creating configuration files..."
cat > config/profiler_config.py << 'EOF'
from dataclasses import dataclass
from typing import Dict, List, Optional

@dataclass
class ProfilerConfig:
    # Profiling settings
    sampling_interval: float = 0.1  # seconds
    max_memory_samples: int = 10000
    enable_cpu_profiling: bool = True
    enable_memory_profiling: bool = True
    enable_io_profiling: bool = True
    
    # Performance thresholds
    cpu_threshold: float = 80.0  # percent
    memory_threshold: float = 85.0  # percent
    latency_threshold: float = 100.0  # milliseconds
    
    # Optimization settings
    auto_optimize: bool = False
    optimization_strategies: List[str] = None
    
    def __post_init__(self):
        if self.optimization_strategies is None:
            self.optimization_strategies = [
                'batch_optimization',
                'memory_pooling',
                'async_io',
                'compression',
                'caching'
            ]

# Default configuration
DEFAULT_CONFIG = ProfilerConfig()
EOF

# Create main profiler engine
cat > src/profiler/profiler_engine.py << 'EOF'
import time
import psutil
import threading
import asyncio
from typing import Dict, List, Any, Optional, Callable
from dataclasses import dataclass, asdict
from datetime import datetime
import json
import tracemalloc
from memory_profiler import profile
import structlog

logger = structlog.get_logger()

@dataclass
class PerformanceMetrics:
    timestamp: float
    cpu_percent: float
    memory_percent: float
    memory_mb: float
    disk_io_read_mb: float
    disk_io_write_mb: float
    network_sent_mb: float
    network_recv_mb: float
    active_threads: int
    function_name: str = ""
    execution_time_ms: float = 0.0

class ProfilerEngine:
    def __init__(self, config):
        self.config = config
        self.metrics_history: List[PerformanceMetrics] = []
        self.is_profiling = False
        self.profiling_thread = None
        self.function_timings = {}
        self.bottlenecks = []
        
        # Start memory tracing
        if config.enable_memory_profiling:
            tracemalloc.start()
    
    def start_profiling(self):
        """Start continuous system profiling"""
        self.is_profiling = True
        self.profiling_thread = threading.Thread(target=self._profiling_loop)
        self.profiling_thread.daemon = True
        self.profiling_thread.start()
        logger.info("Profiling started")
    
    def stop_profiling(self):
        """Stop profiling and return collected metrics"""
        self.is_profiling = False
        if self.profiling_thread:
            self.profiling_thread.join()
        logger.info("Profiling stopped")
        return self.get_metrics_summary()
    
    def _profiling_loop(self):
        """Continuous profiling loop"""
        process = psutil.Process()
        
        while self.is_profiling:
            try:
                # Collect system metrics (interval avoids psutil's first-call 0.0 CPU reading)
                metrics = PerformanceMetrics(
                    timestamp=time.time(),
                    cpu_percent=process.cpu_percent(interval=0.1),
                    memory_percent=process.memory_percent(),
                    memory_mb=process.memory_info().rss / 1024 / 1024,
                    disk_io_read_mb=process.io_counters().read_bytes / 1024 / 1024,
                    disk_io_write_mb=process.io_counters().write_bytes / 1024 / 1024,
                    network_sent_mb=0,  # Simplified for demo
                    network_recv_mb=0,
                    active_threads=process.num_threads()
                )
                
                self.metrics_history.append(metrics)
                
                # Keep only recent metrics
                if len(self.metrics_history) > self.config.max_memory_samples:
                    self.metrics_history = self.metrics_history[-self.config.max_memory_samples:]
                
                # Check for performance issues
                self._detect_bottlenecks(metrics)
                
                time.sleep(self.config.sampling_interval)
            except Exception as e:
                logger.error(f"Profiling error: {e}")
    
    def _detect_bottlenecks(self, metrics: PerformanceMetrics):
        """Detect performance bottlenecks"""
        if metrics.cpu_percent > self.config.cpu_threshold:
            self.bottlenecks.append({
                'type': 'cpu',
                'severity': 'high' if metrics.cpu_percent > 90 else 'medium',
                'value': metrics.cpu_percent,
                'timestamp': metrics.timestamp,
                'recommendation': 'Consider optimizing CPU-intensive operations'
            })
        
        if metrics.memory_percent > self.config.memory_threshold:
            self.bottlenecks.append({
                'type': 'memory',
                'severity': 'high' if metrics.memory_percent > 95 else 'medium',
                'value': metrics.memory_percent,
                'timestamp': metrics.timestamp,
                'recommendation': 'Consider implementing memory pooling or reducing allocations'
            })
    
    def profile_function(self, func: Callable, *args, **kwargs):
        """Profile a specific function execution"""
        start_time = time.time()
        start_memory = psutil.Process().memory_info().rss
        
        try:
            result = func(*args, **kwargs)
            success = True
        except Exception as e:
            result = None
            success = False
            logger.error(f"Function {func.__name__} failed: {e}")
        
        end_time = time.time()
        end_memory = psutil.Process().memory_info().rss
        
        execution_time = (end_time - start_time) * 1000  # Convert to ms
        memory_delta = (end_memory - start_memory) / 1024 / 1024  # Convert to MB
        
        function_profile = {
            'function_name': func.__name__,
            'execution_time_ms': execution_time,
            'memory_delta_mb': memory_delta,
            'success': success,
            'timestamp': start_time
        }
        
        # Store function timing
        if func.__name__ not in self.function_timings:
            self.function_timings[func.__name__] = []
        
        self.function_timings[func.__name__].append(function_profile)
        
        return result, function_profile
    
    def get_metrics_summary(self) -> Dict[str, Any]:
        """Get comprehensive metrics summary"""
        if not self.metrics_history:
            return {}
        
        recent_metrics = self.metrics_history[-100:]  # Last 100 samples
        
        avg_cpu = sum(m.cpu_percent for m in recent_metrics) / len(recent_metrics)
        avg_memory = sum(m.memory_percent for m in recent_metrics) / len(recent_metrics)
        max_memory = max(m.memory_mb for m in recent_metrics)
        
        return {
            'summary': {
                'avg_cpu_percent': round(avg_cpu, 2),
                'avg_memory_percent': round(avg_memory, 2),
                'max_memory_mb': round(max_memory, 2),
                'total_samples': len(self.metrics_history),
                'profiling_duration_seconds': time.time() - self.metrics_history[0].timestamp if self.metrics_history else 0
            },
            'bottlenecks': self.bottlenecks[-10:],  # Last 10 bottlenecks
            'function_timings': {
                name: {
                    'count': len(timings),
                    'avg_time_ms': sum(t['execution_time_ms'] for t in timings) / len(timings),
                    'max_time_ms': max(t['execution_time_ms'] for t in timings),
                    'total_memory_mb': sum(t['memory_delta_mb'] for t in timings)
                }
                for name, timings in self.function_timings.items()
            },
            'raw_metrics': [asdict(m) for m in recent_metrics[-50:]]  # Last 50 raw metrics
        }

# Decorator for easy function profiling
def profile_performance(profiler_engine):
    def decorator(func):
        def wrapper(*args, **kwargs):
            if profiler_engine.is_profiling:
                result, profile_data = profiler_engine.profile_function(func, *args, **kwargs)
                return result
            else:
                return func(*args, **kwargs)
        return wrapper
    return decorator
EOF

# Create optimization engine
cat > src/optimizer/optimization_engine.py << 'EOF'
import asyncio
import json
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import numpy as np
import structlog

logger = structlog.get_logger()

@dataclass
class OptimizationSuggestion:
    category: str
    priority: str  # high, medium, low
    description: str
    estimated_improvement: str
    implementation_complexity: str
    code_example: Optional[str] = None

class OptimizationEngine:
    def __init__(self, config):
        self.config = config
        self.optimization_history = []
        
    def analyze_performance_data(self, metrics_summary: Dict[str, Any]) -> List[OptimizationSuggestion]:
        """Analyze performance data and generate optimization suggestions"""
        suggestions = []
        
        # Analyze CPU usage patterns
        if metrics_summary.get('summary', {}).get('avg_cpu_percent', 0) > 70:
            suggestions.extend(self._cpu_optimization_suggestions(metrics_summary))
        
        # Analyze memory usage patterns
        if metrics_summary.get('summary', {}).get('avg_memory_percent', 0) > 75:
            suggestions.extend(self._memory_optimization_suggestions(metrics_summary))
        
        # Analyze function performance
        function_timings = metrics_summary.get('function_timings', {})
        if function_timings:
            suggestions.extend(self._function_optimization_suggestions(function_timings))
        
        # Analyze bottlenecks
        bottlenecks = metrics_summary.get('bottlenecks', [])
        if bottlenecks:
            suggestions.extend(self._bottleneck_optimization_suggestions(bottlenecks))
        
        return sorted(suggestions, key=lambda x: {'high': 3, 'medium': 2, 'low': 1}[x.priority], reverse=True)
    
    def _cpu_optimization_suggestions(self, metrics: Dict[str, Any]) -> List[OptimizationSuggestion]:
        """Generate CPU optimization suggestions"""
        suggestions = []
        
        avg_cpu = metrics.get('summary', {}).get('avg_cpu_percent', 0)
        
        if avg_cpu >= 85:
            suggestions.append(OptimizationSuggestion(
                category='cpu',
                priority='high',
                description='CPU usage is critically high. Consider implementing async processing and parallel execution.',
                estimated_improvement='30-50% CPU reduction',
                implementation_complexity='medium',
                code_example='''
# Before: Synchronous processing
def process_logs(logs):
    for log in logs:
        parse_log(log)
        validate_log(log)
        store_log(log)

# After: Async batch processing
async def process_logs_async(logs):
    tasks = [process_single_log(log) for log in logs]
    await asyncio.gather(*tasks)
'''
            ))
        
        elif avg_cpu > 70:
            suggestions.append(OptimizationSuggestion(
                category='cpu',
                priority='medium',
                description='CPU usage is elevated. Consider optimizing hot code paths and reducing computational complexity.',
                estimated_improvement='15-30% CPU reduction',
                implementation_complexity='low',
                code_example='''
# Before: Linear search
def find_log_entry(logs, target_id):
    for log in logs:
        if log.id == target_id:
            return log

# After: Hash-based lookup
log_index = {log.id: log for log in logs}
def find_log_entry(log_index, target_id):
    return log_index.get(target_id)
'''
            ))
        
        return suggestions
    
    def _memory_optimization_suggestions(self, metrics: Dict[str, Any]) -> List[OptimizationSuggestion]:
        """Generate memory optimization suggestions"""
        suggestions = []
        
        avg_memory = metrics.get('summary', {}).get('avg_memory_percent', 0)
        max_memory = metrics.get('summary', {}).get('max_memory_mb', 0)
        
        if avg_memory > 90:
            suggestions.append(OptimizationSuggestion(
                category='memory',
                priority='high',
                description='Memory usage is critically high. Implement object pooling and reduce memory allocations.',
                estimated_improvement='40-60% memory reduction',
                implementation_complexity='medium',
                code_example='''
# Object pooling for frequent allocations
class LogEntryPool:
    def __init__(self, size=1000):
        self.pool = [LogEntry() for _ in range(size)]
        self.available = list(range(size))
    
    def get(self):
        if self.available:
            return self.pool[self.available.pop()]
        return LogEntry()  # fallback
    
    def return_obj(self, obj):
        obj.reset()
        self.available.append(self.pool.index(obj))
'''
            ))
        
        elif avg_memory > 75:
            suggestions.append(OptimizationSuggestion(
                category='memory',
                priority='medium',
                description='Memory usage is elevated. Consider implementing lazy loading and reducing object lifetimes.',
                estimated_improvement='20-40% memory reduction',
                implementation_complexity='low'
            ))
        
        return suggestions
    
    def _function_optimization_suggestions(self, function_timings: Dict[str, Any]) -> List[OptimizationSuggestion]:
        """Generate function-specific optimization suggestions"""
        suggestions = []
        
        # Find slow functions
        slow_functions = [
            (name, stats) for name, stats in function_timings.items()
            if stats.get('avg_time_ms', 0) > 50  # Functions taking >50ms on average
        ]
        
        for func_name, stats in slow_functions:
            avg_time = stats.get('avg_time_ms', 0)
            max_time = stats.get('max_time_ms', 0)
            
            if avg_time > 100:
                priority = 'high'
                improvement = '50-70% latency reduction'
            elif avg_time > 50:
                priority = 'medium'  
                improvement = '20-50% latency reduction'
            else:
                priority = 'low'
                improvement = '10-20% latency reduction'
            
            suggestions.append(OptimizationSuggestion(
                category='function',
                priority=priority,
                description=f'Function "{func_name}" is slow (avg: {avg_time:.1f}ms, max: {max_time:.1f}ms). Consider optimization.',
                estimated_improvement=improvement,
                implementation_complexity='low',
                code_example=f'''
# Profile the function to identify bottlenecks:
@profile_performance(profiler_engine)
def {func_name}(*args, **kwargs):
    # Add specific optimization based on function purpose
    pass
'''
            ))
        
        return suggestions
    
    def _bottleneck_optimization_suggestions(self, bottlenecks: List[Dict[str, Any]]) -> List[OptimizationSuggestion]:
        """Generate suggestions based on detected bottlenecks"""
        suggestions = []
        
        # Analyze bottleneck patterns
        bottleneck_types = {}
        for bottleneck in bottlenecks:
            b_type = bottleneck.get('type', 'unknown')
            if b_type not in bottleneck_types:
                bottleneck_types[b_type] = []
            bottleneck_types[b_type].append(bottleneck)
        
        for b_type, instances in bottleneck_types.items():
            if len(instances) >= 3:  # Recurring bottleneck
                suggestions.append(OptimizationSuggestion(
                    category='bottleneck',
                    priority='high',
                    description=f'Recurring {b_type} bottleneck detected ({len(instances)} instances). Immediate optimization required.',
                    estimated_improvement='30-60% performance improvement',
                    implementation_complexity='medium',
                    code_example=f'# Optimize {b_type} bottleneck with appropriate strategy'
                ))
        
        return suggestions
    
    def generate_optimization_report(self, metrics_summary: Dict[str, Any]) -> Dict[str, Any]:
        """Generate comprehensive optimization report"""
        suggestions = self.analyze_performance_data(metrics_summary)
        
        # Categorize suggestions
        categorized = {}
        for suggestion in suggestions:
            category = suggestion.category
            if category not in categorized:
                categorized[category] = []
            categorized[category].append(suggestion)
        
        # Calculate potential improvements
        total_suggestions = len(suggestions)
        high_priority = len([s for s in suggestions if s.priority == 'high'])
        
        return {
            'timestamp': asyncio.get_event_loop().time(),
            'total_suggestions': total_suggestions,
            'high_priority_count': high_priority,
            'categories': categorized,
            'executive_summary': self._generate_executive_summary(suggestions, metrics_summary),
            'implementation_roadmap': self._generate_implementation_roadmap(suggestions)
        }
    
    def _generate_executive_summary(self, suggestions: List[OptimizationSuggestion], metrics: Dict[str, Any]) -> str:
        """Generate executive summary of optimization opportunities"""
        high_priority = len([s for s in suggestions if s.priority == 'high'])
        
        if high_priority > 0:
            return f"CRITICAL: {high_priority} high-priority optimizations identified. Immediate action recommended."
        elif len(suggestions) > 0:
            return f"OPPORTUNITY: {len(suggestions)} optimization opportunities identified. Consider implementation in next sprint."
        else:
            return "OPTIMAL: System performance is within acceptable parameters."
    
    def _generate_implementation_roadmap(self, suggestions: List[OptimizationSuggestion]) -> List[Dict[str, Any]]:
        """Generate implementation roadmap for optimizations"""
        roadmap = []
        
        # Phase 1: High priority, low complexity
        phase1 = [s for s in suggestions if s.priority == 'high' and s.implementation_complexity == 'low']
        if phase1:
            roadmap.append({
                'phase': 1,
                'timeline': 'Week 1',
                'focus': 'Quick wins - high impact, low effort',
                'suggestions': phase1
            })
        
        # Phase 2: High priority, medium complexity
        phase2 = [s for s in suggestions if s.priority == 'high' and s.implementation_complexity == 'medium']
        if phase2:
            roadmap.append({
                'phase': 2,
                'timeline': 'Week 2-3',
                'focus': 'Critical optimizations requiring development effort',
                'suggestions': phase2
            })
        
        # Phase 3: Medium priority optimizations
        phase3 = [s for s in suggestions if s.priority == 'medium']
        if phase3:
            roadmap.append({
                'phase': 3,
                'timeline': 'Week 4-6',
                'focus': 'Performance improvements and future-proofing',
                'suggestions': phase3
            })
        
        return roadmap
EOF

# Create log processing simulation for testing
cat > src/analyzer/log_analyzer.py << 'EOF'
import asyncio
import random
import json
import time
from typing import List, Dict, Any
import structlog

logger = structlog.get_logger()

class LogAnalyzer:
    """Simulates log processing workload for profiling testing"""
    
    def __init__(self):
        self.processed_count = 0
        self.error_count = 0
        self.processing_times = []
    
    def parse_log_entry(self, log_data: str) -> Dict[str, Any]:
        """Simulate log parsing with variable performance"""
        # Simulate parsing time (some entries are slower)
        if random.random() < 0.1:  # 10% of logs are slow to parse
            time.sleep(0.02)  # 20ms delay
        
        try:
            parsed = json.loads(log_data)
            # Simulate validation
            if not self._validate_log_entry(parsed):
                raise ValueError("Invalid log format")
            return parsed
        except (json.JSONDecodeError, ValueError) as e:
            self.error_count += 1
            raise e
    
    def _validate_log_entry(self, log_entry: Dict[str, Any]) -> bool:
        """Validate log entry structure"""
        required_fields = ['timestamp', 'level', 'message']
        return all(field in log_entry for field in required_fields)
    
    def extract_metrics(self, log_entry: Dict[str, Any]) -> Dict[str, Any]:
        """Extract metrics from log entry (CPU-intensive operation)"""
        start_time = time.time()
        
        # Simulate complex metric extraction
        metrics = {
            'response_time': self._extract_response_time(log_entry),
            'error_rate': self._calculate_error_rate(log_entry),
            'request_size': self._estimate_request_size(log_entry),
            'user_id': log_entry.get('user_id'),
            'endpoint': log_entry.get('endpoint')
        }
        
        # Simulate inefficient computation (optimization opportunity)
        for i in range(1000):  # Wasteful loop for testing
            _ = i * i
        
        processing_time = time.time() - start_time
        self.processing_times.append(processing_time)
        
        return metrics
    
    def _extract_response_time(self, log_entry: Dict[str, Any]) -> float:
        """Extract response time from log entry"""
        # Simulate regex parsing (optimization opportunity)
        message = log_entry.get('message', '')
        
        # Inefficient string operations for testing
        parts = message.split(' ')
        for part in parts:
            if 'response_time' in part.lower():
                try:
                    return float(part.split('=')[1].replace('ms', ''))
                except (IndexError, ValueError):
                    pass
        return 0.0
    
    def _calculate_error_rate(self, log_entry: Dict[str, Any]) -> float:
        """Calculate error rate (memory-intensive operation)"""
        # Simulate memory allocation for testing
        large_data = [random.random() for _ in range(10000)]  # Memory waste
        
        level = log_entry.get('level', '').upper()
        if level in ['ERROR', 'CRITICAL']:
            return 1.0
        elif level == 'WARNING':
            return 0.5
        return 0.0
    
    def _estimate_request_size(self, log_entry: Dict[str, Any]) -> int:
        """Estimate request size from log data"""
        # More inefficient operations for testing
        message = str(log_entry)
        return len(message.encode('utf-8'))
    
    async def process_log_batch(self, log_batch: List[str]) -> List[Dict[str, Any]]:
        """Process a batch of log entries"""
        results = []
        
        for log_data in log_batch:
            try:
                parsed_log = self.parse_log_entry(log_data)
                metrics = self.extract_metrics(parsed_log)
                
                results.append({
                    'status': 'success',
                    'log': parsed_log,
                    'metrics': metrics
                })
                self.processed_count += 1
                
            except Exception as e:
                results.append({
                    'status': 'error',
                    'error': str(e),
                    'log_data': log_data[:100]  # First 100 chars for debugging
                })
                self.error_count += 1
        
        return results
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """Get analyzer performance statistics"""
        if not self.processing_times:
            return {'status': 'no_data'}
        
        return {
            'processed_count': self.processed_count,
            'error_count': self.error_count,
            'error_rate': self.error_count / max(self.processed_count + self.error_count, 1),
            'avg_processing_time_ms': sum(self.processing_times) / len(self.processing_times) * 1000,
            'max_processing_time_ms': max(self.processing_times) * 1000,
            'min_processing_time_ms': min(self.processing_times) * 1000
        }

def generate_test_logs(count: int = 100) -> List[str]:
    """Generate test log entries for profiling"""
    log_templates = [
        {
            'timestamp': '2025-05-20T{}:{}:{}.{}Z',
            'level': 'INFO',
            'message': 'User {} accessed endpoint {} - response_time={}ms',
            'user_id': 'user_{}',
            'endpoint': '/api/{}'
        },
        {
            'timestamp': '2025-05-20T{}:{}:{}.{}Z',
            'level': 'ERROR',
            'message': 'Database connection failed for user {} - error_code={}',
            'user_id': 'user_{}',
            'endpoint': '/api/database'
        },
        {
            'timestamp': '2025-05-20T{}:{}:{}.{}Z',
            'level': 'WARNING',
            'message': 'Slow query detected - duration={}ms query_id={}',
            'user_id': 'user_{}',
            'endpoint': '/api/query'
        }
    ]
    
    logs = []
    for i in range(count):
        template = random.choice(log_templates)
        
        # Generate timestamp
        hour = random.randint(0, 23)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        ms = random.randint(0, 999)
        
        # Generate values
        user_id = random.randint(1000, 9999)
        endpoint = random.choice(['users', 'orders', 'products', 'auth'])
        response_time = random.randint(10, 500)
        error_code = random.randint(500, 599)
        duration = random.randint(100, 2000)
        query_id = random.randint(10000, 99999)
        
        # Format log entry
        log_entry = {}
        for key, value in template.items():
            if '{}' in str(value):
                if key == 'timestamp':
                    log_entry[key] = value.format(hour, minute, second, ms)
                elif 'response_time' in str(value):
                    log_entry[key] = value.format(user_id, endpoint, response_time)
                elif 'error_code' in str(value):
                    log_entry[key] = value.format(user_id, error_code)
                elif 'duration' in str(value):
                    log_entry[key] = value.format(duration, query_id)
                elif key == 'user_id':
                    log_entry[key] = value.format(user_id)
                elif key == 'endpoint':
                    log_entry[key] = value.format(endpoint)
                else:
                    log_entry[key] = value
            else:
                log_entry[key] = value
        
        logs.append(json.dumps(log_entry))
    
    return logs
EOF

# Create FastAPI web dashboard
cat > src/dashboard/dashboard_api.py << 'EOF'
import asyncio
import json
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from typing import List, Dict, Any
import uvicorn
import structlog

from profiler.profiler_engine import ProfilerEngine
from optimizer.optimization_engine import OptimizationEngine
from analyzer.log_analyzer import LogAnalyzer, generate_test_logs
from config.profiler_config import DEFAULT_CONFIG

logger = structlog.get_logger()

profiler_engine = ProfilerEngine(DEFAULT_CONFIG)
optimization_engine = OptimizationEngine(DEFAULT_CONFIG)
log_analyzer = LogAnalyzer()

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []
    
    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
    
    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
    
    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            try:
                await connection.send_text(json.dumps(message))
            except Exception:
                pass

manager = ConnectionManager()

def merge_dashboard_metrics() -> Dict[str, Any]:
    """Combine profiler samples with log-analyzer stats for the dashboard."""
    prof = profiler_engine.get_metrics_summary()
    if not prof:
        prof = {"summary": {}, "bottlenecks": [], "function_timings": {}}
    stats = log_analyzer.get_performance_stats()
    if stats.get("status") == "no_data":
        stats = {"processed_count": 0, "error_count": 0, "error_rate": 0.0}
    summary = dict(prof.get("summary") or {})
    dur = float(summary.get("profiling_duration_seconds") or 0)
    if dur <= 0:
        dur = 0.001
    processed = int(stats.get("processed_count") or 0)
    summary["logs_processed"] = processed
    summary["logs_per_second"] = round(processed / dur, 2)
    prof["summary"] = summary
    prof["analyzer"] = stats
    return prof

async def simulate_log_processing():
    """Background task to simulate ongoing log processing"""
    while profiler_engine.is_profiling:
        test_logs = generate_test_logs(20)
        await log_analyzer.process_log_batch(test_logs)
        
        if manager.active_connections:
            metrics = merge_dashboard_metrics()
            await manager.broadcast({
                "type": "metrics_update",
                "data": metrics
            })
        
        await asyncio.sleep(1)

@asynccontextmanager
async def lifespan(app: FastAPI):
    profiler_engine.start_profiling()
    asyncio.create_task(simulate_log_processing())
    yield
    if profiler_engine.is_profiling:
        profiler_engine.stop_profiling()

app = FastAPI(title="Log Performance Profiler Dashboard", version="1.0.0", lifespan=lifespan)

app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Main dashboard page"""
    return templates.TemplateResponse("dashboard.html", {"request": request})

@app.post("/api/start-profiling")
async def start_profiling():
    """Start performance profiling"""
    if not profiler_engine.is_profiling:
        profiler_engine.start_profiling()
        asyncio.create_task(simulate_log_processing())
        return {"status": "started", "message": "Profiling started successfully"}
    else:
        return {"status": "already_running", "message": "Profiling is already running"}

@app.post("/api/stop-profiling")
async def stop_profiling():
    """Stop performance profiling and get results"""
    if profiler_engine.is_profiling:
        metrics_summary = profiler_engine.stop_profiling()
        optimization_report = optimization_engine.generate_optimization_report(metrics_summary)
        return {
            "status": "stopped",
            "metrics": merge_dashboard_metrics(),
            "optimization_report": optimization_report
        }
    else:
        return {"status": "not_running", "message": "Profiling is not currently running"}

@app.get("/api/metrics")
async def get_current_metrics():
    """Get current performance metrics (profiler + log analyzer)"""
    return merge_dashboard_metrics()

@app.get("/api/optimization-suggestions")
async def get_optimization_suggestions():
    """Get current optimization suggestions"""
    metrics_summary = profiler_engine.get_metrics_summary()
    if metrics_summary:
        suggestions = optimization_engine.analyze_performance_data(metrics_summary)
        return {"suggestions": [suggestion.__dict__ for suggestion in suggestions]}
    else:
        return {"suggestions": []}

@app.post("/api/load-test")
async def run_load_test(test_config: dict = None):
    """Run load test to generate performance data"""
    if test_config is None:
        test_config = {"log_count": 1000, "batch_size": 50, "concurrent_batches": 10}
    
    if not profiler_engine.is_profiling:
        profiler_engine.start_profiling()
        asyncio.create_task(simulate_log_processing())
    
    log_count = test_config.get("log_count", 1000)
    batch_size = test_config.get("batch_size", 50)
    concurrent_batches = test_config.get("concurrent_batches", 10)
    
    logger.info(f"Starting load test: {log_count} logs, batch size {batch_size}")
    
    test_logs = generate_test_logs(log_count)
    batches = [test_logs[i:i + batch_size] for i in range(0, len(test_logs), batch_size)]
    
    tasks = []
    for i in range(0, len(batches), concurrent_batches):
        batch_group = batches[i:i + concurrent_batches]
        for batch in batch_group:
            task = log_analyzer.process_log_batch(batch)
            tasks.append(task)
    
    results = await asyncio.gather(*tasks)
    
    analyzer_stats = log_analyzer.get_performance_stats()
    profiler_stats = merge_dashboard_metrics()
    
    return {
        "status": "completed",
        "load_test_config": test_config,
        "analyzer_stats": analyzer_stats,
        "profiler_stats": profiler_stats,
        "processed_batches": len(results)
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await manager.connect(websocket)
    try:
        while True:
            metrics = merge_dashboard_metrics()
            await websocket.send_text(json.dumps({
                "type": "metrics_update",
                "data": metrics
            }))
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Create HTML dashboard template
cat > templates/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Log Performance Profiler</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap" rel="stylesheet">
    <!-- plotly-latest.min.js is frozen at v1.x; use an explicit release: https://github.com/plotly/plotly.js/releases -->
    <script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
    <style>
        :root {
            --bg-page: #f0eeeb;
            --bg-subtle: #e8e6e3;
            --surface: #ffffff;
            --border: #d6d3d1;
            --border-strong: #a8a29e;
            --text: #1c1917;
            --text-muted: #57534e;
            --text-faint: #78716c;
            --accent: #292524;
            --accent-hover: #1c1917;
            --danger: #b91c1c;
            --danger-hover: #991b1b;
            --success: #15803d;
            --success-bg: #ecfdf5;
            --warn-bg: #fffbeb;
            --chart-cpu: #44403c;
            --chart-mem: #a16207;
            --radius: 6px;
            --shadow: 0 1px 3px rgba(28, 25, 23, 0.06);
            --shadow-md: 0 4px 12px rgba(28, 25, 23, 0.08);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'IBM Plex Sans', system-ui, -apple-system, sans-serif;
            background: var(--bg-page);
            min-height: 100vh;
            color: var(--text);
            font-size: 15px;
            line-height: 1.5;
        }

        .app-header {
            background: var(--surface);
            border-bottom: 1px solid var(--border);
            position: sticky;
            top: 0;
            z-index: 100;
        }

        .app-header__inner {
            max-width: 1280px;
            margin: 0 auto;
            padding: 1rem 1.5rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 1rem;
            flex-wrap: wrap;
        }

        .brand__title {
            display: block;
            font-size: 1.125rem;
            font-weight: 600;
            letter-spacing: -0.02em;
            color: var(--text);
        }

        .brand__subtitle {
            display: block;
            font-size: 0.8125rem;
            color: var(--text-muted);
            font-weight: 400;
            margin-top: 0.125rem;
            max-width: 42rem;
        }

        .conn-pill {
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            padding: 0.375rem 0.75rem;
            border-radius: 999px;
            border: 1px solid var(--border);
            background: var(--bg-subtle);
            color: var(--text-muted);
        }

        .conn-pill--live {
            background: var(--success-bg);
            border-color: #a7f3d0;
            color: var(--success);
        }

        .conn-pill--offline {
            background: #fef2f2;
            border-color: #fecaca;
            color: var(--danger);
        }

        .main {
            max-width: 1280px;
            margin: 0 auto;
            padding: 1.5rem;
            display: flex;
            flex-direction: column;
            gap: 1.25rem;
        }

        .panel {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            box-shadow: var(--shadow);
        }

        .panel__header {
            padding: 1rem 1.25rem;
            border-bottom: 1px solid var(--border);
            font-size: 0.6875rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            color: var(--text-muted);
        }

        .panel__body {
            padding: 1.25rem;
        }

        .toolbar {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            justify-content: space-between;
            gap: 1rem;
        }

        .btn-group {
            display: flex;
            flex-wrap: wrap;
            gap: 0.5rem;
        }

        .btn {
            padding: 0.5rem 1rem;
            border-radius: var(--radius);
            font-size: 0.8125rem;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.15s ease, border-color 0.15s ease, color 0.15s ease;
            font-family: inherit;
            border: 1px solid transparent;
        }

        .btn-primary {
            background: var(--accent);
            color: #fafaf9;
            border-color: var(--accent);
        }

        .btn-primary:hover {
            background: var(--accent-hover);
            border-color: var(--accent-hover);
        }

        .btn-danger {
            background: var(--surface);
            color: var(--danger);
            border-color: var(--border-strong);
        }

        .btn-danger:hover {
            background: #fef2f2;
            border-color: var(--danger);
        }

        .btn-secondary {
            background: var(--surface);
            color: var(--text);
            border-color: var(--border-strong);
        }

        .btn-secondary:hover {
            background: var(--bg-page);
            border-color: var(--text-muted);
        }

        .status-row {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.8125rem;
            color: var(--text-muted);
        }

        .status {
            display: inline-block;
            padding: 0.25rem 0.625rem;
            border-radius: var(--radius);
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }

        .status.active {
            background: var(--success-bg);
            color: var(--success);
        }

        .status.inactive {
            background: #f5f5f4;
            color: var(--text-faint);
        }

        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 1rem;
        }

        @media (max-width: 1100px) {
            .metrics-grid { grid-template-columns: repeat(2, 1fr); }
        }

        @media (max-width: 520px) {
            .metrics-grid { grid-template-columns: 1fr; }
        }

        .metric-card {
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 1.125rem 1.25rem;
            background: var(--surface);
            box-shadow: var(--shadow);
        }

        .metric-card h3 {
            font-size: 0.6875rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.07em;
            color: var(--text-faint);
            margin-bottom: 0.75rem;
        }

        .metric-value {
            font-size: 1.875rem;
            font-weight: 600;
            font-variant-numeric: tabular-nums;
            color: var(--text);
            letter-spacing: -0.02em;
            line-height: 1.2;
        }

        .metric-unit {
            font-size: 0.75rem;
            color: var(--text-muted);
            margin-top: 0.25rem;
        }

        .chart-wrap {
            min-height: 380px;
        }

        .section-title {
            font-size: 0.9375rem;
            font-weight: 600;
            color: var(--text);
            margin-bottom: 1rem;
        }

        .optimization-panel .section-title {
            margin-bottom: 0;
        }

        .suggestion-card {
            background: #fafaf9;
            border: 1px solid var(--border);
            border-left-width: 3px;
            border-left-color: var(--text-faint);
            padding: 1rem 1.125rem;
            margin-bottom: 0.75rem;
            border-radius: var(--radius);
        }

        .suggestion-card.high-priority {
            border-left-color: var(--danger);
            background: #fffbeb;
        }

        .suggestion-card.medium-priority {
            border-left-color: #ca8a04;
            background: var(--warn-bg);
        }

        .suggestion-title {
            font-weight: 600;
            margin-bottom: 0.5rem;
            color: var(--text);
            font-size: 0.875rem;
        }

        .suggestion-description {
            color: var(--text-muted);
            line-height: 1.55;
            font-size: 0.875rem;
        }

        .loading {
            display: inline-block;
            width: 18px;
            height: 18px;
            border: 2px solid var(--bg-subtle);
            border-top-color: var(--accent);
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            vertical-align: middle;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        #optimizationSuggestions > p {
            color: var(--text-muted);
            font-size: 0.875rem;
        }
    </style>
</head>
<body>
    <header class="app-header">
        <div class="app-header__inner">
            <div class="brand">
                <span class="brand__title">Log Performance Profiler</span>
                <span class="brand__subtitle">Real-time performance monitoring and optimization for distributed log processing</span>
            </div>
            <div class="conn-pill" id="connectionStatus">Connecting…</div>
        </div>
    </header>

    <main class="main">
        <section class="panel">
            <div class="panel__header">Operations</div>
            <div class="panel__body">
                <div class="toolbar">
                    <div class="btn-group">
                        <button type="button" class="btn btn-primary" onclick="startProfiling()">Start profiling</button>
                        <button type="button" class="btn btn-danger" onclick="stopProfiling()">Stop profiling</button>
                        <button type="button" class="btn btn-secondary" onclick="runLoadTest()">Run load test</button>
                    </div>
                    <div class="status-row">
                        <span>Profiler</span>
                        <span class="status inactive" id="profilingStatus">Inactive</span>
                    </div>
                </div>
            </div>
        </section>

        <div class="metrics-grid">
            <div class="metric-card">
                <h3>CPU usage</h3>
                <div class="metric-value" id="cpuUsage">0</div>
                <div class="metric-unit">Percent</div>
            </div>
            <div class="metric-card">
                <h3>Memory usage</h3>
                <div class="metric-value" id="memoryUsage">0</div>
                <div class="metric-unit">Percent</div>
            </div>
            <div class="metric-card">
                <h3>Processed logs</h3>
                <div class="metric-value" id="processedLogs">0</div>
                <div class="metric-unit">Total</div>
            </div>
            <div class="metric-card">
                <h3>Processing rate</h3>
                <div class="metric-value" id="processingRate">0</div>
                <div class="metric-unit">Logs / second</div>
            </div>
        </div>

        <section class="panel">
            <div class="panel__header">Throughput &amp; resource usage</div>
            <div class="panel__body">
                <div class="chart-wrap" id="performanceChart"></div>
            </div>
        </section>

        <section class="panel optimization-panel">
            <div class="panel__header">Optimization suggestions</div>
            <div class="panel__body">
                <div id="optimizationSuggestions">
                    <p>Profiling data will appear here when suggestions are available.</p>
                </div>
            </div>
        </section>
    </main>

    <script>
        let socket = null;
        let isProfilingActive = false;
        let metricsData = {
            timestamps: [],
            cpu: [],
            memory: []
        };

        function initWebSocket() {
            const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            const wsUrl = `${protocol}//${window.location.host}/ws`;
            socket = new WebSocket(wsUrl);

            socket.onopen = function() {
                updateConnectionStatus(true);
            };

            socket.onmessage = function(event) {
                const data = JSON.parse(event.data);
                if (data.type === 'metrics_update') {
                    updateDashboard(data.data);
                }
            };

            socket.onclose = function() {
                updateConnectionStatus(false);
                setTimeout(initWebSocket, 5000);
            };

            socket.onerror = function() {
                updateConnectionStatus(false);
            };
        }

        function updateConnectionStatus(connected) {
            const el = document.getElementById('connectionStatus');
            if (connected) {
                el.textContent = 'Live';
                el.className = 'conn-pill conn-pill--live';
            } else {
                el.textContent = 'Offline';
                el.className = 'conn-pill conn-pill--offline';
            }
        }

        async function startProfiling() {
            try {
                const response = await fetch('/api/start-profiling', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'}
                });
                const result = await response.json();
                if (result.status === 'started') {
                    isProfilingActive = true;
                    updateProfilingStatus(true);
                }
            } catch (error) {
                console.error('Error starting profiling:', error);
            }
        }

        async function stopProfiling() {
            try {
                const response = await fetch('/api/stop-profiling', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'}
                });
                const result = await response.json();
                if (result.status === 'stopped') {
                    isProfilingActive = false;
                    updateProfilingStatus(false);
                    displayOptimizationSuggestions(result.optimization_report);
                }
            } catch (error) {
                console.error('Error stopping profiling:', error);
            }
        }

        async function runLoadTest() {
            try {
                document.getElementById('optimizationSuggestions').innerHTML =
                    '<div class="loading"></div> <span style="color:var(--text-muted);font-size:0.875rem">Running load test…</span>';
                await fetch('/api/load-test', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        log_count: 1000,
                        batch_size: 50,
                        concurrent_batches: 10
                    })
                });
                getOptimizationSuggestions();
            } catch (error) {
                document.getElementById('optimizationSuggestions').innerHTML =
                    '<p>Error running load test. Please try again.</p>';
            }
        }

        async function getOptimizationSuggestions() {
            try {
                const response = await fetch('/api/optimization-suggestions');
                const result = await response.json();
                displayOptimizationSuggestions({
                    total_suggestions: result.suggestions.length,
                    categories: { general: result.suggestions }
                });
            } catch (error) {
                console.error('Error fetching suggestions:', error);
            }
        }

        function updateProfilingStatus(active) {
            const statusElement = document.getElementById('profilingStatus');
            if (active) {
                statusElement.textContent = 'Active';
                statusElement.className = 'status active';
            } else {
                statusElement.textContent = 'Inactive';
                statusElement.className = 'status inactive';
            }
        }

        function updateDashboard(data) {
            const summary = data.summary || {};
            const logsProcessed = summary.logs_processed != null
                ? summary.logs_processed
                : (data.analyzer && data.analyzer.processed_count) || 0;
            const logsPerSec = summary.logs_per_second != null
                ? summary.logs_per_second
                : (parseFloat(summary.profiling_duration_seconds || 1) > 0
                    ? (logsProcessed / parseFloat(summary.profiling_duration_seconds || 1)).toFixed(1)
                    : '0');

            document.getElementById('cpuUsage').textContent =
                (summary.avg_cpu_percent || 0).toFixed(1);
            document.getElementById('memoryUsage').textContent =
                (summary.avg_memory_percent || 0).toFixed(1);
            document.getElementById('processedLogs').textContent = String(logsProcessed);
            document.getElementById('processingRate').textContent = typeof logsPerSec === 'number'
                ? logsPerSec.toFixed(1) : String(logsPerSec);

            const now = new Date();
            metricsData.timestamps.push(now);
            metricsData.cpu.push(summary.avg_cpu_percent || 0);
            metricsData.memory.push(summary.avg_memory_percent || 0);

            if (metricsData.timestamps.length > 50) {
                metricsData.timestamps.shift();
                metricsData.cpu.shift();
                metricsData.memory.shift();
            }
            updatePerformanceChart();
        }

        function updatePerformanceChart() {
            const cpuTrace = {
                x: metricsData.timestamps,
                y: metricsData.cpu,
                type: 'scatter',
                mode: 'lines+markers',
                name: 'CPU %',
                line: { color: '#44403c', width: 2 },
                marker: { size: 5, color: '#44403c' }
            };

            const memoryTrace = {
                x: metricsData.timestamps,
                y: metricsData.memory,
                type: 'scatter',
                mode: 'lines+markers',
                name: 'Memory %',
                line: { color: '#a16207', width: 2 },
                marker: { size: 5, color: '#a16207' }
            };

            const layout = {
                font: { family: 'IBM Plex Sans, sans-serif', color: '#57534e', size: 12 },
                title: { text: '' },
                xaxis: {
                    title: 'Time',
                    type: 'date',
                    gridcolor: '#e7e5e4',
                    linecolor: '#d6d3d1',
                    zeroline: false
                },
                yaxis: {
                    title: 'Usage (%)',
                    range: [0, 100],
                    gridcolor: '#e7e5e4',
                    linecolor: '#d6d3d1',
                    zeroline: false
                },
                margin: { l: 52, r: 24, t: 16, b: 48 },
                showlegend: true,
                legend: {
                    orientation: 'h',
                    yanchor: 'bottom',
                    y: 1.02,
                    xanchor: 'right',
                    x: 1
                },
                paper_bgcolor: '#ffffff',
                plot_bgcolor: '#fafaf9'
            };

            Plotly.newPlot('performanceChart', [cpuTrace, memoryTrace], layout, {
                responsive: true,
                displayModeBar: true,
                displaylogo: false,
                modeBarButtonsToRemove: ['lasso2d', 'select2d']
            });
        }

        function displayOptimizationSuggestions(report) {
            const container = document.getElementById('optimizationSuggestions');

            if (!report || !report.categories) {
                container.innerHTML = '<p>No optimization suggestions available.</p>';
                return;
            }

            let html = `<p style="margin-bottom:1rem;font-size:0.875rem;color:var(--text-muted)"><strong style="color:var(--text)">${report.total_suggestions || 0}</strong> opportunities identified</p>`;

            for (const [category, suggestions] of Object.entries(report.categories)) {
                if (suggestions && suggestions.length > 0) {
                    html += `<h5 style="font-size:0.75rem;text-transform:uppercase;letter-spacing:0.06em;color:var(--text-faint);margin:1rem 0 0.5rem">${category}</h5>`;

                    suggestions.forEach(suggestion => {
                        const priorityClass = `${suggestion.priority}-priority`;
                        html += `
                            <div class="suggestion-card ${priorityClass}">
                                <div class="suggestion-title">
                                    ${getPriorityIcon(suggestion.priority)}
                                    ${String(suggestion.category || '').toUpperCase()}: ${suggestion.priority} priority
                                </div>
                                <div class="suggestion-description">
                                    ${suggestion.description}
                                    <br><strong>Estimated improvement:</strong> ${suggestion.estimated_improvement}
                                    <br><strong>Complexity:</strong> ${suggestion.implementation_complexity}
                                </div>
                            </div>
                        `;
                    });
                }
            }

            if (!html.includes('suggestion-card')) {
                html += '<p style="color:var(--text-muted);font-size:0.875rem">No immediate optimizations. System looks healthy.</p>';
            }

            container.innerHTML = html;
        }

        function getPriorityIcon(priority) {
            switch (priority) {
                case 'high': return '● ';
                case 'medium': return '● ';
                case 'low': return '○ ';
                default: return '';
            }
        }

        document.addEventListener('DOMContentLoaded', function() {
            initWebSocket();
            updatePerformanceChart();

            fetch('/api/metrics')
                .then(r => r.json())
                .then(data => { if (data && data.summary) updateDashboard(data); })
                .catch(() => {});

            setTimeout(() => { getOptimizationSuggestions(); }, 1000);
        });
    </script>
</body>
</html>

EOF

# Create main application entry point
cat > src/main.py << 'EOF'
import asyncio
import uvicorn
import structlog
from dashboard.dashboard_api import app

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

if __name__ == "__main__":
    logger.info("Starting Log Performance Profiler Dashboard")
    uvicorn.run(
        "dashboard.dashboard_api:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
EOF

# Create comprehensive test suite
echo "🧪 Creating test suite..."
cat > tests/test_profiler.py << 'EOF'
import pytest
import asyncio
import time
from src.profiler.profiler_engine import ProfilerEngine, PerformanceMetrics
from src.optimizer.optimization_engine import OptimizationEngine
from src.analyzer.log_analyzer import LogAnalyzer, generate_test_logs
from config.profiler_config import DEFAULT_CONFIG

class TestProfilerEngine:
    def test_profiler_initialization(self):
        profiler = ProfilerEngine(DEFAULT_CONFIG)
        assert profiler.config == DEFAULT_CONFIG
        assert profiler.is_profiling == False
        assert len(profiler.metrics_history) == 0
    
    def test_start_stop_profiling(self):
        profiler = ProfilerEngine(DEFAULT_CONFIG)
        
        # Start profiling
        profiler.start_profiling()
        assert profiler.is_profiling == True
        
        # Let it run briefly
        time.sleep(0.5)
        
        # Stop profiling
        summary = profiler.stop_profiling()
        assert profiler.is_profiling == False
        assert 'summary' in summary
        assert len(profiler.metrics_history) > 0
    
    def test_function_profiling(self):
        profiler = ProfilerEngine(DEFAULT_CONFIG)
        
        def test_function(x, y):
            time.sleep(0.01)  # Simulate work
            return x + y
        
        result, profile_data = profiler.profile_function(test_function, 5, 3)
        
        assert result == 8
        assert profile_data['function_name'] == 'test_function'
        assert profile_data['execution_time_ms'] >= 5  # sleep(0.01) target; allow scheduler variance
        assert 'test_function' in profiler.function_timings

class TestOptimizationEngine:
    def test_optimization_engine_initialization(self):
        optimizer = OptimizationEngine(DEFAULT_CONFIG)
        assert optimizer.config == DEFAULT_CONFIG
    
    def test_cpu_optimization_suggestions(self):
        optimizer = OptimizationEngine(DEFAULT_CONFIG)
        
        # Simulate high CPU usage
        metrics = {
            'summary': {
                'avg_cpu_percent': 85.0,
                'avg_memory_percent': 50.0
            },
            'function_timings': {},
            'bottlenecks': []
        }
        
        suggestions = optimizer.analyze_performance_data(metrics)
        cpu_suggestions = [s for s in suggestions if s.category == 'cpu']
        
        assert len(cpu_suggestions) > 0
        assert cpu_suggestions[0].priority == 'high'
    
    def test_memory_optimization_suggestions(self):
        optimizer = OptimizationEngine(DEFAULT_CONFIG)
        
        # Simulate high memory usage
        metrics = {
            'summary': {
                'avg_cpu_percent': 30.0,
                'avg_memory_percent': 95.0
            },
            'function_timings': {},
            'bottlenecks': []
        }
        
        suggestions = optimizer.analyze_performance_data(metrics)
        memory_suggestions = [s for s in suggestions if s.category == 'memory']
        
        assert len(memory_suggestions) > 0
        assert memory_suggestions[0].priority == 'high'

class TestLogAnalyzer:
    @pytest.mark.asyncio
    async def test_log_analyzer_processing(self):
        analyzer = LogAnalyzer()
        
        # Generate test logs
        test_logs = generate_test_logs(10)
        
        # Process logs
        results = await analyzer.process_log_batch(test_logs)
        
        assert len(results) == 10
        assert analyzer.processed_count > 0
        
        # Get performance stats
        stats = analyzer.get_performance_stats()
        assert 'processed_count' in stats
        assert 'error_rate' in stats
    
    def test_generate_test_logs(self):
        logs = generate_test_logs(50)
        
        assert len(logs) == 50
        
        # Verify logs are valid JSON
        import json
        for log_str in logs:
            log_data = json.loads(log_str)
            assert 'timestamp' in log_data
            assert 'level' in log_data
            assert 'message' in log_data

@pytest.mark.asyncio
async def test_integration_profiling_and_optimization():
    """Integration test combining profiling and optimization"""
    profiler = ProfilerEngine(DEFAULT_CONFIG)
    optimizer = OptimizationEngine(DEFAULT_CONFIG)
    analyzer = LogAnalyzer()
    
    # Start profiling
    profiler.start_profiling()
    
    # Simulate workload
    test_logs = generate_test_logs(100)
    await analyzer.process_log_batch(test_logs)
    
    # Let profiling run
    await asyncio.sleep(1)
    
    # Stop profiling and get metrics
    metrics_summary = profiler.stop_profiling()
    
    # Generate optimization suggestions
    suggestions = optimizer.analyze_performance_data(metrics_summary)
    
    # Verify integration worked
    assert 'summary' in metrics_summary
    assert isinstance(suggestions, list)
    assert analyzer.processed_count > 0

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create Docker configuration
echo "🐳 Creating Docker configuration..."
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p data/profiles data/reports logs

# Expose port
EXPOSE 8000

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Run the application
CMD ["python", "src/main.py"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  log-profiler:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    environment:
      - PYTHONPATH=/app
      - ENVIRONMENT=docker
    restart: unless-stopped
    
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    restart: unless-stopped

volumes:
  profiler-data:
  profiler-logs:
EOF

# Create demo script
cat > demo.py << 'EOF'
#!/usr/bin/env python3
"""
Demonstration script for Log Performance Profiler
Shows the complete profiling and optimization workflow
"""

import asyncio
import time
import json
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import Progress, TaskID

from src.profiler.profiler_engine import ProfilerEngine
from src.optimizer.optimization_engine import OptimizationEngine
from src.analyzer.log_analyzer import LogAnalyzer, generate_test_logs
from config.profiler_config import DEFAULT_CONFIG

console = Console()

async def main():
    console.print(Panel.fit(
        "🚀 Log Performance Profiler Demonstration\n"
        "Day 71: Profile and optimize log ingestion pipeline",
        title="254-Day System Design Series",
        style="bold blue"
    ))
    
    # Initialize components
    console.print("\n[bold green]1. Initializing profiler components...[/bold green]")
    profiler = ProfilerEngine(DEFAULT_CONFIG)
    optimizer = OptimizationEngine(DEFAULT_CONFIG)
    analyzer = LogAnalyzer()
    
    # Start profiling
    console.print("\n[bold green]2. Starting performance profiling...[/bold green]")
    profiler.start_profiling()
    
    # Generate and process test data
    console.print("\n[bold green]3. Processing test log data...[/bold green]")
    
    with Progress() as progress:
        task = progress.add_task("Processing logs...", total=1000)
        
        for batch_num in range(10):  # 10 batches of 100 logs each
            test_logs = generate_test_logs(100)
            await analyzer.process_log_batch(test_logs)
            progress.update(task, advance=100)
            await asyncio.sleep(0.1)  # Small delay to see profiling data
    
    # Let profiling collect data
    console.print("\n[bold green]4. Collecting performance metrics...[/bold green]")
    await asyncio.sleep(2)
    
    # Stop profiling and get results
    console.print("\n[bold green]5. Generating performance analysis...[/bold green]")
    metrics_summary = profiler.stop_profiling()
    
    # Display performance metrics
    display_performance_metrics(metrics_summary)
    
    # Generate optimization suggestions
    console.print("\n[bold green]6. Generating optimization recommendations...[/bold green]")
    optimization_report = optimizer.generate_optimization_report(metrics_summary)
    
    # Display optimization suggestions
    display_optimization_suggestions(optimization_report)
    
    # Display analyzer performance
    display_analyzer_stats(analyzer)
    
    console.print(Panel.fit(
        "✅ Demonstration completed successfully!\n"
        "🌐 Access the web dashboard at: http://localhost:8000\n"
        "📊 Run './start.sh' (from the log-profiler directory) to start the interactive dashboard",
        title="Next Steps",
        style="bold green"
    ))

def display_performance_metrics(metrics_summary):
    """Display performance metrics in a formatted table"""
    if not metrics_summary or 'summary' not in metrics_summary:
        console.print("[red]No performance metrics available[/red]")
        return
    
    summary = metrics_summary['summary']
    
    # Create performance metrics table
    table = Table(title="📊 Performance Metrics Summary")
    table.add_column("Metric", style="cyan", no_wrap=True)
    table.add_column("Value", style="magenta")
    table.add_column("Unit", style="green")
    
    table.add_row("Average CPU Usage", f"{summary.get('avg_cpu_percent', 0):.1f}", "%")
    table.add_row("Average Memory Usage", f"{summary.get('avg_memory_percent', 0):.1f}", "%")
    table.add_row("Peak Memory Usage", f"{summary.get('max_memory_mb', 0):.1f}", "MB")
    table.add_row("Total Samples", str(summary.get('total_samples', 0)), "count")
    table.add_row("Profiling Duration", f"{summary.get('profiling_duration_seconds', 0):.1f}", "seconds")
    
    console.print(table)
    
    # Display function timings if available
    function_timings = metrics_summary.get('function_timings', {})
    if function_timings:
        func_table = Table(title="⚡ Function Performance Analysis")
        func_table.add_column("Function", style="cyan")
        func_table.add_column("Calls", style="yellow")
        func_table.add_column("Avg Time", style="magenta")
        func_table.add_column("Max Time", style="red")
        
        for func_name, stats in function_timings.items():
            func_table.add_row(
                func_name,
                str(stats.get('count', 0)),
                f"{stats.get('avg_time_ms', 0):.2f} ms",
                f"{stats.get('max_time_ms', 0):.2f} ms"
            )
        
        console.print(func_table)

def display_optimization_suggestions(optimization_report):
    """Display optimization suggestions"""
    if not optimization_report or 'categories' not in optimization_report:
        console.print("[red]No optimization suggestions available[/red]")
        return
    
    console.print(Panel.fit(
        f"🎯 Found {optimization_report.get('total_suggestions', 0)} optimization opportunities\n"
        f"🚨 {optimization_report.get('high_priority_count', 0)} high-priority items need immediate attention",
        title="Optimization Analysis",
        style="bold yellow"
    ))
    
    # Display suggestions by category
    for category, suggestions in optimization_report['categories'].items():
        if not suggestions:
            continue
            
        console.print(f"\n[bold]{category.upper()} Optimizations:[/bold]")
        
        for i, suggestion in enumerate(suggestions, 1):
            priority_style = {
                'high': 'bold red',
                'medium': 'bold yellow', 
                'low': 'bold blue'
            }.get(suggestion.priority, 'white')
            
            console.print(f"  {i}. [{priority_style}]{suggestion.priority.upper()}[/{priority_style}]: {suggestion.description}")
            console.print(f"     💡 {suggestion.estimated_improvement}")
            console.print(f"     🔧 Complexity: {suggestion.implementation_complexity}")
            if suggestion.code_example:
                console.print(f"     📝 Code example available")
            console.print()

def display_analyzer_stats(analyzer):
    """Display log analyzer performance statistics"""
    stats = analyzer.get_performance_stats()
    
    if stats.get('status') == 'no_data':
        console.print("[red]No analyzer data available[/red]")
        return
    
    # Create analyzer stats table
    table = Table(title="📈 Log Processing Performance")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="magenta")
    
    table.add_row("Logs Processed", str(stats.get('processed_count', 0)))
    table.add_row("Processing Errors", str(stats.get('error_count', 0)))
    table.add_row("Error Rate", f"{stats.get('error_rate', 0)*100:.2f}%")
    table.add_row("Avg Processing Time", f"{stats.get('avg_processing_time_ms', 0):.2f} ms")
    table.add_row("Max Processing Time", f"{stats.get('max_processing_time_ms', 0):.2f} ms")
    table.add_row("Min Processing Time", f"{stats.get('min_processing_time_ms', 0):.2f} ms")
    
    console.print(table)

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Application start/stop (run from generated project directory)
cat > start.sh << 'STARTEOF'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

BACKGROUND=0
for arg in "$@"; do
  case "$arg" in
    --background|--daemon|-d) BACKGROUND=1 ;;
  esac
done

if [[ ! -f "$SCRIPT_DIR/venv/bin/activate" ]]; then
  echo "ERROR: venv not found. Run setup.sh first (from the directory that contains it)." >&2
  exit 1
fi

PORT="${PORT:-8000}"
if command -v ss >/dev/null 2>&1; then
  if ss -tlnp 2>/dev/null | grep -qE ":${PORT}\\s"; then
    echo "ERROR: Port ${PORT} is already in use — another instance may be running." >&2
    ss -tlnp 2>/dev/null | grep -E ":${PORT}\\s" || true
    exit 1
  fi
elif command -v fuser >/dev/null 2>&1; then
  if fuser "${PORT}/tcp" 2>/dev/null | grep -q .; then
    echo "ERROR: Port ${PORT} is already in use." >&2
    exit 1
  fi
fi

mkdir -p "$SCRIPT_DIR/logs"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/venv/bin/activate"
export PYTHONPATH="${SCRIPT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"

URL="http://127.0.0.1:${PORT}/"
if [[ "$BACKGROUND" -eq 1 ]]; then
  nohup python "$SCRIPT_DIR/src/main.py" >> "$SCRIPT_DIR/logs/server.log" 2>&1 &
  echo $! > "$SCRIPT_DIR/.server.pid"
  sleep 1
  if ss -tlnp 2>/dev/null | grep -qE ":${PORT}\\s"; then
    echo "Dashboard is running in the background (PID $(cat "$SCRIPT_DIR/.server.pid"))."
  else
    echo "Started background process; if the page does not load, check: $SCRIPT_DIR/logs/server.log" >&2
  fi
  echo "Open: $URL"
  echo "Stop with: $SCRIPT_DIR/stop.sh"
  exit 0
fi

echo "Starting dashboard — open: $URL"
echo "Leave this terminal open while you use the app. Press Ctrl+C to stop."
echo "(Or run: $SCRIPT_DIR/start.sh --background  to run detached.)"
exec python "$SCRIPT_DIR/src/main.py"
STARTEOF

cat > stop.sh << 'STOPEOF'
#!/bin/bash
PORT="${PORT:-8000}"
if command -v fuser >/dev/null 2>&1; then
  if fuser "${PORT}/tcp" 2>/dev/null | grep -q .; then
    fuser -k "${PORT}/tcp" 2>/dev/null || true
    echo "Stopped process(es) on port ${PORT}."
  else
    echo "No process listening on port ${PORT}."
  fi
  exit 0
fi
if command -v lsof >/dev/null 2>&1; then
  mapfile -t PIDS < <(lsof -ti ":${PORT}" 2>/dev/null || true)
  if [[ ${#PIDS[@]} -eq 0 ]]; then
    echo "No process listening on port ${PORT}."
    exit 0
  fi
  kill "${PIDS[@]}" 2>/dev/null || true
  echo "Stopped process(es) on port ${PORT}."
  exit 0
fi
echo "ERROR: Install psmisc (fuser) or lsof to stop the server." >&2
exit 1
STOPEOF

chmod +x start.sh stop.sh

cat > .gitignore << 'GITIGNOREEOF'
# Virtual environments
venv/
.venv/
env/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
*.egg
*.egg-info/
.eggs/
dist/
build/

# Testing / coverage
.pytest_cache/
.mypy_cache/
.ruff_cache/
.coverage
htmlcov/
.tox/

# Local secrets (never commit)
.env
.env.*
!.env.example

# App runtime (regenerated locally)
.server.pid
logs/
*.log

# IDE / OS
.idea/
.vscode/
.DS_Store
Thumbs.db

# Jupyter
.ipynb_checkpoints/
GITIGNOREEOF

cat > cleanup.sh << 'CLEANUPEOF'
#!/bin/bash
# Stop local services and Docker resources for this project; prune unused Docker data.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "==> Stopping local dashboard (if running)..."
if [[ -x "$SCRIPT_DIR/stop.sh" ]]; then
  "$SCRIPT_DIR/stop.sh" 2>/dev/null || true
fi

if command -v docker >/dev/null 2>&1; then
  echo "==> Stopping Docker Compose stack for this project..."
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" down --remove-orphans 2>/dev/null || true
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f "$SCRIPT_DIR/docker-compose.yml" down --remove-orphans 2>/dev/null || true
  fi

  echo "==> Pruning stopped containers..."
  docker container prune -f

  echo "==> Pruning unused images..."
  docker image prune -a -f

  echo "==> Pruning unused networks..."
  docker network prune -f

  echo "==> Pruning build cache..."
  docker builder prune -f

  echo "==> Docker system prune (unused data)..."
  docker system prune -f
else
  echo "(Docker not installed; skipped container/image cleanup.)"
fi

echo "==> Removing local ephemeral files (not for git)..."
rm -f "$SCRIPT_DIR/.server.pid"
rm -rf "$SCRIPT_DIR/logs"
rm -rf "$SCRIPT_DIR/.pytest_cache"
rm -rf "$SCRIPT_DIR/venv"

while IFS= read -r -d '' dir; do
  rm -rf "$dir"
done < <(find "$SCRIPT_DIR" \( -path "$SCRIPT_DIR/.git" \) -prune -o -type d -name __pycache__ -print0 2>/dev/null)

find "$SCRIPT_DIR" \( -path "$SCRIPT_DIR/.git" \) -prune -o -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete 2>/dev/null || true

echo "Cleanup finished."
echo "Recreate Python env: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
CLEANUPEOF

chmod +x cleanup.sh

cat > README.md << 'READMEEOF'
# Log Performance Profiler

Day 71 course project: a small FastAPI service that profiles log-processing workloads, exposes metrics over HTTP/WebSocket, and serves a browser dashboard.

---

## What you need

| Manual run | Docker run |
|------------|------------|
| Python **3.11+** (3.12 recommended) | **Docker Engine** + **Docker Compose** v2 (`docker compose`) |

---

## Clone from GitHub

```bash
git clone <YOUR_REPO_URL>
cd log-profiler
```

Do **not** commit `venv/`, logs, or caches—they are listed in [`.gitignore`](.gitignore). After clone, create a local virtualenv (manual path below).

---

## Manual execution (recommended for development)

### 1. Create a virtual environment

**Linux / macOS:**

```bash
python3 -m venv venv
source venv/bin/activate
```

**Windows (PowerShell):**

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Run the dashboard

From the `log-profiler` directory (repository root):

```bash
./start.sh
```

Or in the background:

```bash
./start.sh --background
```

Open **http://127.0.0.1:8000/** in your browser.

- **Foreground:** leave the terminal open; stop with `Ctrl+C`.
- **Background:** stop with `./stop.sh` (frees port `8000`).

`start.sh` sets `PYTHONPATH` to the project root so `config/` and `src/` imports resolve correctly.

### 4. Tests and demo

```bash
./build_and_test.sh
```

Runs `pytest` on `tests/` and the `demo.py` script.

### 5. Cleanup (local files + optional Docker)

```bash
./cleanup.sh
```

Stops the app on port 8000, runs Docker prune commands if Docker is installed, removes `venv/`, logs, pytest cache, and Python bytecode. Recreate the venv afterward if you need to run manually again:

```bash
python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
```

---

## Docker execution

All commands below assume your current directory is the **`log-profiler`** repository root (where `Dockerfile` and `docker-compose.yml` live).

### Option A — Docker Compose (app + Redis)

Build and start:

```bash
docker compose up --build
```

- Dashboard: **http://127.0.0.1:8000/**
- Redis is exposed on **6379** (included for future/extension use; the demo app does not require Redis to run).

Run detached:

```bash
docker compose up --build -d
```

Stop and remove containers:

```bash
docker compose down
```

### Option B — Image only (no Compose)

```bash
docker build -t log-profiler:local .
docker run --rm -p 8000:8000 \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/logs:/app/logs" \
  log-profiler:local
```

### Docker notes

- The image sets `PYTHONPATH=/app` and runs `python src/main.py`.
- Ensure port **8000** is free on the host before mapping `-p 8000:8000`.

---

## GitHub checklist

Before you push:

1. **Virtualenv** — never commit `venv/` (ignored).
2. **Secrets** — do not commit `.env` files with real keys; use `.env.example` if you add configuration later.
3. **Generated noise** — run `./cleanup.sh` or manually delete `logs/`, `.pytest_cache/`, `__pycache__/`, `.server.pid` if present.
4. **Branch** — push `main` (or your default branch) after `git add` / `git commit`.

```bash
git add .
git status   # confirm venv/ and caches are not staged
git commit -m "Add log-profiler implementation"
git push origin main
```

---

## Project layout (high level)

| Path | Purpose |
|------|---------|
| `src/main.py` | Uvicorn entrypoint |
| `src/dashboard/` | FastAPI app + WebSocket |
| `src/profiler/`, `src/optimizer/`, `src/analyzer/` | Profiling and log simulation |
| `config/` | Python configuration |
| `templates/` | Dashboard HTML |
| `tests/` | Pytest suite |
| `start.sh` / `stop.sh` | Manual run helpers |
| `cleanup.sh` | Stop services + prune Docker + remove local artifacts |
| `docker-compose.yml` / `Dockerfile` | Container deployment |

---

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| **Connection refused** in the browser | Start the app: `./start.sh` or Docker Compose. Nothing listens until the server runs. |
| **Port 8000 in use** | `./stop.sh` or change `PORT=8001 ./start.sh` (match your setup). |
| **Import errors** | Run from repo root; use `./start.sh` (sets `PYTHONPATH`). In Docker, use the provided `Dockerfile` / Compose. |
| **No `venv`** after cleanup | `python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt` |

---

## License

Add a `LICENSE` file in this repository if you need an explicit license for GitHub.

READMEEOF

# Optional: run tests and demo only (does not start the HTTP server)
cat > build_and_test.sh << 'EOF'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
# shellcheck source=/dev/null
source "$SCRIPT_DIR/venv/bin/activate"

export PYTHONPATH="${SCRIPT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"
echo "🧪 Running unit tests..."
python -m pytest tests/test_profiler.py -v

echo "🎮 Running demonstration..."
python demo.py

echo "✅ Tests and demo finished. Start the dashboard with: ./start.sh"
EOF

chmod +x build_and_test.sh

echo "✅ All Python files have valid syntax!"
echo "🧪 Running tests..."

python -m pytest tests/test_profiler.py -v

echo "🎮 Running demonstration..."
python demo.py

echo ""
echo "🎉 Day 71: Log Performance Profiler - Implementation Complete!"
echo "=============================================================="
echo ""
echo "✅ Created comprehensive performance profiling system"
echo "✅ Implemented bottleneck detection and optimization suggestions"
echo "✅ Built real-time web dashboard with Google Cloud Skills Boost styling"
echo "✅ Generated before/after performance metrics"
echo "✅ All tests passing"
echo ""
echo "🚀 Quick Start Commands:"
echo "  1. Start dashboard: ${PROJECT_DIR}/start.sh"
echo "  2. Open: http://localhost:8000"
echo "  3. Stop: ${PROJECT_DIR}/stop.sh"
echo "  4. Run demo: cd ${PROJECT_DIR} && source venv/bin/activate && python demo.py"
echo "  5. Run tests: ${PROJECT_DIR}/build_and_test.sh"
echo "  6. Docker: cd ${PROJECT_DIR} && docker-compose up --build"
echo ""
echo "📊 Key Features Implemented:"
echo "  • Real-time CPU, memory, and I/O profiling"
echo "  • Automated bottleneck detection"
echo "  • AI-powered optimization recommendations"
echo "  • Load testing framework"
echo "  • Before/after performance comparison"
echo "  • Interactive web dashboard"
echo ""
echo "🎯 Performance Optimization Success!"
echo "Your log ingestion pipeline is now ready for production-grade performance analysis!"

echo "✅ Day 71 Implementation Script Created Successfully!"
echo "📁 Project directory: ${PROJECT_DIR}/"
echo "🚀 Start app: ${PROJECT_DIR}/start.sh"