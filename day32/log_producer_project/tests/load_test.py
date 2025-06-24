import asyncio
import aiohttp
import json
import time
import statistics
from typing import List

class LoadTester:
    def __init__(self, base_url: str = "http://localhost:8080"):
        self.base_url = base_url
        self.response_times = []
        self.errors = 0
        
    async def send_log(self, session: aiohttp.ClientSession, log_data: dict):
        """Send a single log and measure response time"""
        start_time = time.time()
        try:
            async with session.post(f"{self.base_url}/logs", json=log_data) as response:
                duration = time.time() - start_time
                self.response_times.append(duration)
                
                if response.status != 200:
                    self.errors += 1
                    
        except Exception as e:
            self.errors += 1
            print(f"Error sending log: {e}")
    
    async def run_load_test(self, total_logs: int = 1000, concurrent_requests: int = 50):
        """Run load test with specified parameters"""
        print(f"Starting load test: {total_logs} logs, {concurrent_requests} concurrent requests")
        
        start_time = time.time()
        
        async with aiohttp.ClientSession() as session:
            # Create semaphore to limit concurrency
            semaphore = asyncio.Semaphore(concurrent_requests)
            
            async def bounded_send_log(i):
                async with semaphore:
                    log_data = {
                        'level': 'INFO',
                        'message': f'Load test message {i}',
                        'source': 'load_tester',
                        'request_id': i,
                        'timestamp': time.time()
                    }
                    await self.send_log(session, log_data)
            
            # Send all logs concurrently
            tasks = [bounded_send_log(i) for i in range(total_logs)]
            await asyncio.gather(*tasks)
        
        total_duration = time.time() - start_time
        
        # Calculate statistics
        avg_response_time = statistics.mean(self.response_times) if self.response_times else 0
        p95_response_time = statistics.quantiles(self.response_times, n=20)[18] if len(self.response_times) > 20 else 0
        throughput = total_logs / total_duration
        error_rate = self.errors / total_logs
        
        print(f"\n=== Load Test Results ===")
        print(f"Total logs sent: {total_logs}")
        print(f"Duration: {total_duration:.2f} seconds")
        print(f"Throughput: {throughput:.2f} logs/second")
        print(f"Average response time: {avg_response_time*1000:.2f} ms")
        print(f"95th percentile response time: {p95_response_time*1000:.2f} ms")
        print(f"Error rate: {error_rate*100:.2f}%")
        print(f"Errors: {self.errors}")
        
        return {
            'throughput': throughput,
            'avg_response_time': avg_response_time,
            'p95_response_time': p95_response_time,
            'error_rate': error_rate,
            'total_errors': self.errors
        }

async def main():
    tester = LoadTester()
    
    # Wait for service to be ready
    print("Waiting for service to be ready...")
    await asyncio.sleep(2)
    
    # Run load test
    results = await tester.run_load_test(total_logs=1000, concurrent_requests=50)
    
    # Verify requirements
    print(f"\n=== Requirement Verification ===")
    print(f"✓ Throughput > 1000 logs/sec: {results['throughput'] > 1000}")
    print(f"✓ Error rate < 1%: {results['error_rate'] < 0.01}")
    print(f"✓ P95 latency < 100ms: {results['p95_response_time'] < 0.1}")

if __name__ == "__main__":
    asyncio.run(main())
