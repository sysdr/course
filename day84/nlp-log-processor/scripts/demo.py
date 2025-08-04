#!/usr/bin/env python3

import requests
import json
import time
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from nlp.sample_data import SampleLogGenerator

def run_demo():
    """Run comprehensive demo of NLP log processing"""
    print("🚀 Starting NLP Log Processing Demo")
    print("=" * 50)
    
    base_url = "http://localhost:5000/api"
    
    # Check if server is running
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code != 200:
            print("❌ Server not responding properly")
            return False
    except requests.exceptions.RequestException:
        print("❌ Cannot connect to server. Make sure it's running on port 5000")
        return False
    
    print("✅ Server is healthy and responding")
    
    # Generate sample log data
    print("\n📝 Generating sample log messages...")
    generator = SampleLogGenerator()
    sample_logs = generator.generate_batch(10)
    
    for i, log in enumerate(sample_logs[:3], 1):
        print(f"  {i}. {log['message']}")
    print(f"  ... and {len(sample_logs) - 3} more")
    
    # Test single message analysis
    print("\n🔍 Testing single message analysis...")
    test_message = "ERROR: Database connection timeout after 30 seconds to server 192.168.1.100 for user admin@company.com"
    
    response = requests.post(f"{base_url}/analyze", json={'message': test_message})
    
    if response.status_code == 200:
        result = response.json()
        analysis = result['nlp_analysis']
        
        print(f"  ✅ Intent: {analysis['intent']} (confidence: {analysis['intent_confidence']:.2f})")
        print(f"  ✅ Sentiment: {analysis['sentiment']['compound']:.3f}")
        print(f"  ✅ Keywords: {', '.join(analysis['keywords'])}")
        
        if analysis['entities']:
            print("  ✅ Entities found:")
            for entity_type, entities in analysis['entities'].items():
                print(f"    - {entity_type}: {', '.join(entities)}")
    else:
        print(f"  ❌ Analysis failed: {response.text}")
        return False
    
    # Test batch processing
    print("\n🔄 Testing batch processing...")
    response = requests.post(f"{base_url}/process", json={'logs': sample_logs})
    
    if response.status_code == 200:
        result = response.json()
        summary = result['summary']
        
        print(f"  ✅ Processed {summary['total_processed']} log messages")
        print(f"  ✅ Average sentiment: {summary['average_sentiment']:.3f}")
        print("  ✅ Intent distribution:")
        for intent, count in summary['intent_distribution'].items():
            print(f"    - {intent}: {count}")
        
        if summary['top_keywords']:
            print("  ✅ Top keywords:")
            for keyword, count in list(summary['top_keywords'].items())[:5]:
                print(f"    - {keyword}: {count}")
    else:
        print(f"  ❌ Batch processing failed: {response.text}")
        return False
    
    # Check statistics
    print("\n📊 Checking processing statistics...")
    response = requests.get(f"{base_url}/stats")
    
    if response.status_code == 200:
        stats = response.json()
        print(f"  ✅ Total processed: {stats['processed_count']}")
        print(f"  ✅ Entity patterns loaded: {stats['patterns_loaded']}")
    
    print("\n🎉 Demo completed successfully!")
    print("\n🌐 Open http://localhost:5000 to view the interactive dashboard")
    
    return True

if __name__ == '__main__':
    success = run_demo()
    sys.exit(0 if success else 1)
