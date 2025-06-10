import asyncio
import random
import time
import json
from src.collectors.metric_collector import MetricsCollector, ApplicationMetricsCollector
from src.aggregators.metrics_aggregator import MetricsAggregator
from src.analyzers.performance_analyzer import PerformanceAnalyzer

async def demonstrate_performance_monitoring():
    """Demonstrate the performance monitoring system"""
    print("🚀 Performance Monitoring System Demonstration")
    print("=" * 60)
    
    # Configuration
    config = {
        'monitoring': {'collection_interval': 2},
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
    
    # Initialize components
    aggregator = MetricsAggregator(config)
    analyzer = PerformanceAnalyzer(config)
    metric_queue = asyncio.Queue()
    
    # Create collectors for simulated nodes
    collectors = {
        'node-1': MetricsCollector('node-1', config['monitoring']),
        'node-2': MetricsCollector('node-2', config['monitoring']),
        'node-3': MetricsCollector('node-3', config['monitoring'])
    }
    
    print("\n1. Starting metric collection from 3 nodes...")
    
    # Start collection tasks
    collection_tasks = []
    for collector in collectors.values():
        task = asyncio.create_task(collector.start_collection(metric_queue))
        collection_tasks.append(task)
    
    # Start aggregator
    aggregator_task = asyncio.create_task(aggregator.process_metrics(metric_queue))
    
    # Simulate workload on application collectors
    async def simulate_workload():
        """Simulate varying workload patterns"""
        while True:
            for node_id, collector in collectors.items():
                # Simulate different load patterns per node
                if node_id == 'node-1':
                    # Primary node - higher load
                    latency = random.uniform(20, 300)
                    for _ in range(random.randint(5, 15)):
                        collector.app_collector.record_write_latency(latency)
                elif node_id == 'node-2':
                    # Secondary node - moderate load
                    latency = random.uniform(10, 150)
                    for _ in range(random.randint(2, 8)):
                        collector.app_collector.record_write_latency(latency)
                else:
                    # Tertiary node - light load
                    latency = random.uniform(5, 100)
                    for _ in range(random.randint(1, 5)):
                        collector.app_collector.record_write_latency(latency)
            
            await asyncio.sleep(1)
    
    workload_task = asyncio.create_task(simulate_workload())
    
    print("2. Collecting metrics for 15 seconds...")
    await asyncio.sleep(15)
    
    print("\n3. Generating aggregated metrics...")
    cluster_metrics = await aggregator.aggregate_cluster_metrics(time_window=300)
    
    print(f"   - Active nodes: {len(cluster_metrics['nodes'])}")
    print(f"   - Metrics collected: {sum(len(metrics) for metrics in aggregator.metrics_buffer.values())}")
    
    # Display cluster totals
    cluster_totals = cluster_metrics.get('cluster_totals', {})
    if cluster_totals:
        print(f"   - Cluster avg CPU: {cluster_totals.get('avg_cpu_usage', 0):.1f}%")
        print(f"   - Cluster avg Memory: {cluster_totals.get('avg_memory_usage', 0):.1f}%")
        print(f"   - Total throughput: {cluster_totals.get('total_throughput', 0):.1f} ops/sec")
    
    print("\n4. Analyzing performance and generating alerts...")
    analysis = await analyzer.analyze_cluster_performance(cluster_metrics)
    
    print(f"   - Overall health: {analysis['overall_health'].upper()}")
    print(f"   - Active alerts: {len(analysis['alerts'])}")
    
    # Display alerts
    if analysis['alerts']:
        print("\n   Active Alerts:")
        for alert in analysis['alerts'][:5]:  # Show first 5 alerts
            print(f"     • {alert['level'].upper()}: {alert['message']} (Node: {alert['node_id']})")
    
    print("\n5. Generating comprehensive performance report...")
    report = await analyzer.generate_performance_report(cluster_metrics)
    
    # Display performance summary
    summary = report['performance_summary']
    print(f"   - Performance Score: {summary['performance_score']:.1f}/100")
    print(f"   - Active Nodes: {summary['active_nodes']}")
    
    # Display recommendations
    if report['recommendations']:
        print("\n   Top Recommendations:")
        for i, rec in enumerate(report['recommendations'][:3], 1):
            print(f"     {i}. {rec}")
    
    print("\n6. Simulating performance issues...")
    
    # Simulate high load on node-1
    for _ in range(50):
        collectors['node-1'].app_collector.record_write_latency(random.uniform(400, 800))
    
    await asyncio.sleep(3)
    
    # Re-analyze
    updated_metrics = await aggregator.aggregate_cluster_metrics(time_window=300)
    updated_analysis = await analyzer.analyze_cluster_performance(updated_metrics)
    
    print(f"   - Updated health status: {updated_analysis['overall_health'].upper()}")
    print(f"   - New alerts: {len(updated_analysis['alerts'])}")
    
    if updated_analysis['alerts']:
        print("\n   Critical Issues Detected:")
        critical_alerts = [a for a in updated_analysis['alerts'] if a['level'] == 'critical']
        for alert in critical_alerts[:3]:
            print(f"     🚨 {alert['message']} (Value: {alert['current_value']:.1f})")
    
    print("\n7. Saving performance report...")
    report_file = f"data/demo_performance_report_{int(time.time())}.json"
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2)
    print(f"   - Report saved to: {report_file}")
    
    # Cleanup
    print("\n8. Cleaning up...")
    for collector in collectors.values():
        collector.stop_collection()
    
    aggregator.stop()
    
    for task in collection_tasks + [aggregator_task, workload_task]:
        task.cancel()
    
    print("\n✅ Performance monitoring demonstration completed!")
    print("\nKey Capabilities Demonstrated:")
    print("• Real-time metric collection from multiple nodes")
    print("• Automatic aggregation and trend analysis")
    print("• Intelligent alerting based on configurable thresholds")
    print("• Performance scoring and health assessment")
    print("• Actionable recommendations for optimization")
    print("\n🎯 The system is now ready for production deployment!")

if __name__ == "__main__":
    asyncio.run(demonstrate_performance_monitoring())
