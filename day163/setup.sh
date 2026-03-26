#!/bin/bash

# Day 163: Service Dependency Mapping - Complete Implementation
# This script creates, builds, tests, and runs the entire system

set -e  # Exit on any error

echo "========================================="
echo "Day 163: Service Dependency Mapping"
echo "========================================="

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project root
PROJECT_ROOT="$(pwd)/dependency-mapper"

echo -e "${BLUE}Step 1: Creating project structure...${NC}"
mkdir -p "$PROJECT_ROOT"/{backend,frontend,logs,tests}
cd "$PROJECT_ROOT"

# Create backend files
echo -e "${BLUE}Step 2: Creating backend source files...${NC}"

# Parser module
cat > backend/parser.py << 'PARSER_EOF'
"""
Log parser for extracting service dependencies
Supports multiple log formats: HTTP, RPC, Database
"""
import re
from datetime import datetime
from typing import Dict, Optional, Tuple

class DependencyParser:
    def __init__(self):
        self.patterns = {
            'http': r'(\w+)\s+called\s+(\w+)\s+(GET|POST|PUT|DELETE)\s+(\S+)\s+(\d+)ms',
            'rpc': r'(\w+)\s*->\s*(\w+)\.(\w+)\(\)\s+(\d+)ms',
            'db': r'(\w+)\s*->\s*(PostgreSQL|MySQL|MongoDB)\s+(SELECT|INSERT|UPDATE|DELETE)\s+(\w+)\s+(\d+)ms',
            'generic': r'(\w+)\s*->\s*(\w+)\s+(\d+)ms'
        }
    
    def parse_log_line(self, line: str) -> Optional[Dict]:
        """Parse a single log line and extract dependency information"""
        timestamp_match = re.search(r'\[([\d\-: ]+)\]', line)
        timestamp = datetime.fromisoformat(timestamp_match.group(1)) if timestamp_match else datetime.now()
        
        # Try HTTP pattern
        match = re.search(self.patterns['http'], line)
        if match:
            return {
                'caller': match.group(1),
                'callee': match.group(2),
                'type': 'http',
                'method': match.group(3),
                'endpoint': match.group(4),
                'latency': int(match.group(5)),
                'timestamp': timestamp
            }
        
        # Try RPC pattern
        match = re.search(self.patterns['rpc'], line)
        if match:
            return {
                'caller': match.group(1),
                'callee': match.group(2),
                'type': 'rpc',
                'method': match.group(3),
                'latency': int(match.group(4)),
                'timestamp': timestamp
            }
        
        # Try database pattern
        match = re.search(self.patterns['db'], line)
        if match:
            return {
                'caller': match.group(1),
                'callee': match.group(2),
                'type': 'database',
                'operation': match.group(3),
                'table': match.group(4),
                'latency': int(match.group(5)),
                'timestamp': timestamp
            }
        
        # Try generic pattern
        match = re.search(self.patterns['generic'], line)
        if match:
            return {
                'caller': match.group(1),
                'callee': match.group(2),
                'type': 'generic',
                'latency': int(match.group(3)),
                'timestamp': timestamp
            }
        
        return None

    def parse_log_file(self, filepath: str):
        """Parse entire log file and yield dependencies"""
        with open(filepath, 'r') as f:
            for line in f:
                dep = self.parse_log_line(line.strip())
                if dep:
                    yield dep
PARSER_EOF

# Graph builder module
cat > backend/graph.py << 'GRAPH_EOF'
"""
Dependency graph builder and analyzer
Uses in-memory graph structure for fast lookups
"""
from collections import defaultdict
from typing import Dict, List, Set, Tuple
import json

class DependencyGraph:
    def __init__(self):
        self.edges = defaultdict(lambda: defaultdict(lambda: {
            'weight': 0,
            'latencies': [],
            'avg_latency': 0,
            'type': 'unknown',
            'first_seen': None,
            'last_seen': None
        }))
        self.nodes = set()
    
    def add_dependency(self, caller: str, callee: str, latency: int, 
                      dep_type: str = 'generic', timestamp=None):
        """Add or update a dependency edge"""
        self.nodes.add(caller)
        self.nodes.add(callee)
        
        edge = self.edges[caller][callee]
        edge['weight'] += 1
        edge['latencies'].append(latency)
        edge['avg_latency'] = sum(edge['latencies']) / len(edge['latencies'])
        edge['type'] = dep_type
        
        if edge['first_seen'] is None:
            edge['first_seen'] = timestamp
        edge['last_seen'] = timestamp
    
    def get_dependencies(self, service: str) -> Dict:
        """Get all dependencies for a service"""
        return {
            'outgoing': dict(self.edges.get(service, {})),
            'incoming': {
                caller: deps
                for caller, deps in self.edges.items()
                if service in deps
            }
        }
    
    def find_cycles(self) -> List[List[str]]:
        """Detect circular dependencies using DFS"""
        cycles = []
        visited = set()
        rec_stack = set()
        path = []
        
        def dfs(node):
            visited.add(node)
            rec_stack.add(node)
            path.append(node)
            
            for neighbor in self.edges.get(node, {}):
                if neighbor not in visited:
                    dfs(neighbor)
                elif neighbor in rec_stack:
                    # Found a cycle
                    cycle_start = path.index(neighbor)
                    cycles.append(path[cycle_start:] + [neighbor])
            
            path.pop()
            rec_stack.remove(node)
        
        for node in self.nodes:
            if node not in visited:
                dfs(node)
        
        return cycles
    
    def find_single_points_of_failure(self) -> List[Tuple[str, int]]:
        """Find services with high outgoing dependencies"""
        spofs = []
        for node in self.nodes:
            incoming_count = sum(1 for n in self.edges if node in self.edges[n])
            if incoming_count > 2:  # More than 2 services depend on it
                spofs.append((node, incoming_count))
        return sorted(spofs, key=lambda x: x[1], reverse=True)
    
    def get_critical_paths(self) -> List[Tuple[List[str], int]]:
        """Find longest dependency chains"""
        def dfs_longest_path(node, visited=set()):
            if node in visited:
                return []
            
            visited.add(node)
            longest = []
            
            for neighbor in self.edges.get(node, {}):
                path = dfs_longest_path(neighbor, visited.copy())
                if len(path) > len(longest):
                    longest = path
            
            visited.remove(node)
            return [node] + longest
        
        paths = []
        for node in self.nodes:
            path = dfs_longest_path(node)
            if path:
                total_latency = sum(
                    self.edges[path[i]][path[i+1]]['avg_latency']
                    for i in range(len(path)-1)
                    if path[i+1] in self.edges[path[i]]
                )
                paths.append((path, int(total_latency)))
        
        return sorted(paths, key=lambda x: len(x[0]), reverse=True)[:5]
    
    def to_json(self) -> str:
        """Export graph to JSON for visualization"""
        nodes_list = [{'id': node, 'label': node} for node in self.nodes]
        edges_list = []
        
        for caller, callees in self.edges.items():
            for callee, data in callees.items():
                edges_list.append({
                    'source': caller,
                    'target': callee,
                    'weight': data['weight'],
                    'avgLatency': data['avg_latency'],
                    'type': data['type']
                })
        
        return json.dumps({
            'nodes': nodes_list,
            'edges': edges_list
        })
GRAPH_EOF

# Analyzer module
cat > backend/analyzer.py << 'ANALYZER_EOF'
"""
Impact analyzer for dependency graphs
Simulates failure scenarios and computes blast radius
"""
from typing import Set, Dict, List

class ImpactAnalyzer:
    def __init__(self, graph):
        self.graph = graph
    
    def simulate_failure(self, service: str) -> Dict:
        """Simulate service failure and find impacted services"""
        impacted = set()
        
        def propagate_failure(node, visited=set()):
            if node in visited:
                return
            visited.add(node)
            impacted.add(node)
            
            # Find all services that depend on this node
            for caller, deps in self.graph.edges.items():
                if node in deps:
                    propagate_failure(caller, visited)
        
        propagate_failure(service)
        impacted.discard(service)  # Don't count the failed service itself
        
        return {
            'failed_service': service,
            'impacted_services': list(impacted),
            'impact_count': len(impacted),
            'blast_radius': self._calculate_blast_radius(impacted)
        }
    
    def _calculate_blast_radius(self, impacted: Set[str]) -> str:
        """Categorize impact severity"""
        count = len(impacted)
        if count == 0:
            return 'none'
        elif count <= 2:
            return 'low'
        elif count <= 5:
            return 'medium'
        elif count <= 10:
            return 'high'
        else:
            return 'critical'
    
    def analyze_all_failures(self) -> List[Dict]:
        """Analyze failure impact for all services"""
        results = []
        for service in self.graph.nodes:
            impact = self.simulate_failure(service)
            results.append(impact)
        
        return sorted(results, key=lambda x: x['impact_count'], reverse=True)
ANALYZER_EOF

# WebSocket server
cat > backend/server.py << 'SERVER_EOF'
"""
WebSocket server for real-time dependency updates
Watches log files and pushes updates to frontend
"""
import asyncio
import json
from datetime import datetime
import websockets
from parser import DependencyParser
from graph import DependencyGraph
from analyzer import ImpactAnalyzer

class DependencyServer:
    def __init__(self, log_file: str, port: int = 8765):
        self.log_file = log_file
        self.port = port
        self.parser = DependencyParser()
        self.graph = DependencyGraph()
        self.analyzer = ImpactAnalyzer(self.graph)
        self.clients = set()
        self.last_position = 0
    
    async def register(self, websocket):
        self.clients.add(websocket)
        # Send current graph state
        await websocket.send(json.dumps({
            'type': 'init',
            'data': json.loads(self.graph.to_json())
        }))
    
    async def unregister(self, websocket):
        self.clients.discard(websocket)
    
    async def broadcast(self, message):
        if self.clients:
            await asyncio.gather(
                *[client.send(message) for client in self.clients],
                return_exceptions=True
            )
    
    async def watch_logs(self):
        """Watch log file for new entries"""
        while True:
            try:
                with open(self.log_file, 'r') as f:
                    f.seek(self.last_position)
                    for line in f:
                        dep = self.parser.parse_log_line(line.strip())
                        if dep:
                            self.graph.add_dependency(
                                dep['caller'],
                                dep['callee'],
                                dep['latency'],
                                dep['type'],
                                dep['timestamp']
                            )
                            
                            # Broadcast update
                            await self.broadcast(json.dumps({
                                'type': 'update',
                                'dependency': {
                                    'caller': dep['caller'],
                                    'callee': dep['callee'],
                                    'latency': dep['latency'],
                                    'type': dep['type']
                                }
                            }))
                            
                            # Check for patterns
                            cycles = self.graph.find_cycles()
                            if cycles:
                                await self.broadcast(json.dumps({
                                    'type': 'alert',
                                    'alert_type': 'cycle',
                                    'cycles': cycles
                                }))
                            
                            spofs = self.graph.find_single_points_of_failure()
                            if spofs:
                                await self.broadcast(json.dumps({
                                    'type': 'alert',
                                    'alert_type': 'spof',
                                    'spofs': [{'service': s, 'count': c} for s, c in spofs[:3]]
                                }))
                    
                    self.last_position = f.tell()
            
            except FileNotFoundError:
                pass
            
            await asyncio.sleep(0.5)
    
    async def handler(self, websocket, path):
        await self.register(websocket)
        try:
            async for message in websocket:
                data = json.loads(message)
                
                if data['type'] == 'get_impact':
                    service = data['service']
                    impact = self.analyzer.simulate_failure(service)
                    await websocket.send(json.dumps({
                        'type': 'impact_result',
                        'impact': impact
                    }))
                
                elif data['type'] == 'get_critical_paths':
                    paths = self.graph.get_critical_paths()
                    await websocket.send(json.dumps({
                        'type': 'critical_paths',
                        'paths': [{'path': p, 'latency': l} for p, l in paths]
                    }))
        
        finally:
            await self.unregister(websocket)
    
    async def start(self):
        """Start the WebSocket server"""
        async with websockets.serve(self.handler, "localhost", self.port):
            print(f"WebSocket server started on ws://localhost:{self.port}")
            await self.watch_logs()

def main():
    import sys
    log_file = sys.argv[1] if len(sys.argv) > 1 else '../logs/sample.log'
    server = DependencyServer(log_file)
    asyncio.run(server.start())

if __name__ == '__main__':
    main()
SERVER_EOF

echo -e "${BLUE}Step 3: Creating frontend files...${NC}"

# Frontend HTML
cat > frontend/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Service Dependency Mapper</title>
    <script src="https://d3js.org/d3.v7.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        header {
            background: white;
            padding: 20px 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        
        h1 {
            color: #667eea;
            font-size: 28px;
            margin-bottom: 5px;
        }
        
        .subtitle {
            color: #666;
            font-size: 14px;
        }
        
        .dashboard {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 20px;
        }
        
        .card {
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .card h2 {
            color: #667eea;
            font-size: 18px;
            margin-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
            padding-bottom: 10px;
        }
        
        #graph-container {
            height: 600px;
            border: 2px solid #f0f0f0;
            border-radius: 8px;
            overflow: hidden;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
            margin-bottom: 20px;
        }
        
        .stat-box {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
        }
        
        .stat-value {
            font-size: 32px;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .stat-label {
            font-size: 12px;
            opacity: 0.9;
        }
        
        .alert {
            padding: 12px;
            border-radius: 6px;
            margin-bottom: 10px;
            font-size: 13px;
        }
        
        .alert-warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            color: #856404;
        }
        
        .alert-danger {
            background: #f8d7da;
            border-left: 4px solid #dc3545;
            color: #721c24;
        }
        
        .alert-info {
            background: #d1ecf1;
            border-left: 4px solid #17a2b8;
            color: #0c5460;
        }
        
        .node {
            cursor: pointer;
            stroke: #fff;
            stroke-width: 2px;
        }
        
        .link {
            stroke: #999;
            stroke-opacity: 0.6;
        }
        
        .node-label {
            font-size: 11px;
            font-weight: 600;
            pointer-events: none;
            text-anchor: middle;
        }
        
        .connection-status {
            display: inline-block;
            width: 10px;
            height: 10px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .connected {
            background: #28a745;
            box-shadow: 0 0 5px #28a745;
        }
        
        .disconnected {
            background: #dc3545;
        }
        
        #alerts-container {
            max-height: 300px;
            overflow-y: auto;
        }
        
        .list-item {
            padding: 8px;
            border-bottom: 1px solid #f0f0f0;
            font-size: 13px;
        }
        
        .list-item:hover {
            background: #f8f9fa;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🔗 Service Dependency Mapper</h1>
            <p class="subtitle">Real-time dependency discovery and analysis | Day 163</p>
            <div style="margin-top: 10px;">
                <span class="connection-status connected" id="status-indicator"></span>
                <span id="status-text">Connected</span>
            </div>
        </header>
        
        <div class="dashboard">
            <div class="card">
                <h2>Dependency Graph</h2>
                <div id="graph-container"></div>
            </div>
            
            <div>
                <div class="card">
                    <h2>Statistics</h2>
                    <div class="stats-grid">
                        <div class="stat-box">
                            <div class="stat-value" id="services-count">0</div>
                            <div class="stat-label">Services</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-value" id="dependencies-count">0</div>
                            <div class="stat-label">Dependencies</div>
                        </div>
                    </div>
                </div>
                
                <div class="card" style="margin-top: 20px;">
                    <h2>Alerts & Warnings</h2>
                    <div id="alerts-container">
                        <div class="alert alert-info">System monitoring active...</div>
                    </div>
                </div>
                
                <div class="card" style="margin-top: 20px;">
                    <h2>Critical Paths</h2>
                    <div id="paths-container"></div>
                </div>
            </div>
        </div>
    </div>
    
    <script src="app.js"></script>
</body>
</html>
HTML_EOF

# Frontend JavaScript
cat > frontend/app.js << 'JS_EOF'
// Service Dependency Mapper - Frontend
let ws;
let graph = { nodes: [], edges: [] };
let simulation;

// Connect to WebSocket server
function connect() {
    ws = new WebSocket('ws://localhost:8765');
    
    ws.onopen = () => {
        console.log('Connected to server');
        updateStatus(true);
    };
    
    ws.onclose = () => {
        console.log('Disconnected from server');
        updateStatus(false);
        setTimeout(connect, 3000); // Reconnect after 3s
    };
    
    ws.onmessage = (event) => {
        const message = JSON.parse(event.data);
        handleMessage(message);
    };
    
    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
    };
}

function updateStatus(connected) {
    const indicator = document.getElementById('status-indicator');
    const text = document.getElementById('status-text');
    
    if (connected) {
        indicator.className = 'connection-status connected';
        text.textContent = 'Connected';
    } else {
        indicator.className = 'connection-status disconnected';
        text.textContent = 'Disconnected';
    }
}

function handleMessage(message) {
    switch (message.type) {
        case 'init':
            graph = message.data;
            initializeGraph();
            updateStats();
            requestCriticalPaths();
            break;
        
        case 'update':
            addDependency(message.dependency);
            updateStats();
            break;
        
        case 'alert':
            showAlert(message);
            break;
        
        case 'critical_paths':
            displayCriticalPaths(message.paths);
            break;
    }
}

function initializeGraph() {
    const container = document.getElementById('graph-container');
    const width = container.clientWidth;
    const height = container.clientHeight;
    
    // Clear existing SVG
    d3.select('#graph-container').selectAll('*').remove();
    
    const svg = d3.select('#graph-container')
        .append('svg')
        .attr('width', width)
        .attr('height', height);
    
    // Create arrow marker
    svg.append('defs').append('marker')
        .attr('id', 'arrowhead')
        .attr('viewBox', '-0 -5 10 10')
        .attr('refX', 20)
        .attr('refY', 0)
        .attr('orient', 'auto')
        .attr('markerWidth', 6)
        .attr('markerHeight', 6)
        .append('svg:path')
        .attr('d', 'M 0,-5 L 10 ,0 L 0,5')
        .attr('fill', '#999');
    
    simulation = d3.forceSimulation(graph.nodes)
        .force('link', d3.forceLink(graph.edges).id(d => d.id).distance(100))
        .force('charge', d3.forceManyBody().strength(-300))
        .force('center', d3.forceCenter(width / 2, height / 2))
        .force('collision', d3.forceCollide().radius(30));
    
    const link = svg.append('g')
        .selectAll('line')
        .data(graph.edges)
        .enter()
        .append('line')
        .attr('class', 'link')
        .attr('stroke-width', d => Math.min(Math.sqrt(d.weight) * 2, 8))
        .attr('marker-end', 'url(#arrowhead)');
    
    const node = svg.append('g')
        .selectAll('circle')
        .data(graph.nodes)
        .enter()
        .append('circle')
        .attr('class', 'node')
        .attr('r', 15)
        .attr('fill', d => getNodeColor(d.id))
        .call(drag(simulation))
        .on('click', (event, d) => {
            // Request impact analysis
            ws.send(JSON.stringify({
                type: 'get_impact',
                service: d.id
            }));
        });
    
    const label = svg.append('g')
        .selectAll('text')
        .data(graph.nodes)
        .enter()
        .append('text')
        .attr('class', 'node-label')
        .attr('dy', 25)
        .text(d => d.label);
    
    simulation.on('tick', () => {
        link
            .attr('x1', d => d.source.x)
            .attr('y1', d => d.source.y)
            .attr('x2', d => d.target.x)
            .attr('y2', d => d.target.y);
        
        node
            .attr('cx', d => d.x)
            .attr('cy', d => d.y);
        
        label
            .attr('x', d => d.x)
            .attr('y', d => d.y);
    });
}

function addDependency(dep) {
    // Add nodes if they don't exist
    if (!graph.nodes.find(n => n.id === dep.caller)) {
        graph.nodes.push({ id: dep.caller, label: dep.caller });
    }
    if (!graph.nodes.find(n => n.id === dep.callee)) {
        graph.nodes.push({ id: dep.callee, label: dep.callee });
    }
    
    // Update or add edge
    const existingEdge = graph.edges.find(
        e => e.source.id === dep.caller && e.target.id === dep.callee
    );
    
    if (existingEdge) {
        existingEdge.weight += 1;
    } else {
        graph.edges.push({
            source: dep.caller,
            target: dep.callee,
            weight: 1,
            avgLatency: dep.latency
        });
    }
    
    // Restart simulation with new data
    if (simulation) {
        simulation.nodes(graph.nodes);
        simulation.force('link').links(graph.edges);
        simulation.alpha(0.3).restart();
    }
}

function getNodeColor(nodeId) {
    const colors = ['#667eea', '#764ba2', '#f093fb', '#4facfe', '#43e97b'];
    const hash = nodeId.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    return colors[hash % colors.length];
}

function drag(simulation) {
    function dragstarted(event) {
        if (!event.active) simulation.alphaTarget(0.3).restart();
        event.subject.fx = event.subject.x;
        event.subject.fy = event.subject.y;
    }
    
    function dragged(event) {
        event.subject.fx = event.x;
        event.subject.fy = event.y;
    }
    
    function dragended(event) {
        if (!event.active) simulation.alphaTarget(0);
        event.subject.fx = null;
        event.subject.fy = null;
    }
    
    return d3.drag()
        .on('start', dragstarted)
        .on('drag', dragged)
        .on('end', dragended);
}

function updateStats() {
    document.getElementById('services-count').textContent = graph.nodes.length;
    document.getElementById('dependencies-count').textContent = graph.edges.length;
}

function showAlert(message) {
    const container = document.getElementById('alerts-container');
    
    if (message.alert_type === 'cycle') {
        const alert = document.createElement('div');
        alert.className = 'alert alert-danger';
        alert.innerHTML = `<strong>⚠ Circular Dependency:</strong> ${message.cycles[0].join(' → ')}`;
        container.insertBefore(alert, container.firstChild);
    } else if (message.alert_type === 'spof') {
        const alert = document.createElement('div');
        alert.className = 'alert alert-warning';
        const service = message.spofs[0];
        alert.innerHTML = `<strong>⚠ Single Point of Failure:</strong> ${service.service} (${service.count} dependencies)`;
        container.insertBefore(alert, container.firstChild);
    }
    
    // Keep only last 10 alerts
    while (container.children.length > 10) {
        container.removeChild(container.lastChild);
    }
}

function requestCriticalPaths() {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'get_critical_paths' }));
    }
}

function displayCriticalPaths(paths) {
    const container = document.getElementById('paths-container');
    container.innerHTML = '';
    
    if (paths.length === 0) {
        container.innerHTML = '<div class="list-item">No critical paths detected</div>';
        return;
    }
    
    paths.slice(0, 5).forEach((pathData, index) => {
        const div = document.createElement('div');
        div.className = 'list-item';
        div.innerHTML = `
            <strong>Path ${index + 1}:</strong> ${pathData.path.join(' → ')}<br>
            <small>Total Latency: ${pathData.latency}ms</small>
        `;
        container.appendChild(div);
    });
}

// Initialize connection on page load
connect();

// Request critical paths every 5 seconds
setInterval(requestCriticalPaths, 5000);
JS_EOF

echo -e "${BLUE}Step 4: Creating sample log data...${NC}"

cat > logs/sample.log << 'LOG_EOF'
[2025-01-30 10:00:01] WebApp called AuthService GET /api/validate 45ms
[2025-01-30 10:00:02] WebApp called UserService GET /api/user/123 120ms
[2025-01-30 10:00:03] UserService -> PostgreSQL SELECT users 35ms
[2025-01-30 10:00:04] WebApp called OrderService POST /api/orders 200ms
[2025-01-30 10:00:05] OrderService -> InventoryService.checkStock() 80ms
[2025-01-30 10:00:06] OrderService -> PaymentService.processPayment() 150ms
[2025-01-30 10:00:07] PaymentService -> PostgreSQL INSERT transactions 40ms
[2025-01-30 10:00:08] InventoryService -> PostgreSQL UPDATE inventory 55ms
[2025-01-30 10:00:09] WebApp called NotificationService POST /api/notify 90ms
[2025-01-30 10:00:10] NotificationService -> EmailService.send() 180ms
[2025-01-30 10:00:11] WebApp called AuthService GET /api/validate 42ms
[2025-01-30 10:00:12] WebApp called UserService GET /api/user/456 115ms
[2025-01-30 10:00:13] OrderService -> PaymentService.processPayment() 145ms
[2025-01-30 10:00:14] SearchService -> PostgreSQL SELECT products 65ms
[2025-01-30 10:00:15] WebApp called SearchService GET /api/search 95ms
LOG_EOF

echo -e "${BLUE}Step 5: Creating test files...${NC}"

cat > tests/test_parser.py << 'TEST_PARSER_EOF'
import sys
sys.path.insert(0, '../backend')

from parser import DependencyParser
import unittest

class TestDependencyParser(unittest.TestCase):
    def setUp(self):
        self.parser = DependencyParser()
    
    def test_http_pattern(self):
        line = "[2025-01-30 10:00:01] WebApp called AuthService GET /api/validate 45ms"
        result = self.parser.parse_log_line(line)
        
        self.assertIsNotNone(result)
        self.assertEqual(result['caller'], 'WebApp')
        self.assertEqual(result['callee'], 'AuthService')
        self.assertEqual(result['type'], 'http')
        self.assertEqual(result['latency'], 45)
    
    def test_rpc_pattern(self):
        line = "[2025-01-30 10:00:05] OrderService -> InventoryService.checkStock() 80ms"
        result = self.parser.parse_log_line(line)
        
        self.assertIsNotNone(result)
        self.assertEqual(result['caller'], 'OrderService')
        self.assertEqual(result['callee'], 'InventoryService')
        self.assertEqual(result['type'], 'rpc')
        self.assertEqual(result['latency'], 80)
    
    def test_database_pattern(self):
        line = "[2025-01-30 10:00:03] UserService -> PostgreSQL SELECT users 35ms"
        result = self.parser.parse_log_line(line)
        
        self.assertIsNotNone(result)
        self.assertEqual(result['caller'], 'UserService')
        self.assertEqual(result['callee'], 'PostgreSQL')
        self.assertEqual(result['type'], 'database')
        self.assertEqual(result['latency'], 35)
    
    def test_invalid_line(self):
        line = "This is not a valid log line"
        result = self.parser.parse_log_line(line)
        self.assertIsNone(result)

if __name__ == '__main__':
    unittest.main()
TEST_PARSER_EOF

cat > tests/test_graph.py << 'TEST_GRAPH_EOF'
import sys
sys.path.insert(0, '../backend')

from graph import DependencyGraph
import unittest
from datetime import datetime

class TestDependencyGraph(unittest.TestCase):
    def setUp(self):
        self.graph = DependencyGraph()
    
    def test_add_dependency(self):
        self.graph.add_dependency('A', 'B', 100, 'http', datetime.now())
        
        self.assertIn('A', self.graph.nodes)
        self.assertIn('B', self.graph.nodes)
        self.assertEqual(self.graph.edges['A']['B']['weight'], 1)
        self.assertEqual(self.graph.edges['A']['B']['avg_latency'], 100)
    
    def test_update_dependency(self):
        self.graph.add_dependency('A', 'B', 100, 'http', datetime.now())
        self.graph.add_dependency('A', 'B', 200, 'http', datetime.now())
        
        self.assertEqual(self.graph.edges['A']['B']['weight'], 2)
        self.assertEqual(self.graph.edges['A']['B']['avg_latency'], 150)
    
    def test_find_cycles(self):
        self.graph.add_dependency('A', 'B', 100, 'http', datetime.now())
        self.graph.add_dependency('B', 'C', 100, 'http', datetime.now())
        self.graph.add_dependency('C', 'A', 100, 'http', datetime.now())
        
        cycles = self.graph.find_cycles()
        self.assertTrue(len(cycles) > 0)
    
    def test_single_point_of_failure(self):
        self.graph.add_dependency('A', 'C', 100, 'http', datetime.now())
        self.graph.add_dependency('B', 'C', 100, 'http', datetime.now())
        self.graph.add_dependency('D', 'C', 100, 'http', datetime.now())
        
        spofs = self.graph.find_single_points_of_failure()
        self.assertTrue(any(s[0] == 'C' for s in spofs))

if __name__ == '__main__':
    unittest.main()
TEST_GRAPH_EOF

cat > tests/test_analyzer.py << 'TEST_ANALYZER_EOF'
import sys
sys.path.insert(0, '../backend')

from graph import DependencyGraph
from analyzer import ImpactAnalyzer
import unittest
from datetime import datetime

class TestImpactAnalyzer(unittest.TestCase):
    def setUp(self):
        self.graph = DependencyGraph()
        self.graph.add_dependency('A', 'B', 100, 'http', datetime.now())
        self.graph.add_dependency('B', 'C', 100, 'http', datetime.now())
        self.graph.add_dependency('B', 'D', 100, 'http', datetime.now())
        self.analyzer = ImpactAnalyzer(self.graph)
    
    def test_simulate_failure(self):
        impact = self.analyzer.simulate_failure('B')
        
        self.assertEqual(impact['failed_service'], 'B')
        self.assertIn('A', impact['impacted_services'])
        self.assertTrue(impact['impact_count'] > 0)
    
    def test_blast_radius(self):
        impact = self.analyzer.simulate_failure('B')
        self.assertIn(impact['blast_radius'], ['none', 'low', 'medium', 'high', 'critical'])

if __name__ == '__main__':
    unittest.main()
TEST_ANALYZER_EOF

echo -e "${BLUE}Step 6: Creating requirements.txt...${NC}"

cat > requirements.txt << 'REQ_EOF'
websockets==12.0
aiofiles==23.2.1
REQ_EOF

echo -e "${BLUE}Step 7: Creating Dockerfile...${NC}"

cat > Dockerfile << 'DOCKERFILE_EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./backend/
COPY frontend/ ./frontend/
COPY logs/ ./logs/

EXPOSE 8765 8000

CMD ["python", "backend/server.py", "logs/sample.log"]
DOCKERFILE_EOF

cat > .dockerignore << 'DOCKERIGNORE_EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
*.so
*.egg
*.egg-info
dist
build
.venv
venv
ENV
DOCKERIGNORE_EOF

echo -e "${BLUE}Step 8: Creating start.sh script...${NC}"

cat > start.sh << 'START_EOF'
#!/bin/bash

echo "Starting Service Dependency Mapper..."

# Create and activate virtual environment
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment with Python 3.11..."
    python3 -m venv .venv
fi

source .venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt

# Start WebSocket server in background
echo "Starting WebSocket server..."
python backend/server.py logs/sample.log &
SERVER_PID=$!

# Start simple HTTP server for frontend
echo "Starting HTTP server for frontend..."
cd frontend
python -m http.server 8000 &
HTTP_PID=$!
cd ..

echo ""
echo "========================================="
echo "Service Dependency Mapper is running!"
echo "========================================="
echo "Dashboard: http://localhost:8000"
echo "WebSocket: ws://localhost:8765"
echo ""
echo "Press Ctrl+C to stop all services"
echo ""

# Save PIDs for cleanup
echo $SERVER_PID > .server.pid
echo $HTTP_PID > .http.pid

# Wait for interrupt
trap "kill $SERVER_PID $HTTP_PID 2>/dev/null; exit" INT TERM
wait
START_EOF

chmod +x start.sh

echo -e "${BLUE}Step 9: Creating stop.sh script...${NC}"

cat > stop.sh << 'STOP_EOF'
#!/bin/bash

echo "Stopping Service Dependency Mapper..."

if [ -f .server.pid ]; then
    SERVER_PID=$(cat .server.pid)
    kill $SERVER_PID 2>/dev/null
    rm .server.pid
fi

if [ -f .http.pid ]; then
    HTTP_PID=$(cat .http.pid)
    kill $HTTP_PID 2>/dev/null
    rm .http.pid
fi

# Kill any remaining Python processes
pkill -f "backend/server.py" 2>/dev/null
pkill -f "http.server 8000" 2>/dev/null

echo "All services stopped."
STOP_EOF

chmod +x stop.sh

echo -e "${GREEN}✓ Project structure created successfully${NC}"

# Verify all files exist
echo -e "${BLUE}Step 10: Verifying file structure...${NC}"

FILES=(
    "backend/parser.py"
    "backend/graph.py"
    "backend/analyzer.py"
    "backend/server.py"
    "frontend/index.html"
    "frontend/app.js"
    "logs/sample.log"
    "tests/test_parser.py"
    "tests/test_graph.py"
    "tests/test_analyzer.py"
    "requirements.txt"
    "Dockerfile"
    ".dockerignore"
    "start.sh"
    "stop.sh"
)

ALL_EXIST=true
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file (missing)"
        ALL_EXIST=false
    fi
done

if [ "$ALL_EXIST" = true ]; then
    echo -e "${GREEN}✓ All files created successfully${NC}"
else
    echo -e "${RED}✗ Some files are missing${NC}"
    exit 1
fi

# Create and activate virtual environment
echo -e "${BLUE}Step 11: Setting up Python virtual environment...${NC}"
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
echo -e "${BLUE}Step 12: Installing dependencies...${NC}"
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt

echo -e "${GREEN}✓ Dependencies installed${NC}"

# Run tests
echo -e "${BLUE}Step 13: Running unit tests...${NC}"

cd tests

echo "Testing parser..."
python test_parser.py -v
PARSER_TEST=$?

echo "Testing graph..."
python test_graph.py -v
GRAPH_TEST=$?

echo "Testing analyzer..."
python test_analyzer.py -v
ANALYZER_TEST=$?

cd ..

if [ $PARSER_TEST -eq 0 ] && [ $GRAPH_TEST -eq 0 ] && [ $ANALYZER_TEST -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo -e "${RED}✗ Some tests failed${NC}"
fi

# Start the application
echo -e "${BLUE}Step 14: Starting application...${NC}"

# Start WebSocket server in background
python backend/server.py logs/sample.log &
SERVER_PID=$!
sleep 2

# Start HTTP server for frontend
cd frontend
python -m http.server 8000 &
HTTP_PID=$!
cd ..

sleep 2

echo ""
echo "========================================="
echo "✓ Service Dependency Mapper is running!"
echo "========================================="
echo ""
echo "📊 Dashboard: http://localhost:8000"
echo "🔌 WebSocket: ws://localhost:8765"
echo ""
echo "Features:"
echo "  • Real-time dependency graph visualization"
echo "  • Automatic cycle detection"
echo "  • Single point of failure alerts"
echo "  • Critical path analysis"
echo "  • Click nodes to simulate failure impact"
echo ""
echo "To stop: ./stop.sh or Ctrl+C"
echo ""

# Add more log entries for demonstration
echo -e "${YELLOW}Adding more log entries for demonstration...${NC}"
sleep 3

cat >> logs/sample.log << 'DEMO_LOG'
[2025-01-30 10:00:16] WebApp called OrderService POST /api/orders 195ms
[2025-01-30 10:00:17] OrderService -> InventoryService.checkStock() 75ms
[2025-01-30 10:00:18] WebApp called RecommendationService GET /api/recommend 110ms
[2025-01-30 10:00:19] RecommendationService -> UserService.getPreferences() 88ms
[2025-01-30 10:00:20] RecommendationService -> SearchService.query() 92ms
[2025-01-30 10:00:21] AnalyticsService -> PostgreSQL INSERT events 48ms
[2025-01-30 10:00:22] WebApp called AnalyticsService POST /api/track 55ms
[2025-01-30 10:00:23] PaymentService -> BankAPI.charge() 320ms
[2025-01-30 10:00:24] OrderService -> NotificationService.notify() 95ms
[2025-01-30 10:00:25] CacheService -> Redis SET user:123 12ms
DEMO_LOG

echo ""
echo "========================================="
echo "Demo log entries added!"
echo "Check the dashboard for updates"
echo "========================================="

# Keep script running
echo ""
echo "Press Ctrl+C to stop..."
trap "kill $SERVER_PID $HTTP_PID 2>/dev/null; echo 'Stopped.'; exit" INT TERM
wait