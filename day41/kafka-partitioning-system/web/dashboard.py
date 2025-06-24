from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
import json
import time
import threading
from datetime import datetime
import sys
import os

# Add src to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

try:
    from monitoring.consumer_monitor import monitor
    from config.topic_manager import setup_kafka_topic
    from producer.log_producer import LogMessageProducer
    from consumer.log_consumer import ConsumerGroupManager
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure to run from the project root directory")
    sys.exit(1)

app = Flask(__name__)
app.config['SECRET_KEY'] = 'kafka-partitioning-demo'
socketio = SocketIO(app, cors_allowed_origins="*")

# Global state
producer = None
consumer_manager = None
demo_running = False

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('dashboard.html')

@app.route('/api/metrics')
def get_metrics():
    """Get current monitoring metrics"""
    try:
        metrics = monitor.get_latest_metrics()
        return jsonify(metrics)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/topic/setup', methods=['POST'])
def setup_topic():
    """Setup the Kafka topic"""
    try:
        topic_info = setup_kafka_topic()
        return jsonify({'success': True, 'topic_info': topic_info})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/demo/start', methods=['POST'])
def start_demo():
    """Start the demonstration"""
    global producer, consumer_manager, demo_running
    
    try:
        if demo_running:
            return jsonify({'success': False, 'error': 'Demo already running'})
        
        # Setup topic first
        setup_kafka_topic()
        
        # Start monitoring
        monitor.start_monitoring(interval_seconds=5)
        
        # Start consumer group
        consumer_manager = ConsumerGroupManager(group_size=3)
        consumer_manager.start_consumer_group()
        
        # Start producer
        producer = LogMessageProducer("demo-producer")
        
        def run_producer():
            producer.start_continuous_production(messages_per_second=20, duration_seconds=300)
        
        producer_thread = threading.Thread(target=run_producer, daemon=True)
        producer_thread.start()
        
        demo_running = True
        
        return jsonify({'success': True, 'message': 'Demo started successfully'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/demo/stop', methods=['POST'])
def stop_demo():
    """Stop the demonstration"""
    global producer, consumer_manager, demo_running
    
    try:
        if producer:
            producer.stop_production()
        
        if consumer_manager:
            consumer_manager.stop_consumer_group()
        
        monitor.stop_monitoring()
        
        demo_running = False
        
        return jsonify({'success': True, 'message': 'Demo stopped successfully'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/consumer/stats')
def get_consumer_stats():
    """Get consumer group statistics"""
    try:
        if consumer_manager:
            stats = consumer_manager.get_group_stats()
            return jsonify(stats)
        else:
            return jsonify({'error': 'Consumer manager not running'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/producer/stats')
def get_producer_stats():
    """Get producer statistics"""
    try:
        if producer:
            stats = producer.get_stats()
            return jsonify(stats)
        else:
            return jsonify({'error': 'Producer not running'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    emit('connected', {'data': 'Connected to Kafka monitoring dashboard'})
    
    # Send initial metrics
    try:
        metrics = monitor.get_latest_metrics()
        emit('metrics_update', metrics)
    except Exception as e:
        emit('error', {'message': str(e)})

@socketio.on('request_metrics')
def handle_metrics_request():
    """Handle request for latest metrics"""
    try:
        metrics = monitor.get_latest_metrics()
        emit('metrics_update', metrics)
    except Exception as e:
        emit('error', {'message': str(e)})

def background_metrics_sender():
    """Send metrics to connected clients periodically"""
    while True:
        try:
            if demo_running:
                metrics = monitor.get_latest_metrics()
                socketio.emit('metrics_update', metrics)
            time.sleep(5)
        except Exception as e:
            print(f"Error sending metrics: {e}")
            time.sleep(5)

# Start background metrics sender
metrics_thread = threading.Thread(target=background_metrics_sender, daemon=True)
metrics_thread.start()

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=8080, debug=True)
