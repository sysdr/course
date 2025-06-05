import json
import logging
import queue
import threading
import time
from datetime import datetime
from typing import Dict, Any, List, Callable, Optional
from concurrent.futures import ThreadPoolExecutor
import colorama
from colorama import Fore, Style

from schema_validator import SchemaValidator

# Set up logging for our processor
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class JSONLogProcessor:
    """
    The central hub for processing JSON logs in our distributed system.
    
    This class is like a smart postal sorting facility that:
    1. Receives packages (JSON logs) from various sources
    2. Validates each package meets shipping requirements (schema validation)
    3. Adds tracking labels (enrichment)
    4. Routes packages to correct destinations (output handlers)
    5. Tracks performance metrics for optimization
    """
    
    def __init__(self, max_workers: int = 4, queue_size: int = 1000):
        """
        Initialize the JSON log processor.
        
        Args:
            max_workers: Number of worker threads for parallel processing
            queue_size: Maximum number of logs that can be queued for processing
        """
        # Core components
        self.validator = SchemaValidator()
        self.processing_queue = queue.Queue(maxsize=queue_size)
        self.executor = ThreadPoolExecutor(max_workers=max_workers)
        
        # Output handlers - functions that process valid logs
        self.output_handlers: List[Callable[[Dict[Any, Any]], None]] = []
        self.error_handlers: List[Callable[[Dict[Any, Any], str], None]] = []
        
        # Processing statistics for monitoring system health
        self.stats = {
            'logs_received': 0,
            'logs_processed': 0,
            'logs_validated': 0,
            'logs_rejected': 0,
            'processing_errors': 0,
            'start_time': datetime.utcnow(),
            'last_activity': datetime.utcnow()
        }
        
        # Control flags for graceful shutdown
        self.is_running = False
        self.processing_thread = None
        
        print(f"{Fore.GREEN}JSON Log Processor initialized with {max_workers} workers{Style.RESET_ALL}")
    
    def add_output_handler(self, handler: Callable[[Dict[Any, Any]], None]) -> None:
        """
        Register a function to handle successfully processed logs.
        
        Think of handlers as different delivery services - one might save to
        a database, another might send to a metrics system, etc.
        """
        self.output_handlers.append(handler)
        print(f"{Fore.BLUE}Added output handler: {handler.__name__}{Style.RESET_ALL}")
    
    def add_error_handler(self, handler: Callable[[Dict[Any, Any], str], None]) -> None:
        """
        Register a function to handle logs that failed validation.
        
        Error handlers are like quality control departments that deal with
        defective products - they might log errors, alert administrators, etc.
        """
        self.error_handlers.append(handler)
        print(f"{Fore.YELLOW}Added error handler: {handler.__name__}{Style.RESET_ALL}")
    
    def start(self) -> None:
        """
        Start the log processing engine.
        
        This method fires up our processing pipeline, like starting a factory
        production line. Once started, the processor continuously pulls logs
        from the queue and processes them in parallel.
        """
        if self.is_running:
            print(f"{Fore.YELLOW}Processor is already running{Style.RESET_ALL}")
            return
        
        self.is_running = True
        self.processing_thread = threading.Thread(target=self._processing_loop, daemon=True)
        self.processing_thread.start()
        
        print(f"{Fore.GREEN}✓ JSON Log Processor started successfully{Style.RESET_ALL}")
    
    def stop(self) -> None:
        """
        Gracefully shutdown the log processor.
        
        This ensures all queued logs are processed before stopping,
        similar to how a factory completes current orders before closing.
        """
        print(f"{Fore.YELLOW}Shutting down JSON Log Processor...{Style.RESET_ALL}")
        
        self.is_running = False
        
        # Wait for the processing thread to finish
        if self.processing_thread and self.processing_thread.is_alive():
            self.processing_thread.join(timeout=5.0)
        
        # Shutdown the thread pool executor
        self.executor.shutdown(wait=True)
        
        print(f"{Fore.GREEN}✓ JSON Log Processor stopped cleanly{Style.RESET_ALL}")
    
    def submit_log(self, raw_log_data: str, schema_name: str = "log_schema") -> bool:
        """
        Submit a raw log string for processing.
        
        This is the main entry point where logs enter our system.
        Think of it as the receiving dock where trucks drop off packages.
        
        Args:
            raw_log_data: Raw JSON string to process
            schema_name: Schema to validate against
            
        Returns:
            True if log was queued successfully, False if queue is full
        """
        self.stats['logs_received'] += 1
        self.stats['last_activity'] = datetime.utcnow()
        
        try:
            # Try to parse the JSON first - this is our first quality check
            log_dict = json.loads(raw_log_data)
            
            # Create a processing task that includes the parsed data and schema name
            task = {
                'log_data': log_dict,
                'schema_name': schema_name,
                'received_at': datetime.utcnow().isoformat()
            }
            
            # Try to add the task to our processing queue
            self.processing_queue.put(task, block=False)
            return True
            
        except json.JSONDecodeError as e:
            # The raw data isn't valid JSON - handle this error immediately
            error_msg = f"Invalid JSON format: {str(e)}"
            self._handle_invalid_log(raw_log_data, error_msg)
            return False
            
        except queue.Full:
            # Our processing queue is at capacity - this indicates backpressure
            print(f"{Fore.RED}Processing queue is full - dropping log{Style.RESET_ALL}")
            self.stats['processing_errors'] += 1
            return False
    
    def _processing_loop(self) -> None:
        """
        The main processing loop that runs in a separate thread.
        
        This is like the assembly line supervisor who continuously pulls
        work from the queue and assigns it to available workers.
        """
        print(f"{Fore.BLUE}Processing loop started{Style.RESET_ALL}")
        
        while self.is_running:
            try:
                # Wait for a task with a timeout so we can check if we should stop
                task = self.processing_queue.get(timeout=1.0)
                
                # Submit the task to our thread pool for parallel processing
                future = self.executor.submit(self._process_single_log, task)
                
                # We don't wait for the result here to maintain high throughput
                # The individual processing method handles success/failure
                
            except queue.Empty:
                # No tasks available - this is normal, just continue the loop
                continue
            except Exception as e:
                # Unexpected error in the processing loop
                logger.error(f"Error in processing loop: {e}")
                self.stats['processing_errors'] += 1
    
    def _process_single_log(self, task: Dict[str, Any]) -> None:
        """
        Process a single log entry through the complete pipeline.
        
        This method represents the complete journey of a log through our system:
        validation → enrichment → output routing
        
        Think of this as following a single package through the entire
        postal system from arrival to final delivery.
        """
        try:
            log_data = task['log_data']
            schema_name = task['schema_name']
            
            # Step 1: Validate the log against the schema
            is_valid, error_message = self.validator.validate_log(log_data, schema_name)
            
            if is_valid:
                # Step 2: Enrich the valid log with additional metadata
                enriched_log = self.validator.enrich_log(log_data)
                
                # Step 3: Send the processed log to all registered output handlers
                for handler in self.output_handlers:
                    try:
                        handler(enriched_log)
                    except Exception as e:
                        logger.error(f"Error in output handler {handler.__name__}: {e}")
                
                self.stats['logs_validated'] += 1
                
            else:
                # Handle invalid logs through error handlers
                for handler in self.error_handlers:
                    try:
                        handler(log_data, error_message)
                    except Exception as e:
                        logger.error(f"Error in error handler {handler.__name__}: {e}")
                
                self.stats['logs_rejected'] += 1
            
            self.stats['logs_processed'] += 1
            
        except Exception as e:
            # Catch-all for unexpected errors during processing
            logger.error(f"Unexpected error processing log: {e}")
            self.stats['processing_errors'] += 1
    
    def _handle_invalid_log(self, raw_data: Any, error_message: str) -> None:
        """Handle logs that couldn't even be parsed as JSON."""
        for handler in self.error_handlers:
            try:
                # Pass the raw data and error to error handlers
                handler({'raw_data': str(raw_data)}, error_message)
            except Exception as e:
                logger.error(f"Error in error handler {handler.__name__}: {e}")
        
        self.stats['logs_rejected'] += 1
    
    def get_stats(self) -> Dict[str, Any]:
        """
        Get comprehensive statistics about processor performance.
        
        This is like looking at the dashboard of a factory to see
        production rates, quality metrics, and system health.
        """
        current_time = datetime.utcnow()
        uptime_seconds = (current_time - self.stats['start_time']).total_seconds()
        
        # Calculate processing rates
        logs_per_second = self.stats['logs_processed'] / max(uptime_seconds, 1)
        
        # Combine our stats with validator stats
        validator_stats = self.validator.get_validation_stats()
        
        return {
            'processor_stats': {
                **self.stats,
                'uptime_seconds': round(uptime_seconds, 2),
                'logs_per_second': round(logs_per_second, 2),
                'queue_size': self.processing_queue.qsize(),
                'is_running': self.is_running
            },
            'validation_stats': validator_stats
        }