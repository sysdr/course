"""
Web Dashboard for Avro Schema Evolution Demo
Provides real-time visualization of schema compatibility
"""

from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import sys
import os

# Add src to path so we can import our modules
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..'))

from src.serializers.avro_handler import AvroSchemaManager, LogEventProcessor
from src.models.log_event import create_log_event

app = Flask(__name__)
CORS(app)

# Global instances
schema_manager = AvroSchemaManager()
event_processor = LogEventProcessor()


@app.route('/')
def dashboard():
    """Main dashboard page"""
    return render_template('dashboard.html')


@app.route('/api/schema-info')
def get_schema_info():
    """Get comprehensive schema information"""
    try:
        return jsonify({
            "status": "success",
            "data": schema_manager.get_compatibility_info()
        })
    except Exception as e:
        return jsonify({
            "status": "error", 
            "message": str(e)
        }), 500


@app.route('/api/test-compatibility', methods=['POST'])
def test_compatibility():
    """Test schema compatibility with sample data"""
    try:
        data = request.json
        schema_version = data.get('schema_version', 'v1')
        
        # Create sample event
        sample_event = create_log_event(schema_version)
        
        # Process the event to test compatibility
        result = event_processor.process_event(sample_event.to_dict(), schema_version)
        
        return jsonify({
            "status": "success",
            "message": result,
            "sample_data": sample_event.to_dict(),
            "processing_summary": event_processor.get_processing_summary()
        })
        
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route('/api/generate-sample/<version>')
def generate_sample(version):
    """Generate sample data for specified schema version"""
    try:
        sample_event = create_log_event(version)
        return jsonify({
            "status": "success", 
            "data": sample_event.to_dict(),
            "schema_version": version
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


if __name__ == '__main__':
    print("🌐 Starting Avro Schema Evolution Dashboard...")
    print("📊 Access dashboard at: http://localhost:5000")
    app.run(debug=True, host='0.0.0.0', port=5000)
