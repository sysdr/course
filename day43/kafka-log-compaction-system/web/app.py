#!/usr/bin/env python3

from flask import Flask, render_template, jsonify
import json
import kafka
from kafka import KafkaConsumer, TopicPartition
import threading
import time

app = Flask(__name__)

class CompactionDashboard:
    def __init__(self):
        self.metrics = {
            'total_messages': 0,
            'unique_keys': 0,
            'compaction_ratio': 0.0,
            'recent_updates': []
        }
        self.running = False
        
    def start_monitoring(self):
        self.running = True
        monitor_thread = threading.Thread(target=self._monitor_loop)
        monitor_thread.daemon = True
        monitor_thread.start()
        
    def _monitor_loop(self):
        try:
            consumer = KafkaConsumer(
                'user-profiles-compacted',
                bootstrap_servers=['localhost:9092'],
                auto_offset_reset='earliest',
                value_deserializer=lambda x: x.decode('utf-8') if x else None
            )
            
            keys_seen = set()
            total_messages = 0
            
            for message in consumer:
                if not self.running:
                    break
                    
                total_messages += 1
                
                if message.key:
                    keys_seen.add(message.key.decode('utf-8'))
                
                if message.value:
                    try:
                        data = json.loads(message.value)
                        self.metrics['recent_updates'].append({
                            'userId': data.get('userId', 'unknown'),
                            'updateType': data.get('updateType', 'unknown'),
                            'timestamp': data.get('timestamp', 'unknown'),
                            'partition': message.partition,
                            'offset': message.offset
                        })
                        
                        # Keep only last 20 updates
                        if len(self.metrics['recent_updates']) > 20:
                            self.metrics['recent_updates'].pop(0)
                            
                    except json.JSONDecodeError:
                        pass
                
                self.metrics['total_messages'] = total_messages
                self.metrics['unique_keys'] = len(keys_seen)
                
                if total_messages > 0:
                    self.metrics['compaction_ratio'] = len(keys_seen) / total_messages
                    
        except Exception as e:
            print(f"Monitoring error: {e}")

dashboard = CompactionDashboard()

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/metrics')
def get_metrics():
    return jsonify(dashboard.metrics)

if __name__ == '__main__':
    dashboard.start_monitoring()
    app.run(host='0.0.0.0', port=8080, debug=True)
