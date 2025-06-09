from flask import Flask, render_template, jsonify, request
import json
import asyncio
from typing import Dict
import threading
import time

class AntiEntropyDashboard:
    """Web dashboard for monitoring anti-entropy operations"""
    
    def __init__(self, coordinator, nodes: Dict):
        self.app = Flask(__name__)
        self.coordinator = coordinator
        self.nodes = nodes
        self.setup_routes()
        
    def setup_routes(self):
        """Setup Flask routes"""
        
        @self.app.route('/')
        def index():
            return render_template('dashboard.html')
        
        @self.app.route('/api/metrics')
        def get_metrics():
            """Get current anti-entropy metrics"""
            return jsonify(self.coordinator.get_metrics())
        
        @self.app.route('/api/repair-queue')
        def get_repair_queue():
            """Get current repair queue status"""
            return jsonify(self.coordinator.get_repair_queue_status())
        
        @self.app.route('/api/nodes')
        def get_nodes():
            """Get node statistics"""
            node_stats = {}
            for node_id, node in self.nodes.items():
                node_stats[node_id] = node.get_stats()
            return jsonify(node_stats)
        
        @self.app.route('/api/trigger-scan', methods=['POST'])
        def trigger_scan():
            """Trigger immediate anti-entropy scan"""
            try:
                # Use threading to avoid blocking Flask
                def run_scan():
                    loop = asyncio.new_event_loop()
                    asyncio.set_event_loop(loop)
                    loop.run_until_complete(self.coordinator.trigger_immediate_scan())
                    loop.close()
                
                scan_thread = threading.Thread(target=run_scan)
                scan_thread.start()
                
                return jsonify({'success': True, 'message': 'Scan triggered'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/inject-inconsistency', methods=['POST'])
        def inject_inconsistency():
            """Inject artificial inconsistency for testing"""
            try:
                data = request.get_json()
                node_id = data.get('node_id')
                key = data.get('key', f'test_key_{int(time.time())}')
                value = data.get('value', f'inconsistent_value_{int(time.time())}')
                
                if node_id in self.nodes:
                    # Use threading for async operation
                    def inject():
                        loop = asyncio.new_event_loop()
                        asyncio.set_event_loop(loop)
                        loop.run_until_complete(self.nodes[node_id].put_entry(key, value))
                        loop.close()
                    
                    inject_thread = threading.Thread(target=inject)
                    inject_thread.start()
                    
                    return jsonify({
                        'success': True, 
                        'message': f'Inconsistency injected on {node_id}',
                        'key': key,
                        'value': value
                    })
                else:
                    return jsonify({'success': False, 'error': 'Node not found'})
                    
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
    
    def run(self, host='127.0.0.1', port=5000, debug=False):
        """Run the dashboard"""
        self.app.run(host=host, port=port, debug=debug)
