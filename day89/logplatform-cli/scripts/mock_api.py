#!/usr/bin/env python3
"""Mock API server for testing CLI"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.parse
from datetime import datetime, timedelta

class MockAPIHandler(BaseHTTPRequestHandler):
    
    def do_GET(self):
        """Handle GET requests"""
        path = urllib.parse.urlparse(self.path).path
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        
        if path == '/logs/search':
            self._handle_log_search(query)
        elif path == '/alerts':
            self._handle_get_alerts()
        elif path == '/admin/health':
            self._handle_health_check()
        elif path == '/admin/stats':
            self._handle_platform_stats()
        elif path == '/admin/users':
            self._handle_get_users()
        else:
            self._send_error(404, 'Not Found')
    
    def do_POST(self):
        """Handle POST requests"""
        path = urllib.parse.urlparse(self.path).path
        
        if path == '/auth/login':
            self._handle_login()
        elif path == '/alerts':
            self._handle_create_alert()
        else:
            self._send_error(404, 'Not Found')
    
    def do_DELETE(self):
        """Handle DELETE requests"""
        path = urllib.parse.urlparse(self.path).path
        
        if path.startswith('/alerts/'):
            self._handle_delete_alert()
        else:
            self._send_error(404, 'Not Found')
    
    def _handle_login(self):
        """Handle authentication"""
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data.decode('utf-8'))
            username = data.get('username')
            password = data.get('password')
            
            if username == 'demo' and password == 'demo':
                response = {
                    'access_token': 'demo_token_12345',
                    'expires_at': (datetime.now() + timedelta(hours=24)).isoformat()
                }
                self._send_json_response(response)
            else:
                self._send_error(401, 'Invalid credentials')
        except:
            self._send_error(400, 'Invalid JSON')
    
    def _handle_log_search(self, query):
        """Handle log search"""
        # Generate sample logs
        logs = []
        for i in range(10):
            logs.append({
                'id': i + 1,
                'timestamp': (datetime.now() - timedelta(minutes=i)).isoformat(),
                'level': ['INFO', 'WARN', 'ERROR'][i % 3],
                'service': ['web-api', 'database', 'cache'][i % 3],
                'message': f'Sample log message {i + 1}'
            })
        
        response = {
            'logs': logs,
            'total': len(logs)
        }
        self._send_json_response(response)
    
    def _handle_get_alerts(self):
        """Handle get alerts"""
        alerts = [
            {
                'id': 1,
                'name': 'High Error Rate',
                'status': 'active',
                'severity': 'high',
                'created_at': datetime.now().isoformat()
            },
            {
                'id': 2,
                'name': 'Slow Response Time',
                'status': 'resolved',
                'severity': 'medium',
                'created_at': (datetime.now() - timedelta(hours=2)).isoformat()
            }
        ]
        
        response = {'alerts': alerts}
        self._send_json_response(response)
    
    def _handle_create_alert(self):
        """Handle create alert"""
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data.decode('utf-8'))
            response = {
                'id': 123,
                'name': data.get('name'),
                'query': data.get('query'),
                'threshold': data.get('threshold'),
                'severity': data.get('severity'),
                'status': 'active',
                'created_at': datetime.now().isoformat()
            }
            self._send_json_response(response, 201)
        except:
            self._send_error(400, 'Invalid JSON')
    
    def _handle_delete_alert(self):
        """Handle delete alert"""
        self._send_json_response({'message': 'Alert deleted successfully'})
    
    def _handle_health_check(self):
        """Handle health check"""
        response = {
            'database': {'status': 'healthy', 'details': 'Connection OK'},
            'storage': {'status': 'healthy', 'details': 'Disk usage: 45%'},
            'api': {'status': 'healthy', 'details': 'Response time: 23ms'}
        }
        self._send_json_response(response)
    
    def _handle_platform_stats(self):
        """Handle platform stats"""
        response = {
            'total_logs': 1234567,
            'logs_today': 45678,
            'active_services': 12,
            'storage_used': '2.3 TB',
            'active_alerts': 3
        }
        self._send_json_response(response)
    
    def _handle_get_users(self):
        """Handle get users"""
        users = [
            {
                'id': 1,
                'username': 'admin',
                'role': 'admin',
                'last_active': datetime.now().isoformat()
            },
            {
                'id': 2,
                'username': 'demo',
                'role': 'user',
                'last_active': (datetime.now() - timedelta(minutes=30)).isoformat()
            }
        ]
        
        response = {'users': users}
        self._send_json_response(response)
    
    def _send_json_response(self, data, status=200):
        """Send JSON response"""
        response = json.dumps(data, indent=2)
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response)))
        self.end_headers()
        self.wfile.write(response.encode('utf-8'))
    
    def _send_error(self, status, message):
        """Send error response"""
        response = json.dumps({'error': message})
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response)))
        self.end_headers()
        self.wfile.write(response.encode('utf-8'))
    
    def log_message(self, format, *args):
        """Override to reduce log verbosity"""
        pass

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8000), MockAPIHandler)
    print("Mock API server running on http://0.0.0.0:8000")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        server.shutdown()
