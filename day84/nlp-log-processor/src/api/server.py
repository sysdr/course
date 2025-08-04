from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import asyncio
import json
import os
from datetime import datetime
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from nlp.log_processor import NLPLogProcessor

app = Flask(__name__, template_folder='../web/templates', static_folder='../web/static')
CORS(app)

# Global NLP processor instance
nlp_processor = None

def initialize_nlp():
    global nlp_processor
    if nlp_processor is None:
        nlp_processor = NLPLogProcessor()
        
        # Run async initialization in event loop
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(nlp_processor.initialize())

# Initialize NLP processor on first request
@app.before_request
def before_request():
    if nlp_processor is None:
        initialize_nlp()

@app.route('/')
def dashboard():
    """Serve the main dashboard"""
    return render_template('dashboard.html')

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'processed_count': nlp_processor.processed_count if nlp_processor else 0
    })

@app.route('/api/process', methods=['POST'])
def process_logs():
    """Process log messages with NLP analysis"""
    try:
        data = request.get_json()
        
        if not data or 'logs' not in data:
            return jsonify({'error': 'Missing logs data'}), 400
        
        logs = data['logs']
        
        # Run async processing
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        processed_logs = loop.run_until_complete(
            nlp_processor.batch_process(logs)
        )
        
        summary = nlp_processor.generate_summary(processed_logs)
        
        return jsonify({
            'processed_logs': processed_logs,
            'summary': summary,
            'status': 'success'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/analyze', methods=['POST'])
def analyze_single_log():
    """Analyze a single log message"""
    try:
        data = request.get_json()
        
        if not data or 'message' not in data:
            return jsonify({'error': 'Missing message'}), 400
        
        log_message = {'message': data['message']}
        
        # Run async processing
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        result = loop.run_until_complete(
            nlp_processor.process_log_message(log_message)
        )
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats')
def get_stats():
    """Get processing statistics"""
    if not nlp_processor:
        return jsonify({'error': 'NLP processor not initialized'}), 500
    
    return jsonify({
        'processed_count': nlp_processor.processed_count,
        'cache_size': len(nlp_processor.entity_cache),
        'patterns_loaded': len(nlp_processor.entity_patterns),
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/read-logs', methods=['POST'])
def read_host_logs():
    """Read logs from host machine file"""
    try:
        data = request.get_json()
        
        if not data or 'file_path' not in data:
            return jsonify({'error': 'Missing file_path'}), 400
        
        file_path = data['file_path']
        
        # Security check - only allow reading from specific directories
        allowed_dirs = ['/var/log', '/tmp', '/home', os.path.expanduser('~')]
        if not any(file_path.startswith(allowed_dir) for allowed_dir in allowed_dirs):
            return jsonify({'error': 'Access denied: File path not allowed'}), 403
        
        if not os.path.exists(file_path):
            return jsonify({'error': 'File not found'}), 404
        
        # Read log file
        logs = []
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if line:  # Skip empty lines
                        logs.append({
                            'message': line,
                            'line_number': line_num,
                            'source_file': file_path
                        })
        except Exception as e:
            return jsonify({'error': f'Error reading file: {str(e)}'}), 500
        
        # Process logs with NLP
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        processed_logs = loop.run_until_complete(
            nlp_processor.batch_process(logs)
        )
        
        summary = nlp_processor.generate_summary(processed_logs)
        
        return jsonify({
            'processed_logs': processed_logs,
            'summary': summary,
            'total_lines': len(logs),
            'file_path': file_path,
            'status': 'success'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/demo-logs')
def get_demo_logs():
    """Get sample demo logs for testing"""
    demo_logs = [
        {
            'message': '2024-01-15 10:30:15 ERROR [UserService] Authentication failed for user john.doe@example.com from IP 192.168.1.100',
            'line_number': 1,
            'source_file': 'demo'
        },
        {
            'message': '2024-01-15 10:30:20 WARN [DatabaseService] Slow query detected: SELECT * FROM users WHERE email = ? (execution time: 2.5s)',
            'line_number': 2,
            'source_file': 'demo'
        },
        {
            'message': '2024-01-15 10:30:25 INFO [PaymentService] Payment processed successfully for order #12345, amount: $99.99',
            'line_number': 3,
            'source_file': 'demo'
        },
        {
            'message': '2024-01-15 10:30:30 ERROR [EmailService] Failed to send email to user@example.com: SMTP connection timeout',
            'line_number': 4,
            'source_file': 'demo'
        },
        {
            'message': '2024-01-15 10:30:35 SECURITY [AuthService] Multiple failed login attempts detected from IP 203.0.113.45',
            'line_number': 5,
            'source_file': 'demo'
        },
        {
            'message': '2024-01-15 10:30:40 INFO [CacheService] Cache miss for key: user_profile_67890, fetching from database',
            'line_number': 6,
            'source_file': 'demo'
        },
        {
            'message': '2024-01-15 10:30:45 ERROR [FileService] File upload failed: /uploads/document.pdf exceeds maximum size limit',
            'line_number': 7,
            'source_file': 'demo'
        },
        {
            'message': '2024-01-15 10:30:50 WARN [MonitoringService] High CPU usage detected: 85% on server web-01',
            'line_number': 8,
            'source_file': 'demo'
        },
        {
            'message': '2024-01-15 10:30:55 INFO [NotificationService] Push notification sent to device token: abc123def456',
            'line_number': 9,
            'source_file': 'demo'
        },
        {
            'message': '2024-01-15 10:31:00 ERROR [API Gateway] Rate limit exceeded for client API_KEY_789012',
            'line_number': 10,
            'source_file': 'demo'
        }
    ]
    
    # Process demo logs with NLP
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    processed_logs = loop.run_until_complete(
        nlp_processor.batch_process(demo_logs)
    )
    
    summary = nlp_processor.generate_summary(processed_logs)
    
    return jsonify({
        'processed_logs': processed_logs,
        'summary': summary,
        'total_lines': len(demo_logs),
        'file_path': 'demo',
        'status': 'success'
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
