#!/usr/bin/env python3
"""Error aggregation consumer across all services."""

import json
from collections import defaultdict
from confluent_kafka import Consumer
from datetime import datetime, UTC

class ErrorAggregator:
    def __init__(self, bootstrap_servers='localhost:9092'):
        self.consumer = Consumer({
            'bootstrap.servers': bootstrap_servers,
            'group.id': 'error-aggregator-group',
            'auto.offset.reset': 'latest'
        })
        self.consumer.subscribe(['web-api-logs', 'user-service-logs', 'payment-service-logs'])
        self.error_stats = defaultdict(int)
        
    def process_messages(self):
        """Process messages and aggregate errors."""
        print("🔍 Starting error aggregation...")
        
        try:
            while True:
                msg = self.consumer.poll(1.0)
                
                if msg is None:
                    continue
                if msg.error():
                    print(f"Consumer error: {msg.error()}")
                    continue
                
                try:
                    log_entry = json.loads(msg.value().decode('utf-8'))
                    
                    if log_entry.get('level') == 'ERROR':
                        service = log_entry.get('service', 'unknown')
                        self.error_stats[service] += 1
                        
                        print(f"❌ ERROR in {service}: {log_entry}")
                        
                except json.JSONDecodeError:
                    print(f"Failed to decode message: {msg.value()}")
                    
        except KeyboardInterrupt:
            pass
        finally:
            self.consumer.close()
            self.print_error_summary()
                
    def print_error_summary(self):
        """Print error statistics."""
        print("\n📊 Error Summary:")
        print("=" * 40)
        for service, count in self.error_stats.items():
            print(f"{service}: {count} errors")
        print("=" * 40)

if __name__ == "__main__":
    aggregator = ErrorAggregator()
    aggregator.process_messages()
