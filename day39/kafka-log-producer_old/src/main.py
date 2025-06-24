import asyncio
import signal
import sys
import time
from pathlib import Path
import structlog

# Add src to path
sys.path.append(str(Path(__file__).parent.parent))

from producer.kafka_producer import KafkaLogProducer
from utils.log_generator import LogGenerator
from monitoring.producer_metrics import ProducerMetrics

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

class ProducerApplication:
    """Main producer application"""
    
    def __init__(self):
        self.producer = None
        self.generator = LogGenerator()
        self.running = False
        
    def setup_signal_handlers(self):
        """Setup graceful shutdown signal handlers"""
        def signal_handler(signum, frame):
            logger.info(f"Received signal {signum}, shutting down gracefully")
            self.shutdown()
            
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
    def start(self):
        """Start the producer application"""
        try:
            logger.info("Starting Kafka Log Producer Application")
            
            # Initialize producer
            self.producer = KafkaLogProducer()
            self.running = True
            
            # Setup signal handlers
            self.setup_signal_handlers()
            
            logger.info("Producer application started successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to start application: {e}")
            return False
            
    def run_demo(self):
        """Run a demonstration of the producer"""
        if not self.start():
            return
            
        logger.info("Starting demo - generating sample logs")
        
        try:
            # Generate and send sample logs
            logs = self.generator.generate_batch(100, 30)
            
            logger.info(f"Sending {len(logs)} sample logs")
            
            batch_size = 10
            for i in range(0, len(logs), batch_size):
                batch = logs[i:i + batch_size]
                results = self.producer.send_logs_batch(batch)
                
                logger.info(
                    f"Batch {i//batch_size + 1}: "
                    f"sent={results['sent']}, failed={results['failed']}"
                )
                
                time.sleep(1)  # Throttle for demo
                
            # Generate an error burst to demonstrate error handling
            logger.info("Generating error burst for demonstration")
            error_logs = self.generator.generate_error_burst(20)
            error_results = self.producer.send_logs_batch(error_logs)
            
            logger.info(
                f"Error burst: sent={error_results['sent']}, "
                f"failed={error_results['failed']}"
            )
            
            # Flush all messages
            self.producer.flush()
            
            logger.info("Demo completed successfully")
            
        except Exception as e:
            logger.error(f"Demo failed: {e}")
        finally:
            self.shutdown()
            
    def run_performance_test(self, duration_seconds: int = 60, rate_per_second: int = 1000):
        """Run performance test"""
        if not self.start():
            return
            
        logger.info(f"Starting performance test: {rate_per_second} msgs/sec for {duration_seconds}s")
        
        try:
            start_time = time.time()
            total_sent = 0
            total_failed = 0
            
            for log in self.generator.generate_high_volume_stream(duration_seconds, rate_per_second):
                if self.producer.send_log(log):
                    total_sent += 1
                else:
                    total_failed += 1
                    
                # Poll for callbacks every 100 messages
                if (total_sent + total_failed) % 100 == 0:
                    self.producer.producer.poll(0)
                    
            # Final flush
            self.producer.flush()
            
            elapsed = time.time() - start_time
            actual_rate = total_sent / elapsed
            
            logger.info(
                f"Performance test completed: "
                f"sent={total_sent}, failed={total_failed}, "
                f"actual_rate={actual_rate:.1f} msgs/sec"
            )
            
        except Exception as e:
            logger.error(f"Performance test failed: {e}")
        finally:
            self.shutdown()
            
    def shutdown(self):
        """Gracefully shutdown the application"""
        self.running = False
        if self.producer:
            self.producer.close()
        logger.info("Application shutdown complete")

def main():
    """Main entry point"""
    app = ProducerApplication()
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "demo":
            app.run_demo()
        elif command == "performance":
            duration = int(sys.argv[2]) if len(sys.argv) > 2 else 60
            rate = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
            app.run_performance_test(duration, rate)
        else:
            print("Usage: python main.py [demo|performance [duration] [rate]]")
    else:
        # Default to demo
        app.run_demo()

if __name__ == "__main__":
    main()
