"""
Demo web server for log enrichment pipeline.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask, render_template, request, jsonify
import json
import logging
from datetime import datetime

from src.pipeline import LogEnrichmentPipeline

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Initialize enrichment pipeline
pipeline = LogEnrichmentPipeline()

@app.route('/')
def index():
    """Main demo page."""
    return render_template('index.html')

@app.route('/api/enrich', methods=['POST'])
def enrich_log():
    """Enrich a log entry via API."""
    try:
        data = request.get_json()
        raw_log = data.get('log_message', '')
        source = data.get('source', 'demo')
        
        if not raw_log:
            return jsonify({'error': 'No log message provided'}), 400
        
        # Enrich the log
        enriched = pipeline.enrich_log(raw_log, source)
        
        return jsonify({
            'success': True,
            'enriched_log': enriched,
            'original_log': raw_log
        })
        
    except Exception as e:
        logger.error(f"API enrichment failed: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats')
def get_stats():
    """Get pipeline statistics."""
    return jsonify(pipeline.get_statistics())

@app.route('/api/sample-logs')
def get_sample_logs():
    """Get sample log entries for testing."""
    sample_logs = [
        "INFO: User login successful for user_id=12345",
        "ERROR: Database connection timeout after 30 seconds",
        "WARN: High memory usage detected: 89% of available memory",
        "DEBUG: Processing payment transaction id=abc123",
        "CRITICAL: System disk space critically low: 95% full",
        "INFO: Cache refresh completed in 150ms",
        "ERROR: Failed to authenticate user: invalid credentials",
        "WARN: API rate limit approaching for client_id=xyz789"
    ]
    return jsonify(sample_logs)

if __name__ == '__main__':
    print("Starting Log Enrichment Demo Server...")
    print("Open http://localhost:8080 in your browser")
    app.run(host='0.0.0.0', port=8080, debug=True)
