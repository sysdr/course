import asyncio
import json
from aiohttp import web, WSMsgType
import aiohttp_cors
from datetime import datetime
import logging

class PerformanceDashboard:
    """Web-based performance monitoring dashboard"""
    
    def __init__(self, aggregator, analyzer, config):
        self.aggregator = aggregator
        self.analyzer = analyzer
        self.config = config
        self.websockets = set()
        self.app = web.Application()
        self.setup_routes()
        
    def setup_routes(self):
        """Setup web routes"""
        self.app.router.add_get('/', self.index)
        self.app.router.add_get('/api/metrics', self.get_metrics)
        self.app.router.add_get('/api/report', self.get_report)
        self.app.router.add_get('/ws', self.websocket_handler)
        self.app.router.add_static('/static/', path='src/dashboard/static', name='static')
        
        # Setup CORS
        cors = aiohttp_cors.setup(self.app, defaults={
            "*": aiohttp_cors.ResourceOptions(
                allow_credentials=True,
                expose_headers="*",
                allow_headers="*",
                allow_methods="*"
            )
        })
        
        for route in list(self.app.router.routes()):
            cors.add(route)
    
    async def index(self, request):
        """Serve dashboard HTML"""
        html = """
<!DOCTYPE html>
<html>
<head>
    <title>Cluster Performance Dashboard</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .metric-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .alert { padding: 10px; margin: 10px 0; border-radius: 4px; }
        .alert-critical { background: #f8d7da; border-left: 4px solid #dc3545; }
        .alert-warning { background: #fff3cd; border-left: 4px solid #ffc107; }
        .status-healthy { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-critical { color: #dc3545; }
        .refresh-button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }
        .recommendations { background: #e7f3ff; padding: 15px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Cluster Performance Dashboard</h1>
        <p>Real-time monitoring for distributed log storage cluster</p>
        <button class="refresh-button" onclick="refreshData()">Refresh Data</button>
        <span id="last-updated" style="float: right;"></span>
    </div>
    
    <div id="cluster-status" class="metric-card">
        <h2>Cluster Status</h2>
        <div id="status-content">Loading...</div>
    </div>
    
    <div class="metric-grid">
        <div class="metric-card">
            <h3>CPU Usage</h3>
            <div id="cpu-chart"></div>
        </div>
        
        <div class="metric-card">
            <h3>Memory Usage</h3>
            <div id="memory-chart"></div>
        </div>
        
        <div class="metric-card">
            <h3>Throughput</h3>
            <div id="throughput-chart"></div>
        </div>
        
        <div class="metric-card">
            <h3>Latency</h3>
            <div id="latency-chart"></div>
        </div>
    </div>
    
    <div id="alerts-section" class="metric-card">
        <h2>Active Alerts</h2>
        <div id="alerts-content">No alerts</div>
    </div>
    
    <div id="recommendations-section" class="recommendations">
        <h2>Performance Recommendations</h2>
        <div id="recommendations-content">No recommendations</div>
    </div>

    <script>
        let ws = null;
        
        function connectWebSocket() {
            ws = new WebSocket('ws://localhost:8080/ws');
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                updateDashboard(data);
            };
            ws.onclose = function() {
                setTimeout(connectWebSocket, 5000);
            };
        }
        
        function updateDashboard(data) {
            updateClusterStatus(data);
            updateCharts(data);
            updateAlerts(data);
            updateRecommendations(data);
            document.getElementById('last-updated').textContent = 
                'Last updated: ' + new Date().toLocaleTimeString();
        }
        
        function updateClusterStatus(data) {
            const status = data.cluster_health || 'unknown';
            const summary = data.performance_summary || {};
            
            let statusClass = 'status-healthy';
            if (status === 'warning') statusClass = 'status-warning';
            if (status === 'critical') statusClass = 'status-critical';
            
            document.getElementById('status-content').innerHTML = `
                <h3 class="${statusClass}">Status: ${status.toUpperCase()}</h3>
                <p>Active Nodes: ${summary.active_nodes || 0}</p>
                <p>Performance Score: ${(summary.performance_score || 0).toFixed(1)}/100</p>
                <p>Total Throughput: ${(summary.total_throughput || 0).toFixed(1)} ops/sec</p>
            `;
        }
        
        function updateCharts(data) {
            const nodes = data.detailed_metrics?.nodes || {};
            
            // CPU Chart
            const cpuData = Object.entries(nodes).map(([nodeId, metrics]) => ({
                x: [nodeId],
                y: [metrics.cpu_usage_total?.avg || 0],
                type: 'bar',
                name: nodeId
            }));
            
            Plotly.newPlot('cpu-chart', cpuData, {
                title: 'CPU Usage by Node (%)',
                yaxis: { range: [0, 100] }
            });
            
            // Memory Chart
            const memoryData = Object.entries(nodes).map(([nodeId, metrics]) => ({
                x: [nodeId],
                y: [metrics.memory_usage?.avg || 0],
                type: 'bar',
                name: nodeId
            }));
            
            Plotly.newPlot('memory-chart', memoryData, {
                title: 'Memory Usage by Node (%)',
                yaxis: { range: [0, 100] }
            });
            
            // Throughput Chart
            const throughputData = Object.entries(nodes).map(([nodeId, metrics]) => ({
                x: [nodeId],
                y: [metrics.operations_per_second?.avg || 0],
                type: 'bar',
                name: nodeId
            }));
            
            Plotly.newPlot('throughput-chart', throughputData, {
                title: 'Throughput by Node (ops/sec)'
            });
            
            // Latency Chart
            const latencyData = Object.entries(nodes).map(([nodeId, metrics]) => ({
                x: [nodeId],
                y: [metrics.write_latency_avg?.avg || 0],
                type: 'bar',
                name: nodeId
            }));
            
            Plotly.newPlot('latency-chart', latencyData, {
                title: 'Write Latency by Node (ms)'
            });
        }
        
        function updateAlerts(data) {
            const alerts = data.alerts || [];
            let alertsHtml = '';
            
            if (alerts.length === 0) {
                alertsHtml = '<p>No active alerts</p>';
            } else {
                alerts.forEach(alert => {
                    const alertClass = alert.level === 'critical' ? 'alert-critical' : 'alert-warning';
                    alertsHtml += `
                        <div class="alert ${alertClass}">
                            <strong>${alert.node_id}</strong>: ${alert.message}
                            <small>(${alert.current_value.toFixed(1)} vs threshold ${alert.threshold.toFixed(1)})</small>
                        </div>
                    `;
                });
            }
            
            document.getElementById('alerts-content').innerHTML = alertsHtml;
        }
        
        function updateRecommendations(data) {
            const recommendations = data.recommendations || [];
            let recHtml = '';
            
            if (recommendations.length === 0) {
                recHtml = '<p>No recommendations at this time</p>';
            } else {
                recHtml = '<ul>';
                recommendations.forEach(rec => {
                    recHtml += `<li>${rec}</li>`;
                });
                recHtml += '</ul>';
            }
            
            document.getElementById('recommendations-content').innerHTML = recHtml;
        }
        
        function refreshData() {
            fetch('/api/report')
                .then(response => response.json())
                .then(data => updateDashboard(data))
                .catch(error => console.error('Error fetching data:', error));
        }
        
        // Initialize
        connectWebSocket();
        refreshData();
        
        // Auto-refresh every 30 seconds
        setInterval(refreshData, 30000);
    </script>
</body>
</html>
        """
        return web.Response(text=html, content_type='text/html')
    
    async def get_metrics(self, request):
        """API endpoint for metrics"""
        try:
            metrics = await self.aggregator.aggregate_cluster_metrics()
            return web.json_response(metrics)
        except Exception as e:
            return web.json_response({'error': str(e)}, status=500)
    
    async def get_report(self, request):
        """API endpoint for performance report"""
        try:
            metrics = await self.aggregator.aggregate_cluster_metrics()
            report = await self.analyzer.generate_performance_report(metrics)
            return web.json_response(report)
        except Exception as e:
            return web.json_response({'error': str(e)}, status=500)
    
    async def websocket_handler(self, request):
        """WebSocket handler for real-time updates"""
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        
        self.websockets.add(ws)
        
        try:
            async for msg in ws:
                if msg.type == WSMsgType.ERROR:
                    print(f'WebSocket error: {ws.exception()}')
        finally:
            self.websockets.discard(ws)
        
        return ws
    
    async def broadcast_update(self, data):
        """Broadcast updates to all connected WebSocket clients"""
        if not self.websockets:
            return
        
        message = json.dumps(data)
        disconnected = set()
        
        for ws in self.websockets:
            try:
                await ws.send_str(message)
            except ConnectionResetError:
                disconnected.add(ws)
        
        # Clean up disconnected WebSockets
        self.websockets -= disconnected
    
    async def start_server(self):
        """Start the dashboard web server"""
        runner = web.AppRunner(self.app)
        await runner.setup()
        
        host = self.config.get('dashboard', {}).get('host', '0.0.0.0')
        port = self.config.get('dashboard', {}).get('port', 8080)
        
        site = web.TCPSite(runner, host, port)
        await site.start()
        
        print(f"Dashboard started at http://{host}:{port}")
        
        # Start periodic updates
        asyncio.create_task(self._periodic_updates())
    
    async def _periodic_updates(self):
        """Send periodic updates to WebSocket clients"""
        while True:
            try:
                metrics = await self.aggregator.aggregate_cluster_metrics()
                report = await self.analyzer.generate_performance_report(metrics)
                await self.broadcast_update(report)
            except Exception as e:
                logging.error(f"Error in periodic updates: {e}")
            
            await asyncio.sleep(self.config.get('dashboard', {}).get('refresh_interval', 10))
