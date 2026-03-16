#!/usr/bin/env python3
import time
import random
import json
from src.normalizer import LogNormalizer

def simulate_log_stream():
    normalizer = LogNormalizer()
    
    log_templates = [
        b'{"timestamp": "2024-01-15T10:30:%02d", "level": "ERROR", "message": "Database error %d", "service": "db-service"}',
        b'{"timestamp": "2024-01-15T10:30:%02d", "level": "INFO", "message": "Request processed %d", "service": "api-gateway"}',
        b'2024-01-15 10:30:%02d ERROR Connection timeout %d',
        b'2024-01-15 10:30:%02d INFO User authenticated %d',
        b'[2024-01-15T10:30:%02d] WARN: Memory usage high %d',
    ]
    
    start_time = time.perf_counter()
    processed_count = 0
    error_count = 0
    
    for i in range(10000):
        template = random.choice(log_templates)
        log_data = template % (i % 60, i)
        
        try:
            result = normalizer.normalize(log_data)
            processed_count += 1
            
            if i % 1000 == 0:
                print(f"Processed {i} logs...")
                
        except Exception as e:
            error_count += 1
    
    end_time = time.perf_counter()
    total_time = end_time - start_time
    
    print(f"\n📊 Production Simulation Results:")
    print(f"Total logs processed: {processed_count}")
    print(f"Total errors: {error_count}")
    print(f"Processing time: {total_time:.2f} seconds")
    print(f"Throughput: {processed_count/total_time:.0f} logs/second")
    print(f"Success rate: {(processed_count/(processed_count + error_count))*100:.2f}%")

if __name__ == '__main__':
    simulate_log_stream()
