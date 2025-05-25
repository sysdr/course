# src/optimized_server.py - High-performance server solution
#!/usr/bin/env python3
import asyncio
import ssl
import json
import gzip
import time
import uvloop  # High-performance event loop
from collections import deque
import aiofiles

class HighPerformanceLogServer:
    def __init__(self, host='0.0.0.0', port=8888, use_tls=True):
        self.host = host
        self.port = port
        self.use_tls = use_tls
        self.metrics = {
            'logs_received': 0,
            'bytes_received': 0,
            'start_time': time.time(),
            'connections': 0
        }
        self.log_queue = asyncio.Queue(maxsize=10000)
        self.batch_processor_running = False
        
    async def handle_client(self, reader, writer):
        self.metrics['connections'] += 1
        client_addr = writer.get_extra_info('peername')
        
        try:
            # Set TCP socket options for performance
            sock = writer.get_extra_info('socket')
            if sock:
                sock.setsockopt(socket.SOL_TCP, socket.TCP_NODELAY, 1)
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65536)
            
            while True:
                # Read with larger buffer
                length_data = await reader.readexactly(4)
                if not length_data:
                    break
                    
                message_length = int.from_bytes(length_data, byteorder='big')
                compressed_data = await reader.readexactly(message_length)
                
                # Queue for batch processing instead of processing inline
                try:
                    await self.log_queue.put_nowait((compressed_data, len(compressed_data)))
                except asyncio.QueueFull:
                    # Drop logs if queue is full (circuit breaker pattern)
                    print("Queue full, dropping logs")
                    continue
                    
        except Exception as e:
            pass
        finally:
            self.metrics['connections'] -= 1
            writer.close()
            await writer.wait_closed()
    
    async def batch_processor(self):
        """Process logs in batches for better performance"""
        batch = []
        batch_size = 500  # Process larger batches
        last_flush = time.time()
        
        while self.batch_processor_running:
            try:
                # Collect batch
                timeout = 0.1  # 100ms timeout
                end_time = time.time() + timeout
                
                while len(batch) < batch_size and time.time() < end_time:
                    try:
                        compressed_data, size = await asyncio.wait_for(
                            self.log_queue.get(), timeout=0.01
                        )
                        batch.append((compressed_data, size))
                    except asyncio.TimeoutError:
                        break
                
                # Process batch if we have logs or timeout
                if batch and (len(batch) >= batch_size or time.time() - last_flush > 0.5):
                    await self.process_log_batch(batch)
                    batch.clear()
                    last_flush = time.time()
                    
            except Exception as e:
                print(f"Batch processor error: {e}")
                await asyncio.sleep(0.1)
    
    async def process_log_batch(self, batch):
        """Process a batch of logs efficiently"""
        total_logs = 0
        total_bytes = 0
        
        for compressed_data, size in batch:
            try:
                json_data = gzip.decompress(compressed_data).decode('utf-8')
                logs = json.loads(json_data)
                total_logs += len(logs)
                total_bytes += size
                
                # In production: bulk insert to database
                # For demo: just count
                
            except Exception:
                continue
        
        # Update metrics atomically
        self.metrics['logs_received'] += total_logs
        self.metrics['bytes_received'] += total_bytes
    
    async def stats_reporter(self):
        last_logs = 0
        while True:
            await asyncio.sleep(5)
            current_logs = self.metrics['logs_received']
            elapsed = time.time() - self.metrics['start_time']
            
            logs_per_sec = (current_logs - last_logs) / 5
            total_rate = current_logs / elapsed if elapsed > 0 else 0
            
            print(f"[PERF] Current: {logs_per_sec:.0f} logs/sec, "
                  f"Average: {total_rate:.0f} logs/sec, "
                  f"Total: {current_logs:,}, "
                  f"Connections: {self.metrics['connections']}")
            
            last_logs = current_logs
    
    async def start_server(self):
        # Use uvloop for better performance
        if hasattr(asyncio, 'set_event_loop_policy'):
            try:
                asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
            except:
                pass  # Fall back to default event loop
        
        if self.use_tls:
            context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
            context.load_cert_chain('certs/server.crt', 'certs/server.key')
        else:
            context = None
        
        # Start batch processor
        self.batch_processor_running = True
        asyncio.create_task(self.batch_processor())
        asyncio.create_task(self.stats_reporter())
        
        server = await asyncio.start_server(
            self.handle_client,
            self.host,
            self.port,
            ssl=context,
            backlog=1000  # Accept more connections
        )
        
        print(f"High-Performance Server listening on {self.host}:{self.port}")
        
        async with server:
            await server.serve_forever()

# src/optimized_load_generator.py - Connection pooling solution
import asyncio
import time
import random
from datetime import datetime

class OptimizedLoadGenerator:
    def __init__(self, target_rps=5000, duration=60, connection_pool_size=20):
        self.target_rps = target_rps
        self.duration = duration
        self.pool_size = connection_pool_size
        self.connection_pool = []
        self.pool_lock = asyncio.Lock()
        self.logs_sent = 0
        self.errors = 0
        
    async def create_connection_pool(self):
        """Create a pool of persistent connections"""
        from log_shipper import LogShipper
        
        for i in range(self.pool_size):
            shipper = LogShipper(
                batch_size=100,  # Larger batches
                batch_interval=0.1,  # More frequent flushes
                use_tls=False  # Disable TLS for max performance
            )
            if await shipper.start():
                self.connection_pool.append(shipper)
            else:
                print(f"Failed to create connection {i}")
        
        print(f"Created connection pool with {len(self.connection_pool)} connections")
    
    async def get_connection(self):
        """Get a connection from the pool using round-robin"""
        async with self.pool_lock:
            if self.connection_pool:
                return self.connection_pool[self.logs_sent % len(self.connection_pool)]
        return None
    
    async def high_speed_worker(self, worker_id):
        """Optimized worker for maximum throughput"""
        start_time = time.time()
        local_count = 0
        
        # Pre-generate logs to reduce CPU overhead
        log_batch = []
        for _ in range(1000):
            log_batch.append({
                'timestamp': datetime.now().isoformat(),
                'level': random.choice(['INFO', 'WARN', 'ERROR']),
                'service': f'service-{random.randint(1, 10)}',
                'message': f'High-speed log message {random.randint(1000, 9999)}',
                'request_id': f'req-{random.randint(10000, 99999)}'
            })
        
        try:
            while time.time() - start_time < self.duration:
                connection = await self.get_connection()
                if connection:
                    # Send logs in rapid succession
                    for _ in range(10):  # Burst of 10 logs
                        log = log_batch[local_count % len(log_batch)]
                        await connection.ship_log(log)
                        self.logs_sent += 1
                        local_count += 1
                    
                    # Dynamic rate limiting based on target
                    sleep_time = (10 * self.pool_size) / self.target_rps
                    await asyncio.sleep(max(0.001, sleep_time))
                else:
                    self.errors += 1
                    await asyncio.sleep(0.01)
                    
        except Exception as e:
            print(f"Worker {worker_id} error: {e}")
            self.errors += 1
    
    async def run_optimized_test(self):
        print(f"Running OPTIMIZED load test: {self.target_rps} RPS target")
        
        await self.create_connection_pool()
        if not self.connection_pool:
            print("Failed to create connection pool")
            return
        
        start_time = time.time()
        
        # Create workers (fewer workers, higher throughput per worker)
        num_workers = min(self.pool_size, 10)
        tasks = []
        for i in range(num_workers):
            task = asyncio.create_task(self.high_speed_worker(i))
            tasks.append(task)
        
        # Monitor task
        monitor_task = asyncio.create_task(self.monitor_progress(start_time))
        
        # Wait for completion
        await asyncio.gather(*tasks)
        monitor_task.cancel()
        
        # Cleanup
        for shipper in self.connection_pool:
            await shipper.close()
        
        elapsed = time.time() - start_time
        actual_rps = self.logs_sent / elapsed
        success_rate = ((self.logs_sent - self.errors) / self.logs_sent * 100) if self.logs_sent > 0 else 0
        
        print(f"\n=== OPTIMIZED TEST RESULTS ===")
        print(f"Target RPS: {self.target_rps}")
        print(f"Actual RPS: {actual_rps:.2f}")
        print(f"Total Logs: {self.logs_sent:,}")
        print(f"Success Rate: {success_rate:.2f}%")
        print(f"Performance: {'✅ TARGET MET' if actual_rps >= self.target_rps * 0.9 else '❌ BELOW TARGET'}")
        
        return {
            'target_rps': self.target_rps,
            'actual_rps': actual_rps,
            'logs_sent': self.logs_sent,
            'success_rate': success_rate,
            'target_met': actual_rps >= self.target_rps * 0.9
        }
    
    async def monitor_progress(self, start_time):
        last_count = 0
        while True:
            await asyncio.sleep(5)
            elapsed = time.time() - start_time
            current_rps = (self.logs_sent - last_count) / 5
            
            print(f"[{elapsed:.0f}s] Current: {current_rps:.0f} RPS, "
                  f"Total: {self.logs_sent:,}, "
                  f"Errors: {self.errors}")
            
            last_count = self.logs_sent

# Performance test script
async def run_performance_test():
    import socket
    
    # Optimize socket settings
    socket.setdefaulttimeout(30)
    
    # Test scenarios
    scenarios = [
        {"name": "Baseline", "rps": 1000},
        {"name": "Target", "rps": 5000},
        {"name": "Stress", "rps": 10000}
    ]
    
    results = []
    for scenario in scenarios:
        print(f"\n{'='*50}")
        print(f"SCENARIO: {scenario['name']} ({scenario['rps']} RPS)")
        print('='*50)
        
        generator = OptimizedLoadGenerator(
            target_rps=scenario['rps'],
            duration=30,
            connection_pool_size=20
        )
        
        result = await generator.run_optimized_test()
        result['scenario'] = scenario['name']
        results.append(result)
        
        # Cool down
        await asyncio.sleep(3)
    
    # Summary
    print(f"\n{'='*50}")
    print("PERFORMANCE SUMMARY")
    print('='*50)
    for result in results:
        status = "✅ PASS" if result['target_met'] else "❌ FAIL"
        print(f"{result['scenario']:10} | {result['actual_rps']:8.0f} RPS | {result['success_rate']:6.1f}% | {status}")

if __name__ == "__main__":
    asyncio.run(run_performance_test())