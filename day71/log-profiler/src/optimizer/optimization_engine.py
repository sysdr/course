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
