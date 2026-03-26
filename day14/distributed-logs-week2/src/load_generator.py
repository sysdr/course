#!/usr/bin/env python3
import asyncio
import time
import json
import random
import sys
import os
from datetime import datetime

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from log_shipper import LogShipper
except ImportError:
    print("Error: Could not import LogShipper. Make sure log_shipper.py is in the same directory.")
    sys.exit(1)

class LoadGenerator:
    def __init__(
        self,
        target_rps=1000,
        duration=60,
        num_workers=10,
        use_tls=True,
        server_host="localhost",
        server_port=8888,
    ):
        self.target_rps = target_rps
        self.duration = duration
        self.num_workers = num_workers
        self.use_tls = use_tls
        self.server_host = server_host
        self.server_port = server_port
        self.logs_sent = 0
        self.errors = 0
        self.start_time = None
        self.running = True
        
        # Sample log templates
        self.log_templates = [
            {"level": "INFO", "service": "web-api", "message": "User {} logged in"},
            {"level": "ERROR", "service": "payment", "message": "Payment failed for order {}"},
            {"level": "WARN", "service": "database", "message": "Slow query detected: {}ms"},
            {"level": "INFO", "service": "cache", "message": "Cache miss for key {}"},
            {"level": "DEBUG", "service": "auth", "message": "Token validated for user {}"}
        ]
    
    def generate_log(self):
        template = random.choice(self.log_templates)
        log = template.copy()
        
        # Add dynamic values
        log['timestamp'] = datetime.now().isoformat()
        log['request_id'] = f"req-{random.randint(10000, 99999)}"
        log['message'] = log['message'].format(random.randint(1000, 9999))
        
        # Add some random fields
        if random.random() < 0.3:
            log['user_id'] = f"user-{random.randint(1, 1000)}"
        if random.random() < 0.2:
            log['response_time'] = random.randint(10, 500)
            
        return log
    
    async def worker(self, worker_id):
        # Create dedicated shipper for this worker
        shipper = LogShipper(
            server_host=self.server_host,
            server_port=self.server_port,
            batch_size=20,
            batch_interval=0.5,
            use_tls=self.use_tls,
        )
        
        if not await shipper.start():
            print(f"Worker {worker_id}: Failed to connect")
            self.errors += 1
            return
        
        print(f"Worker {worker_id}: Connected and ready")
        
        try:
            while self.running and (time.time() - self.start_time) < self.duration:
                log = self.generate_log()
                await shipper.ship_log(log)
                self.logs_sent += 1
                
                # Rate limiting - distribute load across workers
                sleep_time = self.num_workers / self.target_rps
                await asyncio.sleep(max(0.001, sleep_time))
                
        except Exception as e:
            print(f"Worker {worker_id} error: {e}")
            self.errors += 1
        finally:
            await shipper.close()
            print(f"Worker {worker_id}: Finished")
    
    async def run_load_test(self):
        print(f"Starting load test: {self.target_rps} RPS for {self.duration}s with {self.num_workers} workers")
        
        self.start_time = time.time()
        
        # Start workers
        tasks = []
        for i in range(self.num_workers):
            task = asyncio.create_task(self.worker(i))
            tasks.append(task)
        
        # Monitor progress
        monitor_task = asyncio.create_task(self.monitor_progress())
        
        # Wait for completion
        try:
            await asyncio.gather(*tasks)
        except Exception as e:
            print(f"Error in workers: {e}")
        finally:
            self.running = False
            monitor_task.cancel()
            try:
                await monitor_task
            except asyncio.CancelledError:
                pass
        
        # Final stats
        elapsed = time.time() - self.start_time
        actual_rps = self.logs_sent / elapsed if elapsed > 0 else 0
        if self.logs_sent > 0:
            success_rate = ((self.logs_sent - self.errors) / self.logs_sent) * 100
        else:
            success_rate = 0.0
        
        print(f"\n=== LOAD TEST RESULTS ===")
        print(f"Duration: {elapsed:.2f}s")
        print(f"Logs sent: {self.logs_sent}")
        print(f"Errors: {self.errors}")
        print(f"Target RPS: {self.target_rps}")
        print(f"Actual RPS: {actual_rps:.2f}")
        print(f"Success Rate: {success_rate:.2f}%")
        
        return {
            'duration': elapsed,
            'logs_sent': self.logs_sent,
            'errors': self.errors,
            'target_rps': self.target_rps,
            'actual_rps': actual_rps,
            'success_rate': success_rate
        }
    
    async def monitor_progress(self):
        last_count = 0
        while self.running:
            await asyncio.sleep(5)
            if not self.running:
                break
                
            elapsed = time.time() - self.start_time
            current_rps = (self.logs_sent - last_count) / 5
            total_rps = self.logs_sent / elapsed if elapsed > 0 else 0
            
            print(f"[{elapsed:.0f}s] Sent: {self.logs_sent}, "
                  f"Current: {current_rps:.1f} RPS, "
                  f"Average: {total_rps:.1f} RPS, "
                  f"Errors: {self.errors}")
            
            last_count = self.logs_sent

async def main():
    # Args: [rps] [duration] [workers] [--no-tls] (order after numeric args is flexible)
    args = [a for a in sys.argv[1:] if a != "--no-tls"]
    use_tls = "--no-tls" not in sys.argv[1:]
    target_rps = int(args[0]) if len(args) > 0 else 100
    duration = int(args[1]) if len(args) > 1 else 10
    workers = int(args[2]) if len(args) > 2 else 5

    generator = LoadGenerator(
        target_rps=target_rps, duration=duration, num_workers=workers, use_tls=use_tls
    )
    results = await generator.run_load_test()
    
    # Save results to file
    try:
        with open('benchmark_results.json', 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to benchmark_results.json")
    except Exception as e:
        print(f"Failed to save results: {e}")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Load test interrupted.")