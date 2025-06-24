import pytest
import time
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from analyzers.performance_analyzer import PerformanceAnalyzer, AlertLevel

@pytest.mark.asyncio
async def test_performance_analyzer():
    """Test performance analysis"""
    config = {
        'metrics': {
            'thresholds': {
                'cpu_warning': 70,
                'cpu_critical': 90,
                'memory_warning': 80,
                'memory_critical': 95,
                'latency_warning': 100,
                'latency_critical': 500
            }
        }
    }
    
    analyzer = PerformanceAnalyzer(config)
    
    # Test with healthy metrics
    healthy_metrics = {
        'nodes': {
            'node-1': {
                'cpu_usage_total': {'avg': 50.0},
                'memory_usage': {'avg': 60.0},
                'write_latency_avg': {'avg': 50.0}
            }
        },
        'cluster_totals': {
            'avg_cpu_usage': 50.0,
            'total_throughput': 100.0
        }
    }
    
    analysis = await analyzer.analyze_cluster_performance(healthy_metrics)
    assert analysis['overall_health'] == 'healthy'
    assert len(analysis['alerts']) == 0

@pytest.mark.asyncio
async def test_performance_alerts():
    """Test alert generation"""
    config = {
        'metrics': {
            'thresholds': {
                'cpu_warning': 70,
                'cpu_critical': 90,
                'memory_warning': 80,
                'memory_critical': 95
            }
        }
    }
    
    analyzer = PerformanceAnalyzer(config)
    
    # Test with critical metrics
    critical_metrics = {
        'nodes': {
            'node-1': {
                'cpu_usage_total': {'avg': 95.0},
                'memory_usage': {'avg': 98.0}
            }
        },
        'cluster_totals': {}
    }
    
    analysis = await analyzer.analyze_cluster_performance(critical_metrics)
    assert analysis['overall_health'] == 'critical'
    assert len(analysis['alerts']) >= 2
    
    # Check alert levels
    critical_alerts = [a for a in analysis['alerts'] if a['level'] == 'critical']
    assert len(critical_alerts) >= 2

@pytest.mark.asyncio
async def test_performance_report():
    """Test performance report generation"""
    config = {'metrics': {'thresholds': {}}}
    analyzer = PerformanceAnalyzer(config)
    
    metrics = {
        'nodes': {
            'node-1': {
                'cpu_usage_total': {'avg': 60.0},
                'memory_usage': {'avg': 70.0},
                'operations_per_second': {'avg': 50.0}
            }
        },
        'cluster_totals': {
            'avg_cpu_usage': 60.0,
            'total_throughput': 50.0
        }
    }
    
    report = await analyzer.generate_performance_report(metrics)
    
    assert 'report_timestamp' in report
    assert 'cluster_health' in report
    assert 'performance_summary' in report
    assert 'recommendations' in report
    assert 'trends' in report
    
    # Check performance summary
    summary = report['performance_summary']
    assert 'performance_score' in summary
    assert 0 <= summary['performance_score'] <= 100

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
