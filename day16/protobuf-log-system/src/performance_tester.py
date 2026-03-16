import time
import json
import statistics
from typing import List, Dict
from log_processor import ProtobufLogProcessor

class PerformanceTester:
    """Compare JSON vs Protocol Buffers performance with enhanced metrics for v29.3"""
    
    def __init__(self):
        self.processor = ProtobufLogProcessor()
        if not self.processor.validate_protobuf_compatibility():
            raise RuntimeError("Protobuf v29.3 compatibility check failed")
        print(f"🔬 Performance tester initialized with enhanced v29.3 capabilities")
    
    def generate_sample_logs(self, count: int) -> List[Dict]:
        """Generate sample log entries for testing"""
        services = ['user-service', 'payment-service', 'auth-service', 'notification-service', 'analytics-service']
        levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
        
        message_templates = [
            "Processing user authentication request with JWT validation",
            "Payment transaction completed successfully with fraud detection check",
            "Database query executed in {}ms with connection pool optimization",
            "Cache miss occurred, falling back to primary data source",
            "Rate limiting applied to user {} from IP {} due to excessive requests",
            "Microservice communication established with {} service using circuit breaker",
            "Background job processing user data synchronization task",
            "API endpoint responded with detailed error information and stack trace"
        ]
        
        logs = []
        for i in range(count):
            message_template = message_templates[i % len(message_templates)]
            if '{}' in message_template:
                if 'query executed' in message_template:
                    message = message_template.format(50 + (i % 1000))
                elif 'Rate limiting' in message_template:
                    message = message_template.format(f"user_{i % 1000}", f"192.168.{i % 255}.{(i * 7) % 255}")
                elif 'Microservice communication' in message_template:
                    message = message_template.format(services[i % len(services)])
                else:
                    message = message_template
            else:
                message = message_template
            
            log = {
                'timestamp': f"2025-05-27T{10 + i % 14:02d}:{i % 60:02d}:{(i * 13) % 60:02d}.{i % 1000:03d}Z",
                'level': levels[i % len(levels)],
                'service': services[i % len(services)],
                'message': message,
                'request_id': f"req_{i:08d}_{int(time.time() * 1000) % 10000}",
                'response_time_ms': 50 + (i % 1000) + (i // 100),
                'status_code': 200 if i % 10 != 0 else (500 if i % 20 == 0 else 404),
                'user_context': {
                    'user_id': f"user_{i % 10000}",
                    'session_id': f"session_{(i * 7) % 5000}",
                    'ip_address': f"192.168.{i % 255}.{(i * 7) % 255}",
                    'user_agent': f"Mozilla/5.0 (compatible; ServiceClient/{services[i % len(services)]}/2.1.0)"
                },
                'tags': [
                    f"env_production",
                    f"version_2.{i % 10}.{i % 5}",
                    f"datacenter_{['us-east', 'us-west', 'eu-central'][i % 3]}",
                    f"priority_{['high', 'medium', 'low'][i % 3]}"
                ]
            }
            logs.append(log)
        
        return logs
    
    def measure_serialization_performance(self, logs: List[Dict], iterations: int = 50) -> Dict:
        """Measure JSON vs Protobuf serialization performance with enhanced metrics"""
        print(f"\n🔬 Enhanced Performance Testing (Protocol Buffers v29.3)")
        print(f"Testing {len(logs)} log entries across {iterations} iterations")
        print("-" * 60)
        
        # JSON Serialization Test
        json_times = []
        json_sizes = []
        
        print("📊 Running JSON serialization tests...")
        for i in range(iterations):
            if i % (iterations // 4) == 0 and i > 0:
                print(f"  Progress: {i}/{iterations} iterations completed")
                
            start_time = time.perf_counter()
            json_data = json.dumps(logs, separators=(',', ':'))
            end_time = time.perf_counter()
            
            json_times.append(end_time - start_time)
            json_sizes.append(len(json_data.encode('utf-8')))
        
        # Protobuf Serialization Test
        protobuf_times = []
        protobuf_sizes = []
        
        print("📊 Running Protocol Buffers serialization tests...")
        for i in range(iterations):
            if i % (iterations // 4) == 0 and i > 0:
                print(f"  Progress: {i}/{iterations} iterations completed")
                
            start_time = time.perf_counter()
            protobuf_data = self.processor.serialize_to_protobuf(logs)
            end_time = time.perf_counter()
            
            protobuf_times.append(end_time - start_time)
            protobuf_sizes.append(len(protobuf_data))
        
        # Calculate statistics
        results = {
            'json_time_mean': statistics.mean(json_times),
            'json_time_stdev': statistics.stdev(json_times) if len(json_times) > 1 else 0,
            'json_size_mean': statistics.mean(json_sizes),
            'protobuf_time_mean': statistics.mean(protobuf_times),
            'protobuf_time_stdev': statistics.stdev(protobuf_times) if len(protobuf_times) > 1 else 0,
            'protobuf_size_mean': statistics.mean(protobuf_sizes),
            'speed_improvement': statistics.mean(json_times) / statistics.mean(protobuf_times),
            'size_reduction': statistics.mean(json_sizes) / statistics.mean(protobuf_sizes),
            'iterations': iterations
        }
        
        self.print_enhanced_performance_results(results, len(logs))
        return results
    
    def print_enhanced_performance_results(self, results: Dict, log_count: int):
        """Print comprehensive performance results"""
        print("\n" + "=" * 70)
        print("📊 COMPREHENSIVE PERFORMANCE ANALYSIS (Protocol Buffers v29.3)")
        print("=" * 70)
        
        # Timing Results
        print("\n⏱️  SERIALIZATION PERFORMANCE")
        print("-" * 50)
        print(f"JSON (Average):           {results['json_time_mean']:.6f}s ± {results['json_time_stdev']:.6f}s")
        print(f"Protocol Buffers (Avg):   {results['protobuf_time_mean']:.6f}s ± {results['protobuf_time_stdev']:.6f}s")
        print(f"⚡ Speed Improvement:      {results['speed_improvement']:.2f}x faster")
        print(f"📈 Throughput Gain:       {(results['speed_improvement'] - 1) * 100:.1f}% more logs/second")
        
        # Size Results
        print(f"\n💾 DATA SIZE COMPARISON")
        print("-" * 50)
        print(f"JSON Size (Average):      {results['json_size_mean']:,.0f} bytes")
        print(f"Protocol Buffers (Avg):   {results['protobuf_size_mean']:,.0f} bytes")
        print(f"💰 Size Reduction:        {results['size_reduction']:.2f}x smaller")
        print(f"📉 Storage Savings:       {((results['json_size_mean'] - results['protobuf_size_mean']) / results['json_size_mean']) * 100:.1f}% less storage")
        
        # Real-world Impact
        print(f"\n🌍 REAL-WORLD IMPACT ANALYSIS")
        print("-" * 50)
        daily_logs = 1_000_000
        bytes_saved_daily = (results['json_size_mean'] - results['protobuf_size_mean']) * daily_logs
        time_saved_daily = (results['json_time_mean'] - results['protobuf_time_mean']) * daily_logs
        
        print(f"With {daily_logs:,} logs per day:")
        print(f"📊 Storage Savings:       {bytes_saved_daily / 1024 / 1024:.1f} MB/day")
        print(f"📊 Annual Storage:        {bytes_saved_daily * 365 / 1024 / 1024 / 1024:.1f} GB/year")
        print(f"⏰ Time Savings:          {time_saved_daily:.2f} seconds/day")
        print(f"💻 CPU Efficiency:        {((results['json_time_mean'] - results['protobuf_time_mean']) / results['json_time_mean']) * 100:.1f}% less CPU usage")

def main():
    """Run comprehensive performance analysis"""
    tester = PerformanceTester()
    
    print("🚀 Protocol Buffers v29.3 Performance Analysis Suite")
    print("=" * 60)
    
    # Test scenarios
    test_scenarios = [
        (500, "Small batch"),
        (2000, "Medium batch"),
        (5000, "Large batch")
    ]
    
    for log_count, description in test_scenarios:
        print(f"\n🎯 Testing Scenario: {description} ({log_count:,} logs)")
        logs = tester.generate_sample_logs(log_count)
        tester.measure_serialization_performance(logs, iterations=25)
        print("\n" + "="*70)

if __name__ == "__main__":
    main()
