import asyncio
import json
import time
from datetime import datetime
from typing import Dict, Any
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import structlog

from src.stream.processor import StreamProcessor
from src.index.manager import IndexManager
from src.search.interface import SearchInterface

logger = structlog.get_logger()

class WebInterface:
    def __init__(self):
        self.app = FastAPI(title="Real-Time Log Indexing System")
        self.stream_processor = StreamProcessor()
        self.index_manager = IndexManager()
        self.search_interface = None
        self.websocket_connections = set()
        self.indexing_task = None
        self.setup_routes()
        
    def setup_routes(self):
        @self.app.on_event("startup")
        async def startup():
            await self.stream_processor.connect()
            await self.index_manager.initialize()
            self.search_interface = SearchInterface(self.index_manager)
            
            # Start background indexing task
            self.indexing_task = asyncio.create_task(self.run_indexing())
            
        @self.app.on_event("shutdown")
        async def shutdown():
            if self.indexing_task:
                self.indexing_task.cancel()
            await self.stream_processor.disconnect()
            
        @self.app.get("/", response_class=HTMLResponse)
        async def dashboard():
            return await self.get_dashboard_html()
            
        @self.app.get("/api/stats")
        async def get_stats():
            stats = {
                'timestamp': datetime.now().isoformat(),
                'stream_processor': self.stream_processor.get_stats(),
                'index_manager': self.index_manager.get_stats(),
                'search_interface': self.search_interface.get_stats() if self.search_interface else {}
            }
            return JSONResponse(stats)
            
        @self.app.post("/api/search")
        async def search_logs(request: Request):
            data = await request.json()
            query_text = data.get('query', '')
            filters = data.get('filters', {})
            limit = data.get('limit', 100)
            
            if not self.search_interface:
                return JSONResponse({'error': 'Search interface not ready'})
                
            results = await self.search_interface.search_logs(query_text, filters, limit)
            return JSONResponse(results)
            
        @self.app.get("/api/recent")
        async def get_recent():
            if not self.search_interface:
                return JSONResponse({'error': 'Search interface not ready'})
                
            recent_logs = await self.search_interface.get_recent_logs(50)
            return JSONResponse({'results': recent_logs})
            
        @self.app.post("/api/generate-sample")
        async def generate_sample(request: Request):
            data = {}
            try:
                data = await request.json()
            except Exception:
                data = {}
            count = int(data.get('count', 100))
            count = max(0, min(count, 50000))
            await self.stream_processor.generate_sample_logs(count)
            return JSONResponse({'message': f'Generated {count} sample logs'})
            
        @self.app.websocket("/ws")
        async def websocket_endpoint(websocket: WebSocket):
            await websocket.accept()
            self.websocket_connections.add(websocket)
            
            try:
                while True:
                    # Send periodic stats updates
                    stats = await self.app.routes[2].endpoint()  # get_stats
                    await websocket.send_json(stats.body.decode())
                    await asyncio.sleep(2)
            except WebSocketDisconnect:
                self.websocket_connections.remove(websocket)
    
    async def run_indexing(self):
        """Background task for continuous indexing"""
        try:
            async for log_entry in self.stream_processor.consume_log_stream():
                await self.index_manager.add_document(log_entry)
                
                # Notify WebSocket clients of new indexed document
                if self.websocket_connections:
                    notification = {
                        'type': 'new_document',
                        'document': log_entry.to_dict(),
                        'timestamp': datetime.now().isoformat()
                    }
                    
                    # Broadcast to all connected clients
                    disconnected = set()
                    for ws in self.websocket_connections:
                        try:
                            await ws.send_json(notification)
                        except:
                            disconnected.add(ws)
                    
                    # Remove disconnected clients
                    self.websocket_connections -= disconnected
                    
        except Exception as e:
            logger.error("indexing_task_error", error=str(e))
    
    async def get_dashboard_html(self) -> str:
        """Generate dashboard HTML with Google Cloud Skills Boost styling"""
        return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Real-Time Log Indexing System</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Google Sans', 'Roboto', sans-serif;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            color: #202124;
            line-height: 1.6;
        }
        
        .header {
            background: #fff;
            padding: 1rem 2rem;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            border-bottom: 3px solid #4285f4;
        }
        
        .header h1 {
            color: #4285f4;
            font-size: 1.8rem;
            font-weight: 500;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .header .status {
            background: #34a853;
            color: white;
            padding: 4px 12px;
            border-radius: 16px;
            font-size: 0.8rem;
            font-weight: 500;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 2rem;
            display: grid;
            grid-template-columns: 1fr 1fr;
            grid-template-rows: auto auto auto;
            gap: 2rem;
        }
        
        .card {
            background: #fff;
            border-radius: 8px;
            padding: 1.5rem;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            border: 1px solid #e0e0e0;
        }
        
        .card h2 {
            color: #1a73e8;
            font-size: 1.2rem;
            font-weight: 500;
            margin-bottom: 1rem;
            padding-bottom: 0.5rem;
            border-bottom: 2px solid #e8f0fe;
        }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }
        
        .metric {
            text-align: center;
            padding: 1rem;
            background: #f8f9fa;
            border-radius: 6px;
            border-left: 4px solid #4285f4;
        }
        
        .metric-value {
            font-size: 2rem;
            font-weight: 600;
            color: #1a73e8;
            display: block;
        }
        
        .metric-label {
            font-size: 0.9rem;
            color: #5f6368;
            margin-top: 0.5rem;
        }
        
        .search-section {
            grid-column: 1 / -1;
        }
        
        .search-form {
            display: flex;
            gap: 1rem;
            margin-bottom: 1.5rem;
            align-items: end;
        }
        
        .form-group {
            flex: 1;
        }
        
        .form-group label {
            display: block;
            color: #5f6368;
            font-size: 0.9rem;
            margin-bottom: 0.5rem;
            font-weight: 500;
        }
        
        .form-group input, .form-group select {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e0e0e0;
            border-radius: 6px;
            font-size: 1rem;
            transition: border-color 0.2s;
        }
        
        .form-group input:focus, .form-group select:focus {
            outline: none;
            border-color: #4285f4;
            box-shadow: 0 0 0 3px rgba(66, 133, 244, 0.1);
        }
        
        .btn {
            background: #1a73e8;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 6px;
            font-size: 1rem;
            font-weight: 500;
            cursor: pointer;
            transition: background-color 0.2s;
            white-space: nowrap;
        }
        
        .btn:hover {
            background: #174ea6;
        }
        
        .btn-secondary {
            background: #5f6368;
        }
        
        .btn-secondary:hover {
            background: #3c4043;
        }
        
        .results-container {
            max-height: 400px;
            overflow-y: auto;
        }
        
        .log-entry {
            background: #f8f9fa;
            border: 1px solid #e0e0e0;
            border-radius: 6px;
            padding: 1rem;
            margin-bottom: 0.5rem;
            font-family: 'Roboto Mono', monospace;
            font-size: 0.9rem;
        }
        
        .log-entry .log-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 0.5rem;
            font-weight: 500;
        }
        
        .log-level {
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 0.8rem;
            font-weight: 600;
        }
        
        .log-level.INFO { background: #e8f5e8; color: #137333; }
        .log-level.WARN { background: #fef7e0; color: #f57c00; }
        .log-level.ERROR { background: #fce8e6; color: #d93025; }
        .log-level.DEBUG { background: #e3f2fd; color: #1565c0; }
        
        .log-message {
            color: #3c4043;
            margin: 0.5rem 0;
        }
        
        .log-metadata {
            font-size: 0.8rem;
            color: #5f6368;
            padding-top: 0.5rem;
            border-top: 1px solid #e0e0e0;
        }
        
        .status-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .status-online { background: #34a853; }
        .status-processing { background: #fbbc04; }
        .status-error { background: #ea4335; }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.7; }
            100% { opacity: 1; }
        }
        
        .processing {
            animation: pulse 2s infinite;
        }
        
        .empty-state {
            text-align: center;
            color: #5f6368;
            font-style: italic;
            padding: 2rem;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>
            🔍 Real-Time Log Indexing System
            <span class="status" id="status">
                <span class="status-indicator status-online"></span>
                Online
            </span>
        </h1>
    </div>
    
    <div class="container">
        <div class="card">
            <h2>📊 Indexing Statistics</h2>
            <div class="metrics-grid">
                <div class="metric">
                    <span class="metric-value" id="totalDocs">0</span>
                    <div class="metric-label">Total Documents</div>
                </div>
                <div class="metric">
                    <span class="metric-value" id="indexingLatency">0</span>
                    <div class="metric-label">Avg Latency (ms)</div>
                </div>
                <div class="metric">
                    <span class="metric-value" id="memorySegments">0</span>
                    <div class="metric-label">Memory Segments</div>
                </div>
                <div class="metric">
                    <span class="metric-value" id="diskSegments">0</span>
                    <div class="metric-label">Disk Segments</div>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h2>🔍 Search Performance</h2>
            <div class="metrics-grid">
                <div class="metric">
                    <span class="metric-value" id="searchCount">0</span>
                    <div class="metric-label">Searches Performed</div>
                </div>
                <div class="metric">
                    <span class="metric-value" id="searchLatency">0</span>
                    <div class="metric-label">Avg Search Time (ms)</div>
                </div>
                <div class="metric">
                    <span class="metric-value" id="avgResults">0</span>
                    <div class="metric-label">Avg Results</div>
                </div>
                <div class="metric">
                    <span class="metric-value" id="logsProcessed">0</span>
                    <div class="metric-label">Logs Processed</div>
                </div>
            </div>
        </div>
        
        <div class="card search-section">
            <h2>🔍 Search Logs</h2>
            <div class="search-form">
                <div class="form-group">
                    <label for="searchQuery">Search Query</label>
                    <input type="text" id="searchQuery" placeholder="Enter search terms..." value="auth user">
                </div>
                <div class="form-group">
                    <label for="serviceFilter">Service</label>
                    <select id="serviceFilter">
                        <option value="">All Services</option>
                        <option value="web-api">Web API</option>
                        <option value="auth-service">Auth Service</option>
                        <option value="payment-processor">Payment Processor</option>
                        <option value="user-service">User Service</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="levelFilter">Level</label>
                    <select id="levelFilter">
                        <option value="">All Levels</option>
                        <option value="INFO">INFO</option>
                        <option value="WARN">WARN</option>
                        <option value="ERROR">ERROR</option>
                        <option value="DEBUG">DEBUG</option>
                    </select>
                </div>
                <button class="btn" onclick="performSearch()">Search</button>
                <button class="btn btn-secondary" onclick="generateSampleLogs()">Generate Sample</button>
            </div>
            
            <div id="searchResults">
                <div class="empty-state">
                    Enter a search query to find logs. Click "Generate Sample" to create test data.
                </div>
            </div>
        </div>
    </div>
    
    <script>
        async function updateStats() {
            try {
                const response = await fetch('/api/stats');
                const stats = await response.json();
                
                // Update indexing stats
                document.getElementById('totalDocs').textContent = 
                    stats.index_manager.total_documents || 0;
                document.getElementById('indexingLatency').textContent = 
                    Math.round(stats.index_manager.avg_indexing_latency_ms || 0);
                document.getElementById('memorySegments').textContent = 
                    stats.index_manager.memory_segments || 0;
                document.getElementById('diskSegments').textContent = 
                    stats.index_manager.disk_segments || 0;
                
                // Update search stats
                document.getElementById('searchCount').textContent = 
                    stats.search_interface.searches_performed || 0;
                document.getElementById('searchLatency').textContent = 
                    Math.round(stats.search_interface.avg_search_time_ms || 0);
                document.getElementById('avgResults').textContent = 
                    Math.round(stats.search_interface.avg_results_per_search || 0);
                document.getElementById('logsProcessed').textContent = 
                    stats.stream_processor.logs_processed || 0;
                    
            } catch (error) {
                console.error('Failed to update stats:', error);
            }
        }
        
        async function performSearch() {
            const query = document.getElementById('searchQuery').value;
            const serviceFilter = document.getElementById('serviceFilter').value;
            const levelFilter = document.getElementById('levelFilter').value;
            
            if (!query.trim()) {
                alert('Please enter a search query');
                return;
            }
            
            const filters = {};
            if (serviceFilter) filters.service = serviceFilter;
            if (levelFilter) filters.level = levelFilter;
            
            const resultsContainer = document.getElementById('searchResults');
            resultsContainer.innerHTML = '<div class="processing">🔍 Searching...</div>';
            
            try {
                const response = await fetch('/api/search', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        query: query,
                        filters: filters,
                        limit: 50
                    })
                });
                
                const data = await response.json();
                
                if (data.error) {
                    resultsContainer.innerHTML = `<div class="empty-state">Error: ${data.error}</div>`;
                    await updateStats();
                    return;
                }
                
                if (data.results.length === 0) {
                    resultsContainer.innerHTML = '<div class="empty-state">No results found. Try different search terms.</div>';
                    await updateStats();
                    return;
                }
                
                let html = `<p style="margin-bottom: 1rem; color: #5f6368;">
                    Found ${data.total_count} results in ${Math.round(data.search_time_ms)}ms
                </p>`;
                
                data.results.forEach(result => {
                    const log = result.log_entry;
                    const timestamp = new Date(log.timestamp).toLocaleString();
                    
                    html += `
                        <div class="log-entry">
                            <div class="log-header">
                                <span>
                                    <span class="log-level ${log.level}">${log.level}</span>
                                    <strong>${log.service}</strong>
                                </span>
                                <span style="font-size: 0.8rem; color: #5f6368;">${timestamp}</span>
                            </div>
                            <div class="log-message">${log.message}</div>
                            <div class="log-metadata">
                                ID: ${log.id} | Score: ${result.score} | Segment: ${result.segment_id}
                                ${Object.entries(log.metadata).map(([k,v]) => `${k}: ${v}`).join(' | ')}
                            </div>
                        </div>
                    `;
                });
                
                resultsContainer.innerHTML = html;
                await updateStats();
                
            } catch (error) {
                resultsContainer.innerHTML = `<div class="empty-state">Error: ${error.message}</div>`;
                await updateStats();
            }
        }
        
        async function generateSampleLogs() {
            const button = event.target;
            button.disabled = true;
            button.textContent = 'Generating...';
            
            try {
                const response = await fetch('/api/generate-sample', {
                    method: 'POST'
                });
                const data = await response.json();
                
                alert(data.message);
                
                // Wait a moment then perform an automatic search
                setTimeout(() => {
                    document.getElementById('searchQuery').value = 'user';
                    performSearch();
                }, 2000);
                
            } catch (error) {
                alert('Error generating sample logs: ' + error.message);
            } finally {
                button.disabled = false;
                button.textContent = 'Generate Sample';
            }
        }
        
        // Allow Enter key for search
        document.getElementById('searchQuery').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                performSearch();
            }
        });
        
        // Initialize
        updateStats();
    </script>
</body>
</html>
        '''

# Create main application
app_instance = WebInterface()
app = app_instance.app
