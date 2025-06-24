from flask import Flask, render_template, jsonify
from flask_socketio import SocketIO
import threading
import time
import json
from kafka_dashboard import StreamProcessor

app = Flask(__name__, template_folder='../../web/templates', static_folder='../../web/static')
app.config['SECRET_KEY'] = 'dashboard-secret'
socketio = SocketIO(app, cors_allowed_origins="*")

# Global stream processor
processor = StreamProcessor()

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/metrics')
def get_metrics():
    """Get current metrics"""
    return jsonify(processor.get_windowed_metrics())

@app.route('/api/historical')
def get_historical():
    """Get historical data for charts"""
    return jsonify(processor.get_historical_data())

@socketio.on('connect')
def handle_connect():
    print('Client connected')

@socketio.on('disconnect')
def handle_disconnect():
    print('Client disconnected')

def emit_metrics():
    """Background task to emit metrics via WebSocket"""
    while True:
        if processor.running:
            metrics = processor.get_windowed_metrics()
            historical = processor.get_historical_data()
            
            socketio.emit('metrics_update', {
                'metrics': metrics,
                'historical': historical
            })
        time.sleep(2)

def start_dashboard():
    """Start the dashboard application"""
    # Initialize Kafka
    if not processor.initialize_kafka():
        print("Failed to initialize Kafka. Starting in demo mode.")
        return
    
    # Start stream processing thread
    stream_thread = threading.Thread(target=processor.process_stream)
    stream_thread.daemon = True
    stream_thread.start()
    
    # Start metrics emission thread
    metrics_thread = threading.Thread(target=emit_metrics)
    metrics_thread.daemon = True
    metrics_thread.start()
    
    # Start Flask app
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)

if __name__ == '__main__':
    start_dashboard()
