import os
import json
import hashlib
import threading
import time
from datetime import datetime
from flask import Flask, request, jsonify
import psutil

class StorageNode:
    def __init__(self, node_id, port, storage_path):
        self.node_id = node_id
        self.port = port
        self.storage_path = storage_path
        self.is_healthy = True
        self.replication_peers = []
        self.stats = {
            'writes': 0,
            'reads': 0,
            'replications_received': 0,
            'start_time': datetime.now()
        }
        
        # Ensure storage directory exists
        os.makedirs(storage_path, exist_ok=True)
        
        # Initialize Flask app
        self.app = Flask(f"storage_node_{node_id}")
        self._setup_routes()
    
    def _setup_routes(self):
        """Setup Flask routes for the storage node"""
        
        @self.app.route('/health', methods=['GET'])
        def health_check():
            return jsonify({
                'status': 'healthy' if self.is_healthy else 'unhealthy',
                'node_id': self.node_id,
                'uptime': str(datetime.now() - self.stats['start_time']),
                'stats': self.stats
            })
        
        @self.app.route('/write', methods=['POST'])
        def write_log():
            try:
                data = request.get_json()
                file_path = self.write_log_data(data)
                return jsonify({'success': True, 'file_path': file_path})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/read/<path:file_path>', methods=['GET'])
        def read_log(file_path):
            try:
                data = self.read_log_data(file_path)
                if data:
                    return jsonify({'success': True, 'data': data})
                else:
                    return jsonify({'success': False, 'error': 'File not found'}), 404
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/replicate', methods=['POST'])
        def receive_replication():
            try:
                data = request.get_json()
                file_path = data['file_path']
                file_data = data['data']
                
                # Store replicated file
                full_path = os.path.join(self.storage_path, os.path.basename(file_path))
                with open(full_path, 'w') as f:
                    json.dump(file_data, f)
                
                self.stats['replications_received'] += 1
                return jsonify({'success': True, 'node_id': self.node_id})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/stats', methods=['GET'])
        def get_stats():
            return jsonify({
                'node_id': self.node_id,
                'stats': self.stats,
                'disk_usage': self._get_disk_usage(),
                'memory_usage': self._get_memory_usage()
            })
    
    def write_log_data(self, log_data):
        """Write log data to local storage"""
        timestamp = datetime.now().isoformat()
        file_name = f"log_{timestamp.replace(':', '-').replace('.', '_')}.json"
        file_path = os.path.join(self.storage_path, file_name)
        
        enriched_data = {
            'timestamp': timestamp,
            'node_id': self.node_id,
            'original_data': log_data,
            'file_path': file_name,
            'checksum': self._calculate_checksum(log_data)
        }
        
        with open(file_path, 'w') as f:
            json.dump(enriched_data, f, indent=2)
        
        self.stats['writes'] += 1
        return file_name
    
    def read_log_data(self, file_path):
        """Read log data from local storage"""
        full_path = os.path.join(self.storage_path, file_path)
        if os.path.exists(full_path):
            with open(full_path, 'r') as f:
                self.stats['reads'] += 1
                return json.load(f)
        return None
    
    def _calculate_checksum(self, data):
        """Calculate MD5 checksum of data"""
        return hashlib.md5(json.dumps(data, sort_keys=True).encode()).hexdigest()
    
    def _get_disk_usage(self):
        """Get disk usage statistics"""
        usage = psutil.disk_usage(self.storage_path)
        return {
            'total': usage.total,
            'used': usage.used,
            'free': usage.free,
            'percent': (usage.used / usage.total) * 100
        }
    
    def _get_memory_usage(self):
        """Get memory usage statistics"""
        memory = psutil.virtual_memory()
        return {
            'total': memory.total,
            'used': memory.used,
            'percent': memory.percent
        }
    
    def start_server(self):
        """Start the Flask server"""
        print(f"Starting Storage Node {self.node_id} on port {self.port}")
        self.app.run(host='0.0.0.0', port=self.port, debug=False, threaded=True)
