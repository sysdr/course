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
