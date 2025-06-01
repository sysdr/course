"""
Web interface for visualizing Protocol Buffers log processing
"""

from flask import Flask, render_template, jsonify
import sys
import os
from datetime import datetime, timedelta
import json

# Add src to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

try:
    from protobuf_log_processor import ProtobufLogProcessor
except ImportError:
    print("❌ Protocol Buffer processor not found. Ensure protobuf modules are compiled.")

app = Flask(__name__)
processor = ProtobufLogProcessor()

@app.route('/')
def index():
    """Main dashboard"""
    return render_template('dashboard.html')

@app.route('/api/performance-test/<int:entry_count>')
def performance_test(entry_count):
    """Run performance test and return results"""
    if entry_count > 10000:
        entry_count = 10000  # Limit for web demo
    
    results = processor.performance_comparison(entry_count)
    
    # Calculate improvements
    json_size = results["json"]["size_bytes"]
    pb_size = results["protobuf"]["size_bytes"]
    size_reduction = ((json_size - pb_size) / json_size) * 100
    
    json_serialize = results["json"]["serialize_ms"]
    pb_serialize = results["protobuf"]["serialize_ms"]
    serialize_improvement = ((json_serialize - pb_serialize) / json_serialize) * 100
    
    return jsonify({
        "results": results,
        "improvements": {
            "size_reduction_percent": round(size_reduction, 1),
            "serialize_improvement_percent": round(serialize_improvement, 1)
        },
        "entry_count": entry_count
    })

@app.route('/api/generate-sample-logs/<int:count>')
def generate_sample_logs(count):
    """Generate sample log entries"""
    entries = []
    for i in range(min(count, 100)):  # Limit for demo
        entry = processor.create_log_entry_protobuf(
            timestamp=datetime.now().isoformat(),
            level="INFO" if i % 3 == 0 else "ERROR",
            service=f"service-{i % 5}",
            message=f"Sample log message {i + 1}",
            request_id=f"req-{i + 1:06d}",
            processing_time_ms=(i % 100) + 10,
            metadata={"user_id": f"user_{i % 20}", "version": "1.0.0"}
        )
        
        # Convert to dict for JSON response
        entry_dict = {
            "timestamp": entry.timestamp,
            "level": entry.level,
            "service": entry.service,
            "message": entry.message,
            "request_id": entry.request_id,
            "processing_time_ms": entry.processing_time_ms,
            "metadata": dict(entry.metadata)
        }
        entries.append(entry_dict)
    
    return jsonify({"entries": entries, "count": len(entries)})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
