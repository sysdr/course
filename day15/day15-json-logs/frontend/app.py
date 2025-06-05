from flask import Flask, render_template, jsonify, request
import json
import socket
import threading
import queue
from datetime import datetime
import time
import requests
from typing import Dict, Any, List

app = Flask(__name__)

class LogDashboard:
    """
    A web dashboard for monitoring our JSON log processing system.
    
    This dashboard acts like a mission control center where you can observe
    all the activity in your distributed system. It provides real-time
    visibility into log processing, validation statistics, and system health.
    
    Think of this as the difference between flying blind versus having
    a cockpit full of instruments that tell pilots everything they need
    to know about their aircraft's status.
    """
    
    def __init__(self):
        """Initialize the dashboard with empty data structures."""
        # Store recent logs for display (keep last 100)
        self.recent_logs = []
        self.max_logs_to_store = 100
        
        # System statistics
        self.stats = {
            'total_logs': 0,
            'valid_logs': 0,
            'invalid_logs': 0,
            'error_rate': 0.0,
            'logs_per_minute': 0.0,
            'uptime_seconds': 0,
            'last_updated': datetime.utcnow().isoformat()
        }
        
        # Log level counters for visualization
        self.log_level_counts = {
            'DEBUG': 0,
            'INFO': 0,
            'WARN': 0,
            'ERROR': 0,
            'FATAL': 0
        }
        
        # Service activity tracking
        self.service_activity = {}
        
        print("📊 Log Dashboard initialized")
    
    def add_log(self, log_data: Dict[Any, Any], is_valid: bool = True):
        """
        Add a new log entry to the dashboard.
        
        This method processes each log that flows through our system,
        extracting key information for visualization and updating
        various statistics and counters.
        
        Args:
            log_data: The processed log entry
            is_valid: Whether the log passed validation
        """
        # Update basic statistics
        self.stats['total_logs'] += 1
        if is_valid:
            self.stats['valid_logs'] += 1
        else:
            self.stats['invalid_logs'] += 1
        
        # Calculate error rate as a percentage
        if self.stats['total_logs'] > 0:
            self.stats['error_rate'] = (self.stats['invalid_logs'] / self.stats['total_logs']) * 100
        
        # Update timestamp
        self.stats['last_updated'] = datetime.utcnow().isoformat()
        
        # Process valid logs for detailed analytics
        if is_valid and isinstance(log_data, dict):
            # Track log levels for the pie chart
            log_level = log_data.get('level', 'INFO')
            if log_level in self.log_level_counts:
                self.log_level_counts[log_level] += 1
            else:
                self.log_level_counts['INFO'] += 1  # Default unknown levels to INFO
            
            # Track service activity
            service_name = log_data.get('service', 'unknown')
            if service_name not in self.service_activity:
                self.service_activity[service_name] = {
                    'count': 0,
                    'last_seen': datetime.utcnow().isoformat(),
                    'levels': {'DEBUG': 0, 'INFO': 0, 'WARN': 0, 'ERROR': 0, 'FATAL': 0}
                }
            
            self.service_activity[service_name]['count'] += 1
            self.service_activity[service_name]['last_seen'] = datetime.utcnow().isoformat()
            
            if log_level in self.service_activity[service_name]['levels']:
                self.service_activity[service_name]['levels'][log_level] += 1
            
            # Add to recent logs display (with size limit)
            display_log = {
                'timestamp': log_data.get('timestamp', datetime.utcnow().isoformat()),
                'level': log_level,
                'service': service_name,
                'message': log_data.get('message', 'No message'),
                'is_valid': is_valid,
                'processed_at': datetime.utcnow().isoformat()
            }
            
            # Keep only the most recent logs to prevent memory issues
            self.recent_logs.insert(0, display_log)  # Add to front
            if len(self.recent_logs) > self.max_logs_to_store:
                self.recent_logs = self.recent_logs[:self.max_logs_to_store]  # Trim excess
    
    def get_dashboard_data(self) -> Dict[str, Any]:
        """
        Compile all dashboard data for the frontend.
        
        This method gathers statistics, recent logs, and analytics
        into a single data structure that the web interface can
        easily consume and display.
        
        Returns:
            Dictionary containing all dashboard information
        """
        return {
            'stats': self.stats,
            'recent_logs': self.recent_logs[:20],  # Only send 20 most recent for display
            'log_level_distribution': self.log_level_counts,
            'service_activity': dict(list(self.service_activity.items())[:10]),  # Top 10 services
            'total_services': len(self.service_activity),
            'active_services': len([s for s in self.service_activity.values() 
                                 if (datetime.utcnow() - datetime.fromisoformat(s['last_seen'])).seconds < 300])
        }


# Create global dashboard instance
dashboard = LogDashboard()

# Simulate some initial data for demonstration
def populate_sample_data():
    """
    Add sample data to make the dashboard interesting during demos.
    
    In a real system, this data would come from actual log processing.
    This sample data helps students see what a populated dashboard
    looks like and understand the types of insights it provides.
    """
    import random
    
    services = ['user-service', 'auth-service', 'payment-service', 'api-gateway']
    levels = ['DEBUG', 'INFO', 'WARN', 'ERROR']
    messages = [
        'Request processed successfully',
        'User authentication completed',
        'Database query executed',
        'Cache miss occurred',
        'Rate limit warning',
        'Connection timeout',
        'Invalid request format',
        'Service unavailable'
    ]
    
    # Generate 50 sample log entries
    for i in range(50):
        sample_log = {
            'timestamp': (datetime.utcnow()).isoformat(),
            'level': random.choice(levels),
            'service': random.choice(services),
            'message': random.choice(messages),
            'request_id': f"req_{random.randint(1000, 9999)}"
        }
        
        # Most logs are valid, but simulate some validation failures
        is_valid = random.random() > 0.1  # 90% success rate
        dashboard.add_log(sample_log, is_valid)

# Populate sample data when the app starts
populate_sample_data()

@app.route('/')
def index():
    """Serve the main dashboard page."""
    return render_template('dashboard.html')

@app.route('/api/dashboard-data')
def get_dashboard_data():
    """
    API endpoint that provides dashboard data as JSON.
    
    This endpoint allows the frontend JavaScript to fetch fresh data
    periodically and update the dashboard in real-time without requiring
    a full page refresh. This creates a smooth, responsive user experience.
    """
    try:
        data = dashboard.get_dashboard_data()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs')
def get_recent_logs():
    """Get recent logs for the log viewer."""
    try:
        return jsonify({
            'logs': dashboard.recent_logs[:50],
            'total_count': len(dashboard.recent_logs)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/simulate-logs', methods=['POST'])
def simulate_logs():
    """
    API endpoint to generate sample logs for testing.
    
    This endpoint allows users to trigger sample log generation
    from the web interface, which is helpful for testing and
    demonstration purposes.
    """
    try:
        count = request.json.get('count', 10) if request.is_json else 10
        
        # Generate the requested number of sample logs
        for _ in range(min(count, 100)):  # Limit to prevent abuse
            import random
            
            sample_log = {
                'timestamp': datetime.utcnow().isoformat(),
                'level': random.choice(['DEBUG', 'INFO', 'WARN', 'ERROR']),
                'service': random.choice(['demo-service', 'test-service', 'sample-service']),
                'message': f'Simulated log entry #{random.randint(1000, 9999)}',
                'request_id': f"sim_{random.randint(1000, 9999)}"
            }
            
            dashboard.add_log(sample_log, is_valid=True)
        
        return jsonify({'success': True, 'generated': count})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health_check():
    """Simple health check endpoint for monitoring."""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'json-log-dashboard'
    })

# Background log monitor (simulates real log processing integration)
def log_monitor():
    """
    Background thread that would integrate with the actual log processor.
    
    In a real deployment, this would connect to your JSONLogProcessor
    and receive notifications about processed logs. For this demo,
    it occasionally generates sample logs to keep the dashboard active.
    """
    while True:
        try:
            # In a real system, this would receive logs from the processor
            # For demo purposes, occasionally add a sample log
            time.sleep(5 + random.random() * 10)  # Wait 5-15 seconds
            
            # Generate a sample log occasionally
            if random.random() < 0.3:  # 30% chance every interval
                sample_log = {
                    'timestamp': datetime.utcnow().isoformat(),
                    'level': random.choice(['INFO', 'WARN', 'ERROR']),
                    'service': 'background-monitor',
                    'message': 'Periodic system check',
                    'request_id': f"bg_{int(time.time())}"
                }
                dashboard.add_log(sample_log, is_valid=True)
                
        except Exception as e:
            print(f"Error in log monitor: {e}")
            time.sleep(5)

if __name__ == '__main__':
    # Start the background log monitor
    monitor_thread = threading.Thread(target=log_monitor, daemon=True)
    monitor_thread.start()
    
    print("🌐 Starting JSON Log Dashboard on http://localhost:5000")
    print("📊 Dashboard features:")
    print("   - Real-time log monitoring")
    print("   - Validation statistics")
    print("   - Service activity tracking")
    print("   - Log level distribution")
    
    # Run the Flask development server
    app.run(host='0.0.0.0', port=5000, debug=True)