#!/usr/bin/env python3
import time
import statistics
from src.normalizer import LogNormalizer

def benchmark_normalizer():
    normalizer = LogNormalizer()
    
    json_logs = [b'{"timestamp": "2024-01-15T10:30:00Z", "level": "ERROR", "message": "Test error %d"}' % i for i in range(1000)]
    text_logs = [b'2024-01-15 10:30:00 INFO Test message %d' % i for i in range(1000)]
    
    start_time = time.perf_counter()
    for log in json_logs:
        normalizer.normalize(log)
    json_time = time.perf_counter() - start_time
    
    start_time = time.perf_counter()
    for log in text_logs:
        normalizer.normalize(log)
    text_time = time.perf_counter() - start_time
    
    print(f"JSON Processing: {json_time:.4f}s for 1000 logs ({json_time*1000:.2f}ms avg)")
    print(f"Text Processing: {text_time:.4f}s for 1000 logs ({text_time*1000:.2f}ms avg)")
    print(f"Total throughput: {2000/(json_time + text_time):.0f} logs/second")

if __name__ == '__main__':
    benchmark_normalizer()
