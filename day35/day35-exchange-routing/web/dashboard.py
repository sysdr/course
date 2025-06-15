import sys
import os
import time
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask, render_template, jsonify
from flask_socketio import SocketIO, emit
import pika
import json
import threading
from config.config import Config

app = Flask(__name__)
app.config['SECRET_KEY'] = 'log-routing-dashboard'
socketio = SocketIO(app, cors_allowed_origins="*")

class DashboardConsumer:
    def __init__(self):
        self.stats = {
            'total_messages': 0,
            'by_exchange': {'direct': 0, 'topic': 0, 'fanout': 0},
            'by_service': {},
            'by_level': {}
        }
        self.connection = None
        self.channel = None
        self.should_reconnect = True
        
    def connect(self):
        """Establish connection to RabbitMQ with retry logic"""
        while self.should_reconnect:
            try:
                credentials = pika.PlainCredentials(Config.RABBITMQ_USER, Config.RABBITMQ_PASSWORD)
                parameters = pika.ConnectionParameters(
                    host=Config.RABBITMQ_HOST,
                    port=Config.RABBITMQ_PORT,
                    credentials=credentials,
                    heartbeat=600,
                    blocked_connection_timeout=300
                )
                self.connection = pika.BlockingConnection(parameters)
                self.channel = self.connection.channel()
                print("✅ Connected to RabbitMQ")
                return True
            except Exception as e:
                print(f"❌ Failed to connect to RabbitMQ: {e}")
                print("🔄 Retrying in 5 seconds...")
                time.sleep(5)
        return False
        
    def connect_and_monitor(self):
        """Monitor all queues and emit stats with reconnection logic"""
        while self.should_reconnect:
            try:
                if not self.connect():
                    continue
                    
                def process_dashboard_message(ch, method, properties, body):
                    try:
                        message = json.loads(body)
                        self.update_stats(message, method.routing_key)
                        socketio.emit('log_update', {
                            'message': message,
                            'stats': self.stats,
                            'queue': method.routing_key
                        })
                        ch.basic_ack(delivery_tag=method.delivery_tag)
                    except Exception as e:
                        print(f"Dashboard processing error: {e}")
                        
                # Monitor all queues
                for queue_name in Config.QUEUES.values():
                    self.channel.basic_consume(
                        queue=queue_name,
                        on_message_callback=process_dashboard_message
                    )
                    
                print("✅ Started monitoring queues")
                self.channel.start_consuming()
                
            except pika.exceptions.AMQPConnectionError:
                print("❌ Lost connection to RabbitMQ")
                if self.connection and not self.connection.is_closed:
                    self.connection.close()
                time.sleep(5)  # Wait before reconnecting
            except Exception as e:
                print(f"❌ Dashboard monitoring error: {e}")
                time.sleep(5)  # Wait before retrying
                
    def update_stats(self, message, routing_key):
        """Update dashboard statistics"""
        self.stats['total_messages'] += 1
        
        service = message.get('service', 'unknown')
        level = message.get('level', 'unknown')
        
        # Update service stats
        self.stats['by_service'][service] = self.stats['by_service'].get(service, 0) + 1
        self.stats['by_level'][level] = self.stats['by_level'].get(level, 0) + 1
        
        # Update exchange stats based on routing key
        if routing_key.endswith('.error'):
            self.stats['by_exchange']['direct'] += 1
        elif service in ['security', 'monitoring']:
            self.stats['by_exchange']['fanout'] += 1
        else:
            self.stats['by_exchange']['topic'] += 1

dashboard_consumer = DashboardConsumer()

@app.route('/')
def dashboard():
    return render_template('dashboard.html')

@app.route('/stats')
def get_stats():
    return jsonify(dashboard_consumer.stats)

@socketio.on('connect')
def handle_connect():
    print("🔌 Client connected to dashboard")
    emit('connected', {'data': 'Connected to log routing dashboard'})

@socketio.on('disconnect')
def handle_disconnect():
    print("🔌 Client disconnected from dashboard")

if __name__ == '__main__':
    print("🚀 Starting dashboard server...")
    # Start monitoring in background thread
    monitor_thread = threading.Thread(target=dashboard_consumer.connect_and_monitor)
    monitor_thread.daemon = True
    monitor_thread.start()
    
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)
