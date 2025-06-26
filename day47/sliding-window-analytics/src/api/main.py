from fastapi import FastAPI, WebSocket, WebSocketDisconnect, BackgroundTasks
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
import asyncio
import json
import time
from typing import Dict, List
import structlog
from contextlib import asynccontextmanager

from src.core.sliding_window import SlidingWindowManager, WindowResult
from src.utils.event_generator import LogEventGenerator
from config.settings import settings

logger = structlog.get_logger()

# Global sliding window manager
window_manager = SlidingWindowManager(
    window_size=settings.window_size_seconds,
    slide_interval=settings.slide_interval_seconds
)

# Event generator
event_generator = LogEventGenerator()

# WebSocket connections for real-time updates
active_connections: List[WebSocket] = []

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Start background event generation
    task = asyncio.create_task(generate_events_background())
    yield
    task.cancel()

app = FastAPI(title="Sliding Window Analytics", lifespan=lifespan)

async def generate_events_background():
    """Background task to generate continuous events"""
    async for event in event_generator.generate_continuous_events(events_per_second=20):
        # Add to sliding window
        window_manager.add_metric(
            metric_name=event['metric'],
            value=event['value'],
            metadata={k: v for k, v in event.items() if k not in ['metric', 'value']}
        )
        
        # Broadcast to WebSocket clients
        if active_connections:
            current_stats = window_manager.get_all_current_stats()
            message = {
                'type': 'stats_update',
                'data': {
                    metric: {
                        'average': result.average,
                        'count': result.count,
                        'min': result.min_value,
                        'max': result.max_value,
                        'std_dev': result.std_dev,
                        'timestamp': time.time()
                    }
                    for metric, result in current_stats.items()
                }
            }
            
            # Send to all connected clients
            disconnected = []
            for connection in active_connections:
                try:
                    await connection.send_text(json.dumps(message))
                except:
                    disconnected.append(connection)
            
            # Remove disconnected clients
            for conn in disconnected:
                active_connections.remove(conn)

@app.get("/")
async def get_dashboard():
    """Serve the dashboard HTML"""
    return HTMLResponse(content="""
<!DOCTYPE html>
<html>
<head>
    <title>Sliding Window Analytics Dashboard</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; color: #1e40af; margin-bottom: 30px; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric-title { font-size: 18px; font-weight: bold; color: #374151; margin-bottom: 10px; }
        .metric-value { font-size: 24px; font-weight: bold; color: #1e40af; }
        .metric-stats { margin-top: 10px; font-size: 12px; color: #6b7280; }
        .chart-container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); height: 400px; }
        .status { padding: 10px; background: #dcfce7; border-radius: 4px; margin-bottom: 20px; }
        .status.error { background: #fecaca; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔄 Sliding Window Analytics Dashboard</h1>
            <p>Real-time moving averages with 30-second sliding windows</p>
        </div>
        
        <div id="status" class="status">
            Connecting to real-time data stream...
        </div>
        
        <div class="metrics-grid" id="metrics-grid">
            <!-- Metrics will be populated here -->
        </div>
        
        <div class="chart-container">
            <div id="time-series-chart"></div>
        </div>
    </div>

    <script>
        const ws = new WebSocket(`ws://${window.location.host}/ws`);
        const timeSeriesData = {
            response_time_ms: { x: [], y: [], name: 'Response Time (ms)', line: {color: '#3b82f6'} },
            requests_per_second: { x: [], y: [], name: 'Requests/sec', line: {color: '#10b981'} },
            error_rate_percent: { x: [], y: [], name: 'Error Rate (%)', line: {color: '#ef4444'} }
        };
        
        ws.onopen = function(event) {
            document.getElementById('status').innerHTML = '✅ Connected to real-time data stream';
            document.getElementById('status').className = 'status';
        };
        
        ws.onclose = function(event) {
            document.getElementById('status').innerHTML = '❌ Disconnected from data stream';
            document.getElementById('status').className = 'status error';
        };
        
        ws.onmessage = function(event) {
            const message = JSON.parse(event.data);
            if (message.type === 'stats_update') {
                updateMetricsDisplay(message.data);
                updateTimeSeriesChart(message.data);
            }
        };
        
        function updateMetricsDisplay(data) {
            const grid = document.getElementById('metrics-grid');
            grid.innerHTML = '';
            
            Object.entries(data).forEach(([metric, stats]) => {
                const card = document.createElement('div');
                card.className = 'metric-card';
                
                const title = metric.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
                const unit = metric.includes('time') ? 'ms' : 
                           metric.includes('rate') ? '%' : 
                           metric.includes('requests') ? '/sec' : '';
                
                card.innerHTML = `
                    <div class="metric-title">${title}</div>
                    <div class="metric-value">${stats.average.toFixed(2)} ${unit}</div>
                    <div class="metric-stats">
                        Count: ${stats.count} | Min: ${stats.min.toFixed(1)} | Max: ${stats.max.toFixed(1)} | StdDev: ${stats.std_dev.toFixed(2)}
                    </div>
                `;
                
                grid.appendChild(card);
            });
        }
        
        function updateTimeSeriesChart(data) {
            const now = new Date();
            
            Object.entries(data).forEach(([metric, stats]) => {
                if (timeSeriesData[metric]) {
                    timeSeriesData[metric].x.push(now);
                    timeSeriesData[metric].y.push(stats.average);
                    
                    // Keep only last 50 points
                    if (timeSeriesData[metric].x.length > 50) {
                        timeSeriesData[metric].x.shift();
                        timeSeriesData[metric].y.shift();
                    }
                }
            });
            
            const traces = Object.values(timeSeriesData).filter(trace => trace.x.length > 0);
            
            Plotly.newPlot('time-series-chart', traces, {
                title: 'Real-time Sliding Window Trends',
                xaxis: { title: 'Time' },
                yaxis: { title: 'Value' },
                margin: { t: 40 }
            });
        }
        
        // Initialize empty chart
        Plotly.newPlot('time-series-chart', [], {
            title: 'Real-time Sliding Window Trends',
            xaxis: { title: 'Time' },
            yaxis: { title: 'Value' }
        });
    </script>
</body>
</html>
    """)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        active_connections.remove(websocket)

@app.get("/api/stats")
async def get_current_stats():
    """Get current sliding window statistics"""
    return window_manager.get_all_current_stats()

@app.post("/api/metric")
async def add_metric(metric_name: str, value: float):
    """Manually add a metric value"""
    window_manager.add_metric(metric_name, value)
    return {"status": "added", "metric": metric_name, "value": value}

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "active_windows": len(window_manager.windows),
        "active_connections": len(active_connections),
        "uptime": time.time()
    }
