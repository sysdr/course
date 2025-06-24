import asyncio
import json
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
import uvicorn
from src.consumers.consumer_manager import ConsumerManager
import structlog

logger = structlog.get_logger()

app = FastAPI(title="Log Consumer Dashboard", version="1.0.0")

# Global consumer manager instance
consumer_manager = None

@app.get("/", response_class=HTMLResponse)
async def dashboard():
    """Main dashboard page"""
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Log Consumer Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .container { max-width: 1200px; margin: 0 auto; }
            .card { background: white; padding: 20px; margin: 20px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .metric { display: inline-block; margin: 10px 20px; padding: 10px; background: #e3f2fd; border-radius: 4px; }
            .metric-value { font-size: 24px; font-weight: bold; color: #1976d2; }
            .metric-label { font-size: 12px; color: #666; }
            .consumer { margin: 10px 0; padding: 10px; background: #f8f9fa; border-radius: 4px; }
            .refresh-btn { background: #4caf50; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
            .endpoint-table { width: 100%; border-collapse: collapse; }
            .endpoint-table th, .endpoint-table td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
            .endpoint-table th { background-color: #f2f2f2; }
        </style>
        <script>
            async function refreshStats() {
                try {
                    const response = await fetch('/stats');
                    const stats = await response.json();
                    updateDashboard(stats);
                } catch (error) {
                    console.error('Error fetching stats:', error);
                }
            }
            
            function updateDashboard(stats) {
                document.getElementById('total-processed').textContent = stats.total_processed;
                document.getElementById('total-errors').textContent = stats.total_errors;
                document.getElementById('success-rate').textContent = 
                    ((stats.total_processed / Math.max(1, stats.total_processed + stats.total_errors)) * 100).toFixed(1) + '%';
                
                // Update consumer list
                const consumerList = document.getElementById('consumer-list');
                consumerList.innerHTML = '';
                stats.consumers.forEach(consumer => {
                    const div = document.createElement('div');
                    div.className = 'consumer';
                    div.innerHTML = `
                        <strong>${consumer.id}</strong> - 
                        Processed: ${consumer.processed_count}, 
                        Errors: ${consumer.error_count}, 
                        Success Rate: ${(consumer.success_rate * 100).toFixed(1)}%
                    `;
                    consumerList.appendChild(div);
                });
                
                // Update endpoint metrics
                const metrics = stats.processor_metrics;
                if (metrics && metrics.endpoints) {
                    updateEndpointTable(metrics.endpoints);
                }
            }
            
            function updateEndpointTable(endpoints) {
                const tbody = document.getElementById('endpoint-tbody');
                tbody.innerHTML = '';
                
                Object.entries(endpoints).forEach(([endpoint, data]) => {
                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td>${endpoint}</td>
                        <td>${data.count}</td>
                        <td>${data.avg_response_time ? data.avg_response_time.toFixed(2) + 'ms' : 'N/A'}</td>
                        <td>${data.errors}</td>
                        <td>${data.error_rate ? (data.error_rate * 100).toFixed(1) + '%' : '0%'}</td>
                    `;
                    tbody.appendChild(row);
                });
            }
            
            // Auto-refresh every 5 seconds
            setInterval(refreshStats, 5000);
            
            // Initial load
            window.onload = refreshStats;
        </script>
    </head>
    <body>
        <div class="container">
            <h1>Log Consumer Dashboard</h1>
            
            <div class="card">
                <h2>Overall Statistics</h2>
                <div class="metric">
                    <div class="metric-value" id="total-processed">0</div>
                    <div class="metric-label">Total Processed</div>
                </div>
                <div class="metric">
                    <div class="metric-value" id="total-errors">0</div>
                    <div class="metric-label">Total Errors</div>
                </div>
                <div class="metric">
                    <div class="metric-value" id="success-rate">0%</div>
                    <div class="metric-label">Success Rate</div>
                </div>
                <button class="refresh-btn" onclick="refreshStats()">Refresh</button>
            </div>
            
            <div class="card">
                <h2>Consumer Status</h2>
                <div id="consumer-list"></div>
            </div>
            
            <div class="card">
                <h2>Endpoint Metrics</h2>
                <table class="endpoint-table">
                    <thead>
                        <tr>
                            <th>Endpoint</th>
                            <th>Requests</th>
                            <th>Avg Response Time</th>
                            <th>Errors</th>
                            <th>Error Rate</th>
                        </tr>
                    </thead>
                    <tbody id="endpoint-tbody"></tbody>
                </table>
            </div>
        </div>
    </body>
    </html>
    """
    return html

@app.get("/stats")
async def get_stats():
    """Get consumer statistics"""
    if not consumer_manager:
        raise HTTPException(status_code=503, detail="Consumer manager not initialized")
    
    return consumer_manager.get_stats()

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": asyncio.get_event_loop().time()}

def set_consumer_manager(manager: ConsumerManager):
    """Set the global consumer manager instance"""
    global consumer_manager
    consumer_manager = manager
