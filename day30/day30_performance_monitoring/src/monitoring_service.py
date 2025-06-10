import asyncio
import yaml
import logging
import signal
import sys
from pathlib import Path

from collectors.metric_collector import MetricsCollector
from aggregators.metrics_aggregator import MetricsAggregator
from analyzers.performance_analyzer import PerformanceAnalyzer
from dashboard.web_dashboard import PerformanceDashboard

class MonitoringService:
    """Main monitoring service that orchestrates all components"""
    
    def __init__(self, config_path: str):
        self.config = self.load_config(config_path)
        self.metric_queue = asyncio.Queue(maxsize=10000)
        self.collectors = {}
        self.aggregator = MetricsAggregator(self.config)
        self.analyzer = PerformanceAnalyzer(self.config)
        self.dashboard = PerformanceDashboard(self.aggregator, self.analyzer, self.config)
        self.running = False
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    def load_config(self, config_path: str) -> dict:
        """Load configuration from YAML file"""
        with open(config_path, 'r') as file:
            return yaml.safe_load(file)
    
    async def initialize_collectors(self):
        """Initialize metric collectors for each node"""
        nodes = self.config.get('cluster', {}).get('nodes', [])
        
        for node in nodes:
            node_id = node['id']
            collector = MetricsCollector(node_id, self.config.get('monitoring', {}))
            self.collectors[node_id] = collector
            
            # Start collection task
            asyncio.create_task(collector.start_collection(self.metric_queue))
            self.logger.info(f"Started collector for node {node_id}")
    
    async def start(self):
        """Start the monitoring service"""
        self.running = True
        self.logger.info("Starting performance monitoring service...")
        
        try:
            # Initialize collectors
            await self.initialize_collectors()
            
            # Start aggregator
            asyncio.create_task(self.aggregator.process_metrics(self.metric_queue))
            self.logger.info("Started metrics aggregator")
            
            # Start dashboard
            await self.dashboard.start_server()
            self.logger.info("Started web dashboard")
            
            # Start periodic reporting
            asyncio.create_task(self.periodic_reporting())
            
            self.logger.info("Monitoring service started successfully")
            
            # Keep running
            while self.running:
                await asyncio.sleep(1)
                
        except Exception as e:
            self.logger.error(f"Error starting monitoring service: {e}")
            await self.stop()
    
    async def periodic_reporting(self):
        """Generate periodic performance reports"""
        while self.running:
            try:
                # Generate report every 5 minutes
                await asyncio.sleep(300)
                
                metrics = await self.aggregator.aggregate_cluster_metrics()
                report = await self.analyzer.generate_performance_report(metrics)
                
                # Log summary
                summary = report.get('performance_summary', {})
                self.logger.info(
                    f"Performance Report - Score: {summary.get('performance_score', 0):.1f}, "
                    f"CPU: {summary.get('cluster_cpu_avg', 0):.1f}%, "
                    f"Throughput: {summary.get('total_throughput', 0):.1f} ops/sec"
                )
                
                # Save report to file
                report_file = Path(f"data/performance_report_{int(report['report_timestamp'])}.json")
                report_file.parent.mkdir(exist_ok=True)
                
                import json
                with open(report_file, 'w') as f:
                    json.dump(report, f, indent=2)
                
            except Exception as e:
                self.logger.error(f"Error in periodic reporting: {e}")
    
    async def stop(self):
        """Stop the monitoring service"""
        self.logger.info("Stopping monitoring service...")
        self.running = False
        
        # Stop collectors
        for collector in self.collectors.values():
            collector.stop_collection()
        
        # Stop aggregator
        self.aggregator.stop()
        
        self.logger.info("Monitoring service stopped")
    
    def setup_signal_handlers(self):
        """Setup signal handlers for graceful shutdown"""
        def signal_handler(signum, frame):
            self.logger.info(f"Received signal {signum}, shutting down...")
            asyncio.create_task(self.stop())
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

async def main():
    """Main entry point"""
    service = MonitoringService('config/monitoring_config.yaml')
    service.setup_signal_handlers()
    await service.start()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nMonitoring service stopped by user")
