"""Web dashboard for exactly-once processing monitoring"""

from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
import json
import threading
import time
from datetime import datetime

from src.monitoring.transaction_monitor import TransactionMonitor
from config.kafka_config import DATABASE_URL

app = Flask(__name__)
app.config['SECRET_KEY'] = 'exactly-once-demo-secret'
socketio = SocketIO(app, cors_allowed_origins="*")

# Initialize monitor
monitor = TransactionMonitor(DATABASE_URL)

@app.route('/')
def dashboard():
    return render_template('dashboard.html')

@app.route('/test')
def test_dashboard():
    return render_template('test_dashboard.html')

@app.route('/api/stats')
def get_stats():
    try:
        stats = monitor.get_transaction_stats()
        balances = monitor.get_account_balances()
        recent_transactions = monitor.get_recent_transactions()
        guarantee_check = monitor.check_exactly_once_guarantee()
        
        return jsonify({
            'stats': stats,
            'balances': balances,  # Changed from 'account_balances'
            'recent_transactions': recent_transactions,
            'guarantee_check': guarantee_check
        })
    except Exception as e:
        return jsonify({
            'stats': {'total_transactions': 0, 'completed_transactions': 0, 'failed_transactions': 0, 'processing_rate': 0},
            'balances': [],
            'recent_transactions': [],
            'guarantee_check': {'guarantee_status': 'UNKNOWN'}
        })

@socketio.on('connect')
def handle_connect():
    emit('connected', {'data': 'Connected to exactly-once monitoring'})

def background_updates():
    """Send real-time updates to connected clients"""
    while True:
        try:
            stats = monitor.get_transaction_stats()
            balances = monitor.get_account_balances()
            recent_transactions = monitor.get_recent_transactions()
            guarantee_check = monitor.check_exactly_once_guarantee()
            
            socketio.emit('stats_update', {
                'stats': stats,
                'account_balances': balances,
                'recent_transactions': recent_transactions,
                'guarantee_check': guarantee_check,
                'timestamp': datetime.utcnow().isoformat()
            })
            
            time.sleep(5)  # Update every 5 seconds
        except Exception as e:
            print(f"Background update error: {e}")
            time.sleep(10)

if __name__ == '__main__':
    # Start background monitoring
    monitor.start_monitoring()
    
    # Start background updates
    update_thread = threading.Thread(target=background_updates)
    update_thread.daemon = True
    update_thread.start()
    
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)
