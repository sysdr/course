#!/usr/bin/env python3
"""Integration test for log normalizer"""

import json
from src.normalizer import LogNormalizer

def test_real_logs():
    normalizer = LogNormalizer()
    
    print("🧪 Testing JSON log normalization...")
    with open('sample_logs/sample.json', 'rb') as f:
        for line in f:
            if line.strip():
                result = normalizer.normalize(line.strip())
                print(f"✅ Normalized: {result.level} - {result.message[:50]}...")
    
    print("\n🧪 Testing text log normalization...")
    with open('sample_logs/sample.txt', 'rb') as f:
        for line in f:
            if line.strip():
                result = normalizer.normalize(line.strip())
                print(f"✅ Normalized: {result.level} - {result.message[:50]}...")
    
    print("\n🎉 All integration tests passed!")

if __name__ == '__main__':
    test_real_logs()
