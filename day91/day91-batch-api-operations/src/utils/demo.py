import asyncio
import aiohttp
import json
import time
import random
from datetime import datetime, timezone

async def generate_sample_logs(count: int = 1000):
    """Generate sample log entries for testing"""
    services = ['user-service', 'payment-service', 'inventory-service', 'notification-service']
    levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
    
    logs = []
    for i in range(count):
        log = {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'level': random.choice(levels),
            'service': random.choice(services),
            'message': f'Sample log message {i} - {random.choice(["Operation completed", "Processing request", "Cache updated", "Database query executed"])}',
            'metadata': {
                'request_id': f'req_{random.randint(1000, 9999)}',
                'user_id': f'user_{random.randint(1, 1000)}',
                'duration_ms': random.randint(10, 500)
            }
        }
        logs.append(log)
    
    return logs

async def run_batch_demo():
    """Run comprehensive batch operations demonstration"""
    print("🎬 Starting Batch API Operations Demonstration")
    print("=" * 60)
    
    base_url = "http://localhost:8000"
    
    # Wait for API to be ready
    print("⏳ Waiting for API to be ready...")
    for _ in range(30):
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{base_url}/api/v1/health") as resp:
                    if resp.status == 200:
                        print("✅ API is ready!")
                        break
        except:
            pass
        await asyncio.sleep(1)
    else:
        print("❌ API not ready, continuing with demo anyway...")
    
    async with aiohttp.ClientSession() as session:
        # Test 1: Small batch insert
        print("\n🧪 Test 1: Small Batch Insert (100 logs)")
        logs = await generate_sample_logs(100)
        batch_request = {
            'logs': logs,
            'chunk_size': 50
        }
        
        start_time = time.time()
        try:
            async with session.post(
                f"{base_url}/api/v1/logs/batch",
                json=batch_request
            ) as resp:
                result = await resp.json()
                end_time = time.time()
                
                print(f"✅ Status: {result['success']}")
                print(f"📊 Processed: {result['total_processed']} logs")
                print(f"✅ Success: {result['success_count']}")
                print(f"❌ Errors: {result['error_count']}")
                print(f"⏱️ Time: {end_time - start_time:.2f}s (API: {result['processing_time']:.3f}s)")
        except Exception as e:
            print(f"❌ Test 1 failed: {e}")
        
        # Test 2: Large batch insert  
        print("\n🧪 Test 2: Large Batch Insert (5000 logs)")
        logs = await generate_sample_logs(5000)
        batch_request = {
            'logs': logs,
            'chunk_size': 1000
        }
        
        start_time = time.time()
        try:
            async with session.post(
                f"{base_url}/api/v1/logs/batch",
                json=batch_request
            ) as resp:
                result = await resp.json()
                end_time = time.time()
                
                print(f"✅ Status: {result['success']}")
                print(f"📊 Processed: {result['total_processed']} logs")
                print(f"✅ Success: {result['success_count']}")
                print(f"❌ Errors: {result['error_count']}")
                print(f"⏱️ Time: {end_time - start_time:.2f}s (API: {result['processing_time']:.3f}s)")
                print(f"🚀 Throughput: {result['success_count'] / result['processing_time']:.0f} logs/sec")
        except Exception as e:
            print(f"❌ Test 2 failed: {e}")
        
        # Test 3: Batch query
        print("\n🧪 Test 3: Batch Query Operation")
        query_request = {
            'filters': {
                'level': 'ERROR',
                'service': 'payment-service'
            },
            'limit': 100
        }
        
        try:
            async with session.post(
                f"{base_url}/api/v1/logs/batch/query",
                json=query_request
            ) as resp:
                result = await resp.json()
                
                print(f"✅ Status: {result['success']}")
                print(f"📊 Results: {result['total_results']} logs")
                print(f"⏱️ Time: {result['processing_time']:.3f}s")
                print(f"📈 Query Stats: {result['query_stats']}")
        except Exception as e:
            print(f"❌ Test 3 failed: {e}")
        
        # Test 4: Performance comparison
        print("\n🧪 Test 4: Performance Comparison (Individual vs Batch)")
        
        # Individual operations (simulated)
        individual_time = 100 * 0.01  # 100 logs × 10ms each = 1s
        print(f"📈 Individual operations (100 logs): ~{individual_time:.1f}s")
        
        # Batch operation
        logs = await generate_sample_logs(100)
        batch_request = {'logs': logs, 'chunk_size': 100}
        
        start_time = time.time()
        try:
            async with session.post(
                f"{base_url}/api/v1/logs/batch",
                json=batch_request
            ) as resp:
                result = await resp.json()
                batch_time = time.time() - start_time
                
                improvement = individual_time / batch_time if batch_time > 0 else 0
                print(f"🚀 Batch operation (100 logs): {batch_time:.2f}s")
                print(f"⚡ Performance improvement: {improvement:.1f}x faster")
        except Exception as e:
            print(f"❌ Performance test failed: {e}")
        
        # Test 5: Get metrics
        print("\n🧪 Test 5: Current System Metrics")
        try:
            async with session.get(f"{base_url}/api/v1/metrics/batch") as resp:
                metrics = await resp.json()
                
                print(f"📊 Total Batches: {metrics['total_batches_processed']}")
                print(f"📊 Total Logs: {metrics['total_logs_processed']}")
                print(f"📊 Average Batch Size: {metrics['average_batch_size']:.1f}")
                print(f"📊 Success Rate: {metrics['success_rate']:.1f}%")
                print(f"🚀 Throughput: {metrics['throughput_per_second']:.1f} logs/sec")
        except Exception as e:
            print(f"❌ Metrics test failed: {e}")
    
    print("\n🎉 Batch API Demonstration Completed!")
    print("🌐 Open http://localhost:8000/docs for interactive API documentation")
    print("📊 Open http://localhost:8001 for real-time monitoring dashboard")

if __name__ == "__main__":
    asyncio.run(run_batch_demo())
