import asyncio
import aiohttp
from aiohttp import web, WSMsgType
import json
import time

class MonitoringDashboard:
    def __init__(self):
        self.app = web.Application()
        self.websockets = set()
        self.setup_routes()
        
    def setup_routes(self):
        self.app.router.add_get('/', self.dashboard_handler)
        self.app.router.add_get('/ws', self.websocket_handler)
        self.app.router.add_static('/static', 'static', name='static')
        
    async def dashboard_handler(self, request):
        """Serve the monitoring dashboard"""
        html_content = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Batch API Operations Monitor</title>
            <style>
                body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
                .container { max-width: 1200px; margin: 0 auto; }
                .header { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
                .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
                .metric-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
                .metric-value { font-size: 24px; font-weight: bold; color: #2563eb; }
                .metric-label { color: #6b7280; margin-top: 5px; }
                .status-indicator { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 8px; }
                .status-healthy { background-color: #10b981; }
                .status-warning { background-color: #f59e0b; }
                .operations-list { max-height: 400px; overflow-y: auto; }
                .operation-item { padding: 8px; border-bottom: 1px solid #e5e7eb; font-family: monospace; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🚀 Batch API Operations Monitor</h1>
                    <p><span class="status-indicator status-healthy"></span>System Status: <span id="system-status">Healthy</span></p>
                </div>
                
                <div class="metrics-grid">
                    <div class="metric-card">
                        <div class="metric-value" id="total-batches">0</div>
                        <div class="metric-label">Total Batches Processed</div>
                    </div>
                    
                    <div class="metric-card">
                        <div class="metric-value" id="total-logs">0</div>
                        <div class="metric-label">Total Logs Processed</div>
                    </div>
                    
                    <div class="metric-card">
                        <div class="metric-value" id="throughput">0.0</div>
                        <div class="metric-label">Throughput (logs/sec)</div>
                    </div>
                    
                    <div class="metric-card">
                        <div class="metric-value" id="success-rate">0%</div>
                        <div class="metric-label">Success Rate</div>
                    </div>
                    
                    <div class="metric-card">
                        <div class="metric-value" id="avg-batch-size">0</div>
                        <div class="metric-label">Average Batch Size</div>
                    </div>
                    
                    <div class="metric-card">
                        <div class="metric-value" id="avg-processing-time">0.0s</div>
                        <div class="metric-label">Average Processing Time</div>
                    </div>
                </div>
                
                <div class="metric-card" style="margin-top: 20px;">
                    <h3>Recent Operations</h3>
                    <div id="operations-list" class="operations-list">
                        <div class="operation-item">Waiting for operations...</div>
                    </div>
                </div>
            </div>
            
            <script>
                const ws = new WebSocket('ws://localhost:8001/ws');
                
                ws.onmessage = function(event) {
                    const data = JSON.parse(event.data);
                    updateDashboard(data);
                };
                
                function updateDashboard(data) {
                    const stats = data.batch_stats;
                    const systemMetrics = data.system_metrics;
                    
                    document.getElementById('total-batches').textContent = stats.total_batches_processed;
                    document.getElementById('total-logs').textContent = stats.total_logs_processed.toLocaleString();
                    document.getElementById('throughput').textContent = stats.throughput_per_second.toFixed(1);
                    document.getElementById('success-rate').textContent = stats.success_rate.toFixed(1) + '%';
                    document.getElementById('avg-batch-size').textContent = Math.round(stats.average_batch_size);
                    document.getElementById('avg-processing-time').textContent = stats.average_processing_time.toFixed(3) + 's';
                    
                    // Update recent operations
                    const operationsList = document.getElementById('operations-list');
                    if (data.recent_operations && data.recent_operations.length > 0) {
                        operationsList.innerHTML = data.recent_operations.map(op => 
                            `<div class="operation-item">
                                ${new Date(op.timestamp * 1000).toLocaleTimeString()} - 
                                ${op.type.toUpperCase()}: ${op.batch_size} logs in ${op.processing_time.toFixed(3)}s
                            </div>`
                        ).join('');
                    }
                }
                
                // Connection status
                ws.onopen = function() {
                    document.getElementById('system-status').textContent = 'Connected';
                };
                
                ws.onclose = function() {
                    document.getElementById('system-status').textContent = 'Disconnected';
                };
            </script>
        </body>
        </html>
        """
        return web.Response(text=html_content, content_type='text/html')
    
    async def websocket_handler(self, request):
        """Handle WebSocket connections for real-time updates"""
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        
        self.websockets.add(ws)
        
        try:
            async for msg in ws:
                if msg.type == WSMsgType.TEXT:
                    if msg.data == 'close':
                        await ws.close()
                elif msg.type == WSMsgType.ERROR:
                    print(f'WebSocket error: {ws.exception()}')
        finally:
            self.websockets.discard(ws)
            
        return ws
    
    async def broadcast_metrics(self, metrics_data):
        """Broadcast metrics to all connected WebSockets"""
        if self.websockets:
            message = json.dumps(metrics_data)
            await asyncio.gather(
                *[ws.send_str(message) for ws in self.websockets.copy()],
                return_exceptions=True
            )
    
    async def start_metrics_broadcast(self):
        """Start periodic metrics broadcasting"""
        while True:
            try:
                # Fetch metrics from main API
                async with aiohttp.ClientSession() as session:
                    async with session.get('http://localhost:8000/api/v1/metrics/batch') as resp:
                        if resp.status == 200:
                            batch_stats = await resp.json()
                            
                            # Get current stats
                            async with session.get('http://localhost:8000/api/v1/health') as health_resp:
                                health_data = await health_resp.json() if health_resp.status == 200 else {}
                            
                            metrics_data = {
                                'batch_stats': batch_stats,
                                'system_metrics': {'cpu_percent': 0, 'memory_percent': 0},
                                'recent_operations': []
                            }
                            
                            await self.broadcast_metrics(metrics_data)
            except Exception as e:
                print(f"⚠️ Metrics broadcast error: {e}")
            
            await asyncio.sleep(2)  # Update every 2 seconds

async def run_dashboard():
    """Run the monitoring dashboard"""
    dashboard = MonitoringDashboard()
    
    # Start metrics broadcasting
    asyncio.create_task(dashboard.start_metrics_broadcast())
    
    # Start web server
    runner = web.AppRunner(dashboard.app)
    await runner.setup()
    site = web.TCPSite(runner, 'localhost', 8001)
    await site.start()
    
    print("📊 Monitoring Dashboard running on http://localhost:8001")
    
    # Keep running
    while True:
        await asyncio.sleep(1)

if __name__ == "__main__":
    asyncio.run(run_dashboard())
