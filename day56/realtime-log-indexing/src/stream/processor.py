import asyncio
import json
import time
from datetime import datetime
from typing import AsyncGenerator, Dict, Any
import redis.asyncio as redis
import structlog

from src.models import LogEntry
from config.indexing_config import config

logger = structlog.get_logger()

class StreamProcessor:
    """Processes incoming log streams and feeds them to indexing"""
    
    def __init__(self):
        self.redis_client = None
        self.processing_stats = {
            'logs_processed': 0,
            'processing_errors': 0,
            'total_processing_time_ms': 0
        }
        
    async def connect(self):
        """Connect to Redis stream"""
        self.redis_client = redis.from_url(config.redis_url)
        await self.redis_client.ping()
        logger.info("stream_processor_connected", redis_url=config.redis_url)
        
    async def disconnect(self):
        """Disconnect from Redis"""
        if self.redis_client:
            await self.redis_client.close()
    
    async def consume_log_stream(self) -> AsyncGenerator[LogEntry, None]:
        """Consume logs from Redis stream"""
        consumer_group = "indexing_group"
        consumer_name = "indexer_1"
        
        try:
            # Create consumer group if it doesn't exist
            try:
                await self.redis_client.xgroup_create(
                    config.log_stream_key, 
                    consumer_group, 
                    id="0", 
                    mkstream=True
                )
            except redis.RedisError:
                pass  # Group already exists
            
            logger.info("consuming_log_stream", 
                       stream=config.log_stream_key,
                       group=consumer_group)
            
            while True:
                try:
                    # Read from stream
                    messages = await self.redis_client.xreadgroup(
                        consumer_group,
                        consumer_name,
                        {config.log_stream_key: '>'},
                        count=config.batch_size,
                        block=config.batch_timeout_ms
                    )
                    
                    for stream, msgs in messages:
                        for msg_id, fields in msgs:
                            start_time = time.time()
                            
                            try:
                                # Parse log entry
                                log_data = json.loads(fields[b'data'].decode('utf-8'))
                                log_entry = self._parse_log_entry(log_data)
                                
                                # Acknowledge message
                                await self.redis_client.xack(
                                    config.log_stream_key,
                                    consumer_group,
                                    msg_id
                                )
                                
                                # Update stats
                                processing_time = (time.time() - start_time) * 1000
                                self.processing_stats['logs_processed'] += 1
                                self.processing_stats['total_processing_time_ms'] += processing_time
                                
                                yield log_entry
                                
                            except Exception as e:
                                self.processing_stats['processing_errors'] += 1
                                logger.error("log_processing_error", 
                                           msg_id=msg_id.decode(),
                                           error=str(e))
                
                except Exception as e:
                    logger.error("stream_consumption_error", error=str(e))
                    await asyncio.sleep(1)
                    
        except Exception as e:
            logger.error("stream_processor_error", error=str(e))
            raise
    
    def _parse_log_entry(self, log_data: Dict[str, Any]) -> LogEntry:
        """Parse raw log data into LogEntry"""
        # Handle different timestamp formats
        timestamp_str = log_data.get('timestamp', datetime.now().isoformat())
        if isinstance(timestamp_str, str):
            try:
                timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
            except ValueError:
                timestamp = datetime.now()
        else:
            timestamp = datetime.now()
        
        return LogEntry(
            timestamp=timestamp,
            level=log_data.get('level', 'INFO'),
            service=log_data.get('service', 'unknown'),
            message=log_data.get('message', ''),
            metadata=log_data.get('metadata', {})
        )
    
    async def generate_sample_logs(self, count: int = 100) -> None:
        """Generate sample logs for testing"""
        for i in range(count):
            # Ensure searches like "user" return a mix of service+level combinations.
            # Previously, only some messages contained the word "user", which meant the
            # dashboard query "user" returned only 2 specific service/level types.
            sample_services = ['web-api', 'auth-service', 'payment-processor', 'user-service']
            sample_levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']

            service = sample_services[i % len(sample_services)]
            level = sample_levels[i % len(sample_levels)]

            messages_by_service_and_level = {
                'web-api': {
                    'INFO': [
                        'User authentication successful',
                        'User login successful'
                    ],
                    'WARN': [
                        'User authentication rate limit exceeded',
                        'User session nearing expiration'
                    ],
                    'ERROR': [
                        'User authentication failed',
                        'User permission denied'
                    ],
                    'DEBUG': [
                        'User auth debug trace',
                        'User request debug information'
                    ],
                },
                'auth-service': {
                    'INFO': [
                        'User token issued successfully',
                        'User session created'
                    ],
                    'WARN': [
                        'User login retry recommended',
                        'User auth subsystem warned'
                    ],
                    'ERROR': [
                        'User login verification failed',
                        'User auth flow crashed'
                    ],
                    'DEBUG': [
                        'User auth debug details',
                        'User auth internal debug trace'
                    ],
                },
                'payment-processor': {
                    'INFO': [
                        'User payment processing completed',
                        'User payment settlement successful'
                    ],
                    'WARN': [
                        'User payment processing delayed',
                        'User payment webhook warning'
                    ],
                    'ERROR': [
                        'User payment processing failed',
                        'User payment failed due to missing profile'
                    ],
                    'DEBUG': [
                        'User payment processor debug trace',
                        'User payment processing debug information'
                    ],
                },
                'user-service': {
                    'INFO': [
                        'User profile fetch completed',
                        'User profile updated successfully'
                    ],
                    'WARN': [
                        'User profile cache miss warning',
                        'User profile update delayed'
                    ],
                    'ERROR': [
                        'User database connection timeout',
                        'User profile fetch failed'
                    ],
                    'DEBUG': [
                        'User service debug trace',
                        'User service internal debug information'
                    ],
                },
            }

            level_messages = messages_by_service_and_level[service][level]
            # Deterministic selection so sample data is stable between runs.
            message_core = level_messages[i % len(level_messages)]

            log_data = {
                'timestamp': datetime.now().isoformat(),
                'level': level,
                'service': service,
                'message': f"{message_core} (log {i+1})",
                'metadata': {
                    'user_id': f'user_{(i % 1000) + 1}',
                    'request_id': f'req_{i+1:06d}',
                    'response_time_ms': (i % 500) + 10
                }
            }
            
            await self.redis_client.xadd(
                config.log_stream_key,
                {'data': json.dumps(log_data)}
            )
            
            if i % 10 == 0:
                await asyncio.sleep(0.01)  # Small delay to simulate realistic timing
        
        logger.info("sample_logs_generated", count=count)
    
    def get_stats(self) -> Dict:
        """Get processing statistics"""
        avg_processing_time = (self.processing_stats['total_processing_time_ms'] / 
                              max(1, self.processing_stats['logs_processed']))
        
        return {
            'logs_processed': self.processing_stats['logs_processed'],
            'processing_errors': self.processing_stats['processing_errors'],
            'avg_processing_time_ms': avg_processing_time,
            'error_rate': self.processing_stats['processing_errors'] / 
                         max(1, self.processing_stats['logs_processed'])
        }
