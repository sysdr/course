import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from flask import Flask, render_template, jsonify
from flask_socketio import SocketIO, emit
import json
import threading
import time
from anomaly_detector import detector
from log_generator import log_generator
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)

app = Flask(__name__, template_folder='../templates')
app.config['SECRET_KEY'] = 'anomaly_detection_secret'
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Global statistics
stats = {
    'total_logs': 0,
    'anomalies_detected': 0,
    'false_positives': 0,
    'true_positives': 0,
    'recent_anomalies': [],
    'detection_rate': 0.0
}

# Simulation state
simulation_active = False
simulation_thread = None

@app.route('/')
def dashboard():
    try:
        return render_template('dashboard.html')
    except Exception as e:
        return f"Error: {str(e)}", 500

@app.route('/api/stats')
def get_stats():
    return jsonify(stats)

@socketio.on('connect')
def handle_connect():
    emit('connected', {'data': 'Connected to anomaly detection dashboard'})

@socketio.on('start_simulation')
def handle_start_simulation(data):
    global simulation_active, simulation_thread
    
    try:
        anomaly_type = data.get('anomaly_type', 'slow_response')
        count = data.get('count', 5)
        interval = data.get('interval', 2)
        
        if simulation_active:
            emit('simulation_error', {'error': 'Simulation already running'})
            return
        
        simulation_active = True
        
        def run_simulation():
            global simulation_active
            try:
                for i in range(count):
                    if not simulation_active:
                        break
                    
                    # Generate anomalous log
                    if anomaly_type == 'slow_response':
                        log = log_generator.generate_anomalous_log()
                        log['anomaly_type'] = 'slow_response'
                    elif anomaly_type == 'unusual_size':
                        log = log_generator.generate_anomalous_log()
                        log['anomaly_type'] = 'unusual_size'
                    elif anomaly_type == 'suspicious_agent':
                        log = log_generator.generate_anomalous_log()
                        log['anomaly_type'] = 'suspicious_agent'
                    elif anomaly_type == 'temporal':
                        log = log_generator.generate_anomalous_log()
                        log['anomaly_type'] = 'temporal'
                    elif anomaly_type == 'high_frequency':
                        # Generate multiple logs rapidly
                        for _ in range(3):
                            log = log_generator.generate_normal_log()
                            log['anomaly_type'] = 'high_frequency'
                            # Process the log immediately
                            process_single_log(log)
                        time.sleep(interval)
                        continue
                    else:
                        log = log_generator.generate_anomalous_log()
                        log['anomaly_type'] = anomaly_type
                    
                    # Process the log
                    process_single_log(log)
                    
                    if i < count - 1:  # Don't sleep after the last one
                        time.sleep(interval)
                
                simulation_active = False
                socketio.emit('simulation_stopped', {'message': 'Simulation completed'})
                
            except Exception as e:
                logging.error(f"Simulation error: {e}")
                simulation_active = False
                socketio.emit('simulation_error', {'error': str(e)})
        
        simulation_thread = threading.Thread(target=run_simulation)
        simulation_thread.daemon = True
        simulation_thread.start()
        
        emit('simulation_started', {
            'anomaly_type': anomaly_type,
            'count': count,
            'interval': interval
        })
        
    except Exception as e:
        logging.error(f"Error starting simulation: {e}")
        emit('simulation_error', {'error': str(e)})

@socketio.on('stop_simulation')
def handle_stop_simulation():
    global simulation_active
    simulation_active = False
    emit('simulation_stopped', {'message': 'Simulation stopped by user'})

def process_single_log(log):
    """Process a single log entry and update statistics"""
    global stats
    
    # Detect anomaly
    result = detector.detect_anomaly(log)
    
    # Update statistics
    stats['total_logs'] += 1
    
    if result['is_anomaly']:
        stats['anomalies_detected'] += 1
        
        # Check if it's a true positive (we know because we generated it)
        if log.get('anomaly_type'):
            stats['true_positives'] += 1
        else:
            stats['false_positives'] += 1
        
        # Add to recent anomalies
        anomaly_info = {
            'timestamp': result['timestamp'],
            'confidence': result['confidence'],
            'type': log.get('anomaly_type', 'unknown'),
            'details': log
        }
        stats['recent_anomalies'].append(anomaly_info)
        
        # Keep only last 10 anomalies
        if len(stats['recent_anomalies']) > 10:
            stats['recent_anomalies'].pop(0)
    
    # Calculate detection rate
    if stats['anomalies_detected'] > 0:
        stats['detection_rate'] = stats['true_positives'] / stats['anomalies_detected']
    
    # Convert result to JSON-serializable format
    serializable_result = {
        'is_anomaly': bool(result['is_anomaly']),
        'confidence': float(result['confidence']),
        'methods': {
            'zscore': {
                'anomaly': bool(result['methods']['zscore']['anomaly']),
                'confidence': float(result['methods']['zscore']['confidence'])
            },
            'isolation_forest': {
                'anomaly': bool(result['methods']['isolation_forest']['anomaly']),
                'confidence': float(result['methods']['isolation_forest']['confidence'])
            },
            'temporal': {
                'anomaly': bool(result['methods']['temporal']['anomaly']),
                'confidence': float(result['methods']['temporal']['confidence'])
            }
        },
        'timestamp': str(result['timestamp']),
        'log_entry': result['log_entry']
    }
    
    # Emit to dashboard
    socketio.emit('log_processed', {
        'log': log,
        'result': serializable_result,
        'stats': stats
    })

def process_logs():
    """Background process to handle log processing"""
    global stats
    
    try:
        # Generate some historical data for training
        historical_logs = []
        for _ in range(100):
            log = log_generator.generate_normal_log()
            historical_logs.append(log)
        
        # Train models
        detector.train_models(historical_logs)
        
        # Start log generation
        log_generator.start_generation()
        
        while True:
            try:
                log = log_generator.get_log()
                if log:
                    process_single_log(log)
                
                time.sleep(0.1)
            except Exception as e:
                logging.error(f"Error in log processing: {e}")
                time.sleep(1)
    except Exception as e:
        logging.error(f"Error in process_logs: {e}")

# Start log processing in background
log_thread = threading.Thread(target=process_logs)
log_thread.daemon = True
log_thread.start()

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5001, debug=False, allow_unsafe_werkzeug=True)
