#!/usr/bin/env python3

import requests
import json
import time
import random
from datetime import datetime, timedelta

def generate_demo_data():
    """Generate realistic demo log data"""
    
    services = ['auth', 'payment', 'user-api', 'inventory', 'notification', 'analytics']
    levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
    
    # Error messages by service
    messages = {
        'auth': [
            'User authentication successful',
            'Invalid credentials provided',
            'Password reset requested',
            'Account locked due to failed attempts',
            'Two-factor authentication enabled',
            'Session expired',
            'JWT token validation failed',
            'OAuth callback received'
        ],
        'payment': [
            'Payment processing completed',
            'Credit card validation failed', 
            'Insufficient funds detected',
            'Payment gateway timeout',
            'Refund processed successfully',
            'Fraud detection triggered',
            'Payment webhook received',
            'Subscription renewal failed'
        ],
        'user-api': [
            'User profile updated',
            'Invalid request parameters',
            'Rate limit exceeded',
            'Database query timeout',
            'Cache miss for user data',
            'User registration completed',
            'Profile picture uploaded',
            'Email verification sent'
        ],
        'inventory': [
            'Stock level updated',
            'Low stock warning triggered',
            'Product variant created',
            'Inventory sync completed',
            'Warehouse transfer initiated',
            'Stock adjustment made',
            'Reorder point reached',
            'Product discontinued'
        ],
        'notification': [
            'Email notification sent',
            'Push notification delivered',
            'SMS delivery failed',
            'Email template rendered',
            'Notification preferences updated',
            'Webhook delivery attempted',
            'Notification queue processed',
            'Delivery receipt received'
        ],
        'analytics': [
            'Event tracking processed',
            'Analytics data aggregated',
            'Report generation completed',
            'Metric threshold exceeded',
            'Dashboard data refreshed',
            'Conversion funnel updated',
            'A/B test results compiled',
            'Data export initiated'
        ]
    }
    
    # Generate 100 log entries
    logs = []
    for i in range(100):
        service = random.choice(services)
        level = random.choices(levels, weights=[50, 25, 15, 10])[0]  # Weighted distribution
        message = random.choice(messages[service])
        
        # Create log entry
        log_entry = {
            'level': level,
            'service': service,
            'message': message,
            'source_ip': f"192.168.{random.randint(1, 10)}.{random.randint(1, 255)}",
            'user_id': f"user_{random.randint(1, 1000)}" if random.random() > 0.3 else None,
            'request_id': f"req_{random.randint(10000, 99999)}",
            'metadata': {
                'response_time': random.randint(10, 2000),
                'endpoint': f"/api/v1/{service}/{random.choice(['users', 'orders', 'products', 'sessions'])}",
                'user_agent': random.choice([
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
                ]),
                'request_size': random.randint(100, 10000),
                'session_id': f"sess_{random.randint(1000, 9999)}"
            }
        }
        
        logs.append(log_entry)
    
    return logs

def submit_demo_logs():
    """Submit demo logs to the API"""
    
    base_url = "http://localhost:8000"
    logs = generate_demo_data()
    
    print(f"🔥 Generating {len(logs)} demo log entries...")
    
    successful = 0
    failed = 0
    
    for i, log_entry in enumerate(logs):
        try:
            response = requests.post(f"{base_url}/api/logs", json=log_entry, timeout=5)
            if response.status_code == 200:
                successful += 1
                print(f"✅ Log {i+1}/{len(logs)}: {log_entry['level']} - {log_entry['service']}")
            else:
                failed += 1
                print(f"❌ Failed to submit log {i+1}: {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            failed += 1
            print(f"❌ Network error for log {i+1}: {e}")
        
        # Small delay to simulate real-time log generation
        time.sleep(0.1)
    
    print(f"\n📊 Demo data generation complete!")
    print(f"✅ Successfully submitted: {successful} logs")
    print(f"❌ Failed submissions: {failed} logs")
    print(f"\n🌐 Open http://localhost:8000 to start searching!")
    
    # Suggest some sample searches
    print(f"\n💡 Try these sample searches:")
    print(f"   🔍 'error payment' - Find payment errors")
    print(f"   🔍 'timeout' - Find timeout-related logs")
    print(f"   🔍 Filter by level: ERROR, service: payment")
    print(f"   🔍 Filter by time range: Last 1 hour")

def test_search_api():
    """Test the search API with sample queries"""
    
    base_url = "http://localhost:8000"
    
    test_searches = [
        {
            "name": "Basic text search",
            "request": {
                "query": "error",
                "filters": {},
                "limit": 5
            }
        },
        {
            "name": "Error level filter", 
            "request": {
                "query": "",
                "filters": {"levels": ["ERROR"]},
                "limit": 5
            }
        },
        {
            "name": "Payment service filter",
            "request": {
                "query": "",
                "filters": {"services": ["payment"]},
                "limit": 5
            }
        },
        {
            "name": "Combined filters",
            "request": {
                "query": "failed",
                "filters": {
                    "levels": ["ERROR", "WARN"],
                    "services": ["payment", "auth"]
                },
                "limit": 5
            }
        }
    ]
    
    print("🧪 Testing search API...")
    
    for test in test_searches:
        try:
            response = requests.post(f"{base_url}/api/search", json=test["request"], timeout=10)
            if response.status_code == 200:
                data = response.json()
                print(f"✅ {test['name']}: Found {data['total_count']} results in {data['execution_time_ms']:.1f}ms")
            else:
                print(f"❌ {test['name']}: HTTP {response.status_code}")
        except Exception as e:
            print(f"❌ {test['name']}: {e}")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        test_search_api()
    else:
        submit_demo_logs()
