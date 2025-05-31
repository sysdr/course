from flask import Flask, request, jsonify
from datetime import datetime, UTC
from .validator import LogValidator
from .storage import Storage

app = Flask(__name__)
validator = LogValidator()
storage = Storage()

@app.route('/health')
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'schemas_count': len(validator.schemas),
        'subjects_count': len(storage.list_subjects()),
        'timestamp': datetime.now(UTC).isoformat()
    })

@app.route('/schemas/<subject>', methods=['POST'])
def register_schema(subject):
    """Register a new schema version."""
    try:
        schema = request.get_json()
        version, schema_id = validator.register_schema(subject, schema)
        storage.save_schema(subject, version, schema)
        
        return jsonify({
            'message': 'Schema registered successfully',
            'version': version,
            'id': schema_id
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/schemas/<subject>', methods=['GET'])
def get_schema(subject):
    """Get the latest schema version."""
    schema = validator.get_schema(subject)
    if not schema:
        return jsonify({'error': 'Schema not found'}), 404
        
    return jsonify(schema)

@app.route('/subjects')
def list_subjects():
    """List all registered subjects."""
    return jsonify({
        'subjects': storage.list_subjects()
    })

@app.route('/subjects/<subject>/versions')
def get_versions(subject):
    """Get all versions for a subject."""
    versions = storage.get_versions(subject)
    if not versions:
        return jsonify({'error': 'Subject not found'}), 404
        
    return jsonify({
        'subject': subject,
        'versions': versions
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
