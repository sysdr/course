#!/usr/bin/env python3
import asyncio
import json
import random
import time
import redis.asyncio as redis
from datetime import datetime

async def generate_demo_logs():
    """Generate demo log data for testing consumers"""
    client = redis.from_url("redis://localhost:6379")
    
    # Sample log templates
    log_templates = [
        {
            "level": "INFO",
            "source": "web-server",
            "message_template": "{method} {endpoint} {status}",
            "metadata_template": {
                "endpoint": "/api/users",
                "method": "GET",
                "status_code": 200,
                "response_time": lambda: random.uniform(10, 100)
            }
        },
        {
            "level": "ERROR",
            "source": "database",
            "message_template": "Database connection failed: {error}",
            "metadata_template": {
                "error": "Connection timeout",
                "retry_count": lambda: random.randint(1, 5)
            }
        },
        {
            "level": "WARN",
            "source": "auth-service",
            "message_template": "Failed login attempt from {ip}",
            "metadata_template": {
                "ip": lambda: f"192.168.1.{random.randint(1, 255)}",
                "username": lambda: random.choice(["admin", "user", "test"])
            }
        }
    ]
    
    endpoints = ["/api/users", "/api/orders", "/api/products", "/api/auth", "/api/metrics"]
    methods = ["GET", "POST", "PUT", "DELETE"]
    
    print("Generating demo logs...")
    
    for i in range(100):
        template = random.choice(log_templates)
        
        # Create log message
        log_message = {
            "id": f"demo-{i}",
            "timestamp": time.time(),
            "level": template["level"],
            "source": template["source"],
            "message": template["message_template"].format(
                method=random.choice(methods),
                endpoint=random.choice(endpoints),
                status=random.choice([200, 404, 500]),
                error="Connection timeout",
                ip=f"192.168.1.{random.randint(1, 255)}"
            )
        }
        
        # Add metadata
        metadata = {}
        for key, value in template["metadata_template"].items():
            if callable(value):
                metadata[key] = value()
            else:
                metadata[key] = value
        
        # For web server logs, randomize endpoint and response time
        if template["source"] == "web-server":
            metadata["endpoint"] = random.choice(endpoints)
            metadata["method"] = random.choice(methods)
            metadata["status_code"] = random.choice([200, 200, 200, 404, 500])  # Weighted towards 200
            metadata["response_time"] = random.uniform(10, 200)
        
        log_message["metadata"] = metadata
        
        # Send to Redis stream
        await client.xadd("logs", {"data": json.dumps(log_message)})
        
        if (i + 1) % 20 == 0:
            print(f"Generated {i + 1} logs...")
            await asyncio.sleep(0.1)  # Small delay
    
    await client.close()
    print("Demo log generation complete!")

if __name__ == "__main__":
    asyncio.run(generate_demo_logs())
