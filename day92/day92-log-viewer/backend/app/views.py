from flask import Blueprint, request, jsonify, current_app
from app.models import LogEntry
from app.utils import load_sample_logs, parse_query_filters, apply_log_filters
from app import db
import math

logs_bp = Blueprint('logs', __name__)

@logs_bp.route('/api/logs', methods=['GET', 'POST'])
def logs():
    """Get logs with optional filtering and pagination, or create a new log entry"""
    if request.method == 'POST':
        """Create a new log entry"""
        try:
            data = request.get_json()
            
            # Validate required fields
            required_fields = ['level', 'service', 'message']
            for field in required_fields:
                if field not in data:
                    return jsonify({'error': f'Missing required field: {field}'}), 400
            
            # Create log entry
            log_entry = LogEntry.from_dict(data)
            db.session.add(log_entry)
            db.session.commit()
            
            return jsonify({
                'message': 'Log entry created successfully',
                'log': log_entry.to_dict()
            }), 201
            
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    
    # GET method - existing logic
    try:
        # Parse query parameters
        page = int(request.args.get('page', 1))
        per_page = int(request.args.get('per_page', 20))
        per_page = min(per_page, 100)  # Limit to 100 per page
        
        # Parse filters
        filters = parse_query_filters(request.args)
        
        # Build query
        query = LogEntry.query
        query = apply_log_filters(query, filters)
        
        # Order by timestamp (newest first)
        query = query.order_by(LogEntry.timestamp.desc())
        
        # Get total count for pagination
        total = query.count()
        
        # Apply pagination
        logs = query.offset((page - 1) * per_page).limit(per_page).all()
        
        return jsonify({
            'logs': [log.to_dict() for log in logs],
            'pagination': {
                'page': page,
                'per_page': per_page,
                'total': total,
                'pages': math.ceil(total / per_page) if total > 0 else 0
            },
            'filters': filters
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@logs_bp.route('/api/logs/<int:log_id>', methods=['GET'])
def get_log_detail(log_id):
    """Get detailed information for a specific log entry"""
    try:
        log = LogEntry.query.get_or_404(log_id)
        return jsonify(log.to_dict())
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@logs_bp.route('/api/logs/stats', methods=['GET'])
def get_log_stats():
    """Get statistics about logs"""
    try:
        total_logs = LogEntry.query.count()
        
        # Count by level
        level_stats = {}
        levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
        for level in levels:
            count = LogEntry.query.filter(LogEntry.level == level).count()
            level_stats[level] = count
        
        # Count by service
        service_query = db.session.query(
            LogEntry.service, 
            db.func.count(LogEntry.id).label('count')
        ).group_by(LogEntry.service).all()
        
        service_stats = {service: count for service, count in service_query}
        
        return jsonify({
            'total_logs': total_logs,
            'level_stats': level_stats,
            'service_stats': service_stats
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@logs_bp.route('/api/logs/init', methods=['POST'])
def init_sample_data():
    """Initialize with sample log data"""
    try:
        count = load_sample_logs()
        return jsonify({
            'message': f'Successfully loaded {count} sample log entries',
            'count': count
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@logs_bp.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    from datetime import datetime
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat()
    })
