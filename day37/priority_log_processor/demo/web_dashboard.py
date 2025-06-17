from flask import Flask, render_template, jsonify
import asyncio
import threading
import json
import time
from src.processor import LogProcessor

app = Flask(__name__)
processor = LogProcessor()

# Global event loop for the processor
processor_loop = None

# Start processor in background thread
def run_processor():
    global processor_loop
    processor_loop = asyncio.new_event_loop()
    asyncio.set_event_loop(processor_loop)
    
    async def main():
        await processor.start()
        # Keep running
        while processor.running:
            await asyncio.sleep(0.1)
    
    try:
        processor_loop.run_until_complete(main())
    except Exception as e:
        print(f"Processor error: {e}")
    finally:
        processor_loop.close()

@app.route('/')
def dashboard():
    return render_template('dashboard.html')

@app.route('/api/status')
def api_status():
    return jsonify(processor.get_queue_status())

@app.route('/api/processed')
def api_processed():
    return jsonify(processor.get_processed_messages(50))

@app.route('/api/inject/<priority>')
def inject_message(priority):
    """Inject a test message with specified priority"""
    test_messages = {
        'critical': {'level': 'ERROR', 'message': 'Payment failed for transaction #12345', 'service': 'payment'},
        'high': {'level': 'WARN', 'message': 'High latency detected in API responses', 'service': 'api-gateway'},
        'medium': {'level': 'INFO', 'message': 'User logged in successfully', 'service': 'user-service'},
        'low': {'level': 'DEBUG', 'message': 'Database query executed', 'service': 'analytics'}
    }
    
    if priority.lower() in test_messages:
        success = processor.process_log_message(test_messages[priority.lower()])
        return jsonify({'success': success, 'message': f'{priority} message injected'})
    else:
        return jsonify({'success': False, 'message': 'Invalid priority level'}), 400

if __name__ == '__main__':
    # Start processor in background
    processor_thread = threading.Thread(target=run_processor, daemon=True)
    processor_thread.start()
    
    # Give the processor time to start
    time.sleep(2)
    
    # Start web server
    app.run(host='0.0.0.0', port=8080, debug=True)
