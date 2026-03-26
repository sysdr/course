#!/bin/bash

# Day 162: Log-based Network Traffic Analysis - Setup Script
# This script sets up the complete network traffic analysis system

set -e  # Exit on error

echo "========================================="
echo "Day 162: Network Traffic Analysis Setup"
echo "========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project root
PROJECT_ROOT=$(pwd)/network_traffic_analysis
echo -e "${BLUE}Creating project structure at: $PROJECT_ROOT${NC}"

# Create directory structure
mkdir -p $PROJECT_ROOT/{backend,frontend/src/components,tests,logs,data,scripts}
mkdir -p $PROJECT_ROOT/backend/{parsers,detectors,analytics,utils,api}
mkdir -p $PROJECT_ROOT/data/{sample_logs,baselines}

cd $PROJECT_ROOT

echo -e "${GREEN}✓ Directory structure created${NC}"

# Create backend requirements
cat > backend/requirements.txt << 'EOF'
fastapi==0.115.0
uvicorn==0.32.0
pydantic==2.9.0
redis==5.2.0
numpy==2.1.3
scipy==1.14.1
python-dateutil==2.9.0
aiofiles==24.1.0
websockets==13.1
EOF

echo -e "${GREEN}✓ Requirements file created${NC}"

# Create main backend application
cat > backend/main.py << 'EOF'
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import asyncio
import json
from datetime import datetime
from api.routes import router
from analytics.traffic_analyzer import TrafficAnalyzer
from detectors.threat_detector import ThreatDetector

app = FastAPI(title="Network Traffic Analysis System")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize components
traffic_analyzer = TrafficAnalyzer()
threat_detector = ThreatDetector()

app.include_router(router, prefix="/api")

# WebSocket for real-time updates
active_connections = []

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            await asyncio.sleep(1)
    except:
        active_connections.remove(websocket)

@app.on_event("startup")
async def startup_event():
    print("Starting Network Traffic Analysis System...")
    asyncio.create_task(stream_analysis())

async def stream_analysis():
    """Background task to analyze traffic and send updates"""
    while True:
        try:
            # Analyze recent traffic
            metrics = traffic_analyzer.get_current_metrics()
            threats = threat_detector.detect_threats(metrics)
            
            update = {
                "timestamp": datetime.now().isoformat(),
                "metrics": metrics,
                "threats": threats
            }
            
            # Broadcast to all connected clients
            for connection in active_connections:
                try:
                    await connection.send_json(update)
                except:
                    pass
                    
        except Exception as e:
            print(f"Analysis error: {e}")
        
        await asyncio.sleep(2)

@app.get("/")
async def root():
    return {"status": "Network Traffic Analysis System Running"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Create log parsers
cat > backend/parsers/syslog_parser.py << 'EOF'
import re
from datetime import datetime
from typing import Dict, Optional

class SyslogParser:
    """Parse syslog format network logs"""
    
    # Syslog pattern: <priority>timestamp hostname process: message
    SYSLOG_PATTERN = r'<(\d+)>(\w+\s+\d+\s+\d+:\d+:\d+)\s+(\S+)\s+(\S+):\s+(.*)'
    
    # Firewall log pattern
    FW_PATTERN = r'SRC=(\S+)\s+DST=(\S+)\s+.*PROTO=(\S+)\s+SPT=(\d+)\s+DPT=(\d+).*LEN=(\d+)'
    
    def parse(self, log_line: str) -> Optional[Dict]:
        """Parse a single log line"""
        try:
            # Match syslog format
            match = re.search(self.SYSLOG_PATTERN, log_line)
            if not match:
                return None
            
            priority, timestamp, hostname, process, message = match.groups()
            
            # Parse firewall message
            fw_match = re.search(self.FW_PATTERN, message)
            if not fw_match:
                return None
            
            src_ip, dst_ip, protocol, src_port, dst_port, length = fw_match.groups()
            
            return {
                "timestamp": datetime.now().isoformat(),
                "source_ip": src_ip,
                "dest_ip": dst_ip,
                "source_port": int(src_port),
                "dest_port": int(dst_port),
                "protocol": protocol,
                "bytes": int(length),
                "hostname": hostname,
                "action": "ACCEPT" if "ACCEPT" in message else "DROP"
            }
        except Exception as e:
            print(f"Parse error: {e}")
            return None

class JSONParser:
    """Parse JSON format logs (AWS VPC, GCP)"""
    
    def parse(self, log_line: str) -> Optional[Dict]:
        """Parse JSON log entry"""
        try:
            import json
            data = json.loads(log_line)
            
            return {
                "timestamp": data.get("timestamp", datetime.now().isoformat()),
                "source_ip": data.get("srcaddr", ""),
                "dest_ip": data.get("dstaddr", ""),
                "source_port": int(data.get("srcport", 0)),
                "dest_port": int(data.get("dstport", 0)),
                "protocol": data.get("protocol", "TCP"),
                "bytes": int(data.get("bytes", 0)),
                "action": data.get("action", "ACCEPT")
            }
        except:
            return None

class DNSParser:
    """Parse DNS query logs"""
    
    DNS_PATTERN = r'client\s+(\S+)#(\d+).*query:\s+(\S+)\s+IN\s+(\S+)'
    
    def parse(self, log_line: str) -> Optional[Dict]:
        """Parse DNS log entry"""
        try:
            match = re.search(self.DNS_PATTERN, log_line)
            if not match:
                return None
            
            client_ip, client_port, domain, record_type = match.groups()
            
            return {
                "timestamp": datetime.now().isoformat(),
                "source_ip": client_ip,
                "query_domain": domain,
                "query_type": record_type,
                "domain_length": len(domain)
            }
        except:
            return None
EOF

# Create threat detector
cat > backend/detectors/threat_detector.py << 'EOF'
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Dict, List
import math

class ThreatDetector:
    """Detect network security threats using pattern matching"""
    
    def __init__(self):
        self.connection_tracker = defaultdict(lambda: {
            "ports": set(),
            "connections": 0,
            "failed_auth": 0,
            "bytes_sent": 0,
            "last_seen": datetime.now()
        })
        self.dns_tracker = defaultdict(lambda: {
            "queries": [],
            "domains": set()
        })
        
    def detect_threats(self, metrics: Dict) -> List[Dict]:
        """Detect threats from traffic metrics"""
        threats = []
        
        # Port scan detection
        port_scan_threats = self._detect_port_scans(metrics.get("connections", []))
        threats.extend(port_scan_threats)
        
        # Brute force detection
        brute_force_threats = self._detect_brute_force(metrics.get("auth_attempts", []))
        threats.extend(brute_force_threats)
        
        # Data exfiltration detection
        exfil_threats = self._detect_exfiltration(metrics.get("data_transfers", []))
        threats.extend(exfil_threats)
        
        # DNS tunneling detection
        dns_threats = self._detect_dns_tunneling(metrics.get("dns_queries", []))
        threats.extend(dns_threats)
        
        return threats
    
    def _detect_port_scans(self, connections: List[Dict]) -> List[Dict]:
        """Detect port scanning activity"""
        threats = []
        port_tracker = defaultdict(set)
        
        # Track unique ports per source IP
        for conn in connections:
            src = conn.get("source_ip")
            port = conn.get("dest_port")
            if src and port:
                port_tracker[src].add(port)
        
        # Flag sources touching many ports
        for src_ip, ports in port_tracker.items():
            if len(ports) > 20:  # Threshold for port scan
                threat_score = min(100, 50 + len(ports))
                threats.append({
                    "type": "port_scan",
                    "source_ip": src_ip,
                    "threat_score": threat_score,
                    "details": f"Scanned {len(ports)} ports",
                    "severity": "critical" if threat_score > 80 else "high",
                    "timestamp": datetime.now().isoformat()
                })
        
        return threats
    
    def _detect_brute_force(self, auth_attempts: List[Dict]) -> List[Dict]:
        """Detect brute force authentication attempts"""
        threats = []
        failure_tracker = defaultdict(int)
        
        for attempt in auth_attempts:
            if not attempt.get("success"):
                src = attempt.get("source_ip")
                failure_tracker[src] += 1
        
        for src_ip, failures in failure_tracker.items():
            if failures > 10:  # Threshold for brute force
                threats.append({
                    "type": "brute_force",
                    "source_ip": src_ip,
                    "threat_score": min(100, 60 + failures * 2),
                    "details": f"{failures} failed authentication attempts",
                    "severity": "critical",
                    "timestamp": datetime.now().isoformat()
                })
        
        return threats
    
    def _detect_exfiltration(self, transfers: List[Dict]) -> List[Dict]:
        """Detect unusual data exfiltration"""
        threats = []
        upload_tracker = defaultdict(int)
        
        for transfer in transfers:
            if transfer.get("direction") == "outbound":
                src = transfer.get("source_ip")
                bytes_sent = transfer.get("bytes", 0)
                upload_tracker[src] += bytes_sent
        
        # Check for unusual upload volumes (>100MB)
        for src_ip, total_bytes in upload_tracker.items():
            mb_uploaded = total_bytes / (1024 * 1024)
            if mb_uploaded > 100:
                threats.append({
                    "type": "data_exfiltration",
                    "source_ip": src_ip,
                    "threat_score": min(100, 70 + int(mb_uploaded / 10)),
                    "details": f"Uploaded {mb_uploaded:.2f}MB",
                    "severity": "high",
                    "timestamp": datetime.now().isoformat()
                })
        
        return threats
    
    def _detect_dns_tunneling(self, dns_queries: List[Dict]) -> List[Dict]:
        """Detect DNS tunneling attempts"""
        threats = []
        
        for query in dns_queries:
            domain = query.get("query_domain", "")
            
            # Check domain length (tunneling uses long subdomains)
            if len(domain) > 50:
                entropy = self._calculate_entropy(domain)
                
                # High entropy + long domain = likely tunneling
                if entropy > 3.5:
                    threats.append({
                        "type": "dns_tunneling",
                        "source_ip": query.get("source_ip"),
                        "domain": domain,
                        "threat_score": 75,
                        "details": f"Suspicious DNS query: entropy={entropy:.2f}, length={len(domain)}",
                        "severity": "medium",
                        "timestamp": datetime.now().isoformat()
                    })
        
        return threats
    
    def _calculate_entropy(self, text: str) -> float:
        """Calculate Shannon entropy of a string"""
        if not text:
            return 0.0
        
        # Calculate character frequency
        freq = defaultdict(int)
        for char in text.lower():
            if char.isalnum():
                freq[char] += 1
        
        # Calculate entropy
        length = sum(freq.values())
        entropy = 0.0
        for count in freq.values():
            p = count / length
            entropy -= p * math.log2(p)
        
        return entropy
EOF

# Create traffic analyzer
cat > backend/analytics/traffic_analyzer.py << 'EOF'
from collections import defaultdict, deque
from datetime import datetime, timedelta
from typing import Dict, List
import random

class TrafficAnalyzer:
    """Analyze network traffic patterns and compute metrics"""
    
    def __init__(self, window_size=300):  # 5-minute window
        self.window_size = window_size
        self.connections = deque(maxlen=10000)
        self.metrics_history = deque(maxlen=100)
        self.baselines = {}
        
    def add_connection(self, connection: Dict):
        """Add a connection to the analysis window"""
        connection["timestamp"] = datetime.now()
        self.connections.append(connection)
    
    def get_current_metrics(self) -> Dict:
        """Calculate current traffic metrics"""
        now = datetime.now()
        window_start = now - timedelta(seconds=self.window_size)
        
        # Filter to current window
        recent = [c for c in self.connections if c.get("timestamp", now) > window_start]
        
        # Calculate metrics
        total_connections = len(recent)
        unique_sources = len(set(c.get("source_ip") for c in recent if c.get("source_ip")))
        unique_dests = len(set(c.get("dest_ip") for c in recent if c.get("dest_ip")))
        total_bytes = sum(c.get("bytes", 0) for c in recent)
        
        # Protocol distribution
        protocols = defaultdict(int)
        for conn in recent:
            proto = conn.get("protocol", "UNKNOWN")
            protocols[proto] += 1
        
        # Port distribution
        ports = defaultdict(int)
        for conn in recent:
            port = conn.get("dest_port")
            if port:
                ports[port] += 1
        
        # Top talkers
        src_bytes = defaultdict(int)
        for conn in recent:
            src = conn.get("source_ip")
            if src:
                src_bytes[src] += conn.get("bytes", 0)
        
        top_talkers = sorted(src_bytes.items(), key=lambda x: x[1], reverse=True)[:10]
        
        metrics = {
            "timestamp": now.isoformat(),
            "total_connections": total_connections,
            "unique_sources": unique_sources,
            "unique_destinations": unique_dests,
            "total_bytes": total_bytes,
            "connections_per_second": total_connections / self.window_size if self.window_size > 0 else 0,
            "bytes_per_second": total_bytes / self.window_size if self.window_size > 0 else 0,
            "protocols": dict(protocols),
            "top_ports": dict(sorted(ports.items(), key=lambda x: x[1], reverse=True)[:10]),
            "top_talkers": [{"ip": ip, "bytes": bytes} for ip, bytes in top_talkers],
            "connections": recent[-100:],  # Last 100 for pattern detection
            "auth_attempts": self._generate_auth_attempts(),
            "data_transfers": self._generate_data_transfers(recent),
            "dns_queries": self._generate_dns_queries()
        }
        
        self.metrics_history.append(metrics)
        return metrics
    
    def _generate_auth_attempts(self) -> List[Dict]:
        """Generate authentication attempts for demo"""
        attempts = []
        # Simulate normal and failed auth attempts
        for _ in range(random.randint(5, 15)):
            attempts.append({
                "source_ip": f"192.168.1.{random.randint(1, 254)}",
                "success": random.random() > 0.1,  # 90% success rate
                "timestamp": datetime.now().isoformat()
            })
        return attempts
    
    def _generate_data_transfers(self, connections: List[Dict]) -> List[Dict]:
        """Extract data transfer information"""
        transfers = []
        for conn in connections:
            if conn.get("bytes", 0) > 1000:  # Only significant transfers
                transfers.append({
                    "source_ip": conn.get("source_ip"),
                    "dest_ip": conn.get("dest_ip"),
                    "bytes": conn.get("bytes"),
                    "direction": "outbound" if conn.get("source_ip", "").startswith("192.168") else "inbound",
                    "timestamp": conn.get("timestamp", datetime.now()).isoformat()
                })
        return transfers
    
    def _generate_dns_queries(self) -> List[Dict]:
        """Generate DNS queries for demo"""
        queries = []
        normal_domains = ["google.com", "facebook.com", "amazon.com", "github.com"]
        
        # Add normal queries
        for _ in range(random.randint(10, 20)):
            queries.append({
                "source_ip": f"192.168.1.{random.randint(1, 254)}",
                "query_domain": random.choice(normal_domains),
                "timestamp": datetime.now().isoformat()
            })
        
        # Occasionally add suspicious query
        if random.random() < 0.1:
            suspicious_domain = "".join(random.choices("abcdefghijklmnopqrstuvwxyz0123456789", k=60)) + ".evil.com"
            queries.append({
                "source_ip": f"192.168.1.{random.randint(1, 254)}",
                "query_domain": suspicious_domain,
                "timestamp": datetime.now().isoformat()
            })
        
        return queries
    
    def calculate_baseline(self):
        """Calculate baseline metrics from historical data"""
        if len(self.metrics_history) < 10:
            return {}
        
        # Calculate averages
        total_conns = [m["total_connections"] for m in self.metrics_history]
        total_bytes_list = [m["total_bytes"] for m in self.metrics_history]
        
        import numpy as np
        
        self.baselines = {
            "connections_mean": np.mean(total_conns),
            "connections_std": np.std(total_conns),
            "bytes_mean": np.mean(total_bytes_list),
            "bytes_std": np.std(total_bytes_list)
        }
        
        return self.baselines
EOF

# Create API routes
cat > backend/api/routes.py << 'EOF'
from fastapi import APIRouter
from typing import Dict, List
from datetime import datetime
import random

router = APIRouter()

# Simulate traffic data
traffic_data = []

@router.get("/metrics")
async def get_metrics() -> Dict:
    """Get current traffic metrics"""
    return {
        "timestamp": datetime.now().isoformat(),
        "connections": random.randint(200, 500),
        "threats": random.randint(0, 5),
        "bytes_transferred": random.randint(1000000, 5000000),
        "unique_ips": random.randint(50, 150)
    }

@router.get("/threats")
async def get_threats() -> List[Dict]:
    """Get detected threats"""
    threats = []
    
    # Simulate threats
    if random.random() < 0.3:
        threats.append({
            "type": "port_scan",
            "source_ip": f"192.168.1.{random.randint(1, 254)}",
            "threat_score": random.randint(70, 95),
            "severity": "critical",
            "timestamp": datetime.now().isoformat()
        })
    
    return threats

@router.get("/topology")
async def get_topology() -> Dict:
    """Get network topology data"""
    nodes = []
    edges = []
    
    # Generate sample topology
    for i in range(10):
        nodes.append({
            "id": f"192.168.1.{i+1}",
            "label": f"Host-{i+1}",
            "threat_score": random.randint(0, 100)
        })
    
    for i in range(15):
        edges.append({
            "source": f"192.168.1.{random.randint(1, 10)}",
            "target": f"192.168.1.{random.randint(1, 10)}",
            "bytes": random.randint(1000, 100000)
        })
    
    return {"nodes": nodes, "edges": edges}

@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}
EOF

# Create sample log generator
cat > scripts/generate_logs.py << 'EOF'
#!/usr/bin/env python3
"""Generate sample network traffic logs"""

import random
import time
from datetime import datetime

def generate_firewall_log():
    """Generate syslog format firewall log"""
    src_ip = f"192.168.1.{random.randint(1, 254)}"
    dst_ip = f"{random.randint(1, 223)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}"
    protocol = random.choice(["TCP", "UDP", "ICMP"])
    src_port = random.randint(1024, 65535)
    dst_port = random.choice([80, 443, 22, 53, 3306, 5432, random.randint(1, 65535)])
    length = random.randint(40, 1500)
    action = random.choice(["ACCEPT", "ACCEPT", "ACCEPT", "DROP"])
    
    timestamp = datetime.now().strftime("%b %d %H:%M:%S")
    
    log = f"<134>{timestamp} firewall kernel: [FILTER] SRC={src_ip} DST={dst_ip} PROTO={protocol} SPT={src_port} DPT={dst_port} LEN={length} {action}"
    return log

def generate_port_scan():
    """Generate port scan traffic"""
    src_ip = f"10.0.0.{random.randint(1, 254)}"
    dst_ip = "192.168.1.100"
    
    logs = []
    for port in random.sample(range(1, 65535), 50):
        timestamp = datetime.now().strftime("%b %d %H:%M:%S")
        log = f"<134>{timestamp} firewall kernel: [FILTER] SRC={src_ip} DST={dst_ip} PROTO=TCP SPT={random.randint(50000, 60000)} DPT={port} LEN=60 DROP"
        logs.append(log)
    
    return logs

def main():
    print("Generating network traffic logs...")
    print("Press Ctrl+C to stop\n")
    
    try:
        while True:
            # Generate normal traffic
            for _ in range(10):
                print(generate_firewall_log())
                time.sleep(0.1)
            
            # Occasionally generate port scan
            if random.random() < 0.05:
                print("\n--- Port Scan Detected ---")
                for log in generate_port_scan():
                    print(log)
                print("--- End Port Scan ---\n")
            
            time.sleep(1)
    
    except KeyboardInterrupt:
        print("\nLog generation stopped")

if __name__ == "__main__":
    main()
EOF

chmod +x scripts/generate_logs.py

# Create frontend package.json
cat > frontend/package.json << 'EOF'
{
  "name": "network-traffic-analysis",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "recharts": "^2.13.3",
    "react-force-graph-2d": "^1.25.4"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "vite": "^6.0.3"
  }
}
EOF

# Create Vite config
cat > frontend/vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true
      },
      '/ws': {
        target: 'ws://localhost:8000',
        ws: true
      }
    }
  }
})
EOF

# Create index.html
cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Network Traffic Analysis</title>
</head>
<body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
</body>
</html>
EOF

# Create main React app
cat > frontend/src/main.jsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
EOF

# Create CSS
cat > frontend/src/index.css << 'EOF'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #333;
}

#root {
  min-height: 100vh;
}
EOF

# Create main App component
cat > frontend/src/App.jsx << 'EOF'
import React, { useState, useEffect } from 'react';
import Dashboard from './components/Dashboard';
import ThreatList from './components/ThreatList';
import TrafficGraph from './components/TrafficGraph';
import MetricsPanel from './components/MetricsPanel';
import './App.css';

function App() {
  const [metrics, setMetrics] = useState(null);
  const [threats, setThreats] = useState([]);
  const [topology, setTopology] = useState({ nodes: [], edges: [] });
  const [wsConnected, setWsConnected] = useState(false);

  useEffect(() => {
    // Connect to WebSocket
    const ws = new WebSocket('ws://localhost:8000/ws');
    
    ws.onopen = () => {
      console.log('WebSocket connected');
      setWsConnected(true);
    };
    
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      setMetrics(data.metrics);
      setThreats(data.threats || []);
    };
    
    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
      setWsConnected(false);
    };
    
    ws.onclose = () => {
      console.log('WebSocket disconnected');
      setWsConnected(false);
    };
    
    // Fetch initial topology
    fetchTopology();
    
    // Poll for topology updates
    const interval = setInterval(fetchTopology, 10000);
    
    return () => {
      ws.close();
      clearInterval(interval);
    };
  }, []);
  
  const fetchTopology = async () => {
    try {
      const response = await fetch('http://localhost:8000/api/topology');
      const data = await response.json();
      setTopology(data);
    } catch (error) {
      console.error('Failed to fetch topology:', error);
    }
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>🛡️ Network Traffic Analysis System</h1>
        <div className="status">
          <span className={wsConnected ? 'status-connected' : 'status-disconnected'}>
            {wsConnected ? '● Live' : '○ Disconnected'}
          </span>
        </div>
      </header>
      
      <div className="app-content">
        <MetricsPanel metrics={metrics} />
        
        <div className="main-grid">
          <div className="chart-section">
            <Dashboard metrics={metrics} />
          </div>
          
          <div className="threat-section">
            <ThreatList threats={threats} />
          </div>
        </div>
        
        <div className="topology-section">
          <TrafficGraph topology={topology} threats={threats} />
        </div>
      </div>
    </div>
  );
}

export default App;
EOF

# Create App CSS
cat > frontend/src/App.css << 'EOF'
.app {
  min-height: 100vh;
  padding: 20px;
}

.app-header {
  background: white;
  padding: 20px 30px;
  border-radius: 12px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  margin-bottom: 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.app-header h1 {
  font-size: 28px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.status {
  font-size: 14px;
  font-weight: 600;
}

.status-connected {
  color: #10b981;
}

.status-disconnected {
  color: #ef4444;
}

.app-content {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.main-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 20px;
}

.chart-section, .threat-section, .topology-section {
  background: white;
  padding: 20px;
  border-radius: 12px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

@media (max-width: 1024px) {
  .main-grid {
    grid-template-columns: 1fr;
  }
}
EOF

# Create MetricsPanel component
cat > frontend/src/components/MetricsPanel.jsx << 'EOF'
import React from 'react';
import './MetricsPanel.css';

function MetricsPanel({ metrics }) {
  if (!metrics) {
    return <div className="metrics-panel">Loading...</div>;
  }
  
  const formatBytes = (bytes) => {
    if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(2) + ' GB';
    if (bytes >= 1048576) return (bytes / 1048576).toFixed(2) + ' MB';
    if (bytes >= 1024) return (bytes / 1024).toFixed(2) + ' KB';
    return bytes + ' B';
  };
  
  return (
    <div className="metrics-panel">
      <div className="metric-card">
        <div className="metric-icon">🔗</div>
        <div className="metric-content">
          <div className="metric-value">{metrics.total_connections || 0}</div>
          <div className="metric-label">Total Connections</div>
        </div>
      </div>
      
      <div className="metric-card">
        <div className="metric-icon">📊</div>
        <div className="metric-content">
          <div className="metric-value">{(metrics.connections_per_second || 0).toFixed(1)}/s</div>
          <div className="metric-label">Connections Rate</div>
        </div>
      </div>
      
      <div className="metric-card">
        <div className="metric-icon">💾</div>
        <div className="metric-content">
          <div className="metric-value">{formatBytes(metrics.total_bytes || 0)}</div>
          <div className="metric-label">Total Traffic</div>
        </div>
      </div>
      
      <div className="metric-card">
        <div className="metric-icon">🌐</div>
        <div className="metric-content">
          <div className="metric-value">{metrics.unique_sources || 0}</div>
          <div className="metric-label">Unique Sources</div>
        </div>
      </div>
    </div>
  );
}

export default MetricsPanel;
EOF

# Create MetricsPanel CSS
cat > frontend/src/components/MetricsPanel.css << 'EOF'
.metrics-panel {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 15px;
  margin-bottom: 20px;
}

.metric-card {
  background: white;
  padding: 20px;
  border-radius: 12px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: center;
  gap: 15px;
  transition: transform 0.2s;
}

.metric-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

.metric-icon {
  font-size: 32px;
  width: 60px;
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 50%;
}

.metric-content {
  flex: 1;
}

.metric-value {
  font-size: 24px;
  font-weight: 700;
  color: #1f2937;
  line-height: 1.2;
}

.metric-label {
  font-size: 13px;
  color: #6b7280;
  margin-top: 4px;
}
EOF

# Create Dashboard component
cat > frontend/src/components/Dashboard.jsx << 'EOF'
import React, { useState, useEffect } from 'react';
import { LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import './Dashboard.css';

function Dashboard({ metrics }) {
  const [chartData, setChartData] = useState([]);
  const [protocolData, setProtocolData] = useState([]);
  
  useEffect(() => {
    if (metrics) {
      // Update time series data
      setChartData(prev => {
        const newData = [...prev, {
          time: new Date(metrics.timestamp).toLocaleTimeString(),
          connections: metrics.total_connections,
          bytes: Math.round(metrics.total_bytes / 1024)
        }];
        return newData.slice(-20); // Keep last 20 points
      });
      
      // Update protocol distribution
      if (metrics.protocols) {
        const data = Object.entries(metrics.protocols).map(([name, value]) => ({
          name,
          value
        }));
        setProtocolData(data);
      }
    }
  }, [metrics]);
  
  const COLORS = ['#667eea', '#764ba2', '#f093fb', '#4facfe', '#43e97b'];
  
  return (
    <div className="dashboard">
      <h2>Traffic Analytics</h2>
      
      <div className="chart-grid">
        <div className="chart-container">
          <h3>Connection Rate Over Time</h3>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="connections" stroke="#667eea" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>
        
        <div className="chart-container">
          <h3>Protocol Distribution</h3>
          <ResponsiveContainer width="100%" height={250}>
            <PieChart>
              <Pie
                data={protocolData}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
              >
                {protocolData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}

export default Dashboard;
EOF

# Create Dashboard CSS
cat > frontend/src/components/Dashboard.css << 'EOF'
.dashboard h2 {
  font-size: 22px;
  margin-bottom: 20px;
  color: #1f2937;
}

.chart-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 20px;
}

.chart-container {
  background: #f9fafb;
  padding: 15px;
  border-radius: 8px;
}

.chart-container h3 {
  font-size: 16px;
  margin-bottom: 15px;
  color: #374151;
}
EOF

# Create ThreatList component
cat > frontend/src/components/ThreatList.jsx << 'EOF'
import React from 'react';
import './ThreatList.css';

function ThreatList({ threats }) {
  const getSeverityClass = (severity) => {
    switch (severity) {
      case 'critical': return 'severity-critical';
      case 'high': return 'severity-high';
      case 'medium': return 'severity-medium';
      default: return 'severity-low';
    }
  };
  
  const getSeverityIcon = (severity) => {
    switch (severity) {
      case 'critical': return '🔴';
      case 'high': return '🟠';
      case 'medium': return '🟡';
      default: return '🟢';
    }
  };
  
  return (
    <div className="threat-list">
      <h2>🚨 Active Threats</h2>
      
      {threats.length === 0 ? (
        <div className="no-threats">
          <p>✅ No active threats detected</p>
        </div>
      ) : (
        <div className="threats-container">
          {threats.map((threat, index) => (
            <div key={index} className={`threat-card ${getSeverityClass(threat.severity)}`}>
              <div className="threat-header">
                <span className="threat-icon">{getSeverityIcon(threat.severity)}</span>
                <span className="threat-type">{threat.type.replace('_', ' ').toUpperCase()}</span>
                <span className="threat-score">{threat.threat_score}/100</span>
              </div>
              <div className="threat-details">
                <p><strong>Source:</strong> {threat.source_ip}</p>
                <p><strong>Details:</strong> {threat.details}</p>
                <p className="threat-time">
                  {new Date(threat.timestamp).toLocaleTimeString()}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default ThreatList;
EOF

# Create ThreatList CSS
cat > frontend/src/components/ThreatList.css << 'EOF'
.threat-list h2 {
  font-size: 22px;
  margin-bottom: 20px;
  color: #1f2937;
}

.no-threats {
  text-align: center;
  padding: 40px;
  color: #10b981;
  font-size: 18px;
}

.threats-container {
  display: flex;
  flex-direction: column;
  gap: 12px;
  max-height: 500px;
  overflow-y: auto;
}

.threat-card {
  padding: 15px;
  border-radius: 8px;
  border-left: 4px solid;
  background: #f9fafb;
  transition: transform 0.2s;
}

.threat-card:hover {
  transform: translateX(4px);
}

.severity-critical {
  border-left-color: #dc2626;
  background: #fef2f2;
}

.severity-high {
  border-left-color: #f97316;
  background: #fff7ed;
}

.severity-medium {
  border-left-color: #eab308;
  background: #fefce8;
}

.threat-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
}

.threat-icon {
  font-size: 20px;
}

.threat-type {
  flex: 1;
  font-weight: 700;
  font-size: 14px;
  color: #1f2937;
}

.threat-score {
  background: #1f2937;
  color: white;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}

.threat-details {
  font-size: 13px;
  color: #4b5563;
  line-height: 1.6;
}

.threat-details p {
  margin: 4px 0;
}

.threat-time {
  margin-top: 8px;
  font-size: 11px;
  color: #9ca3af;
  font-style: italic;
}
EOF

# Create TrafficGraph component
cat > frontend/src/components/TrafficGraph.jsx << 'EOF'
import React, { useEffect, useRef } from 'react';
import './TrafficGraph.css';

function TrafficGraph({ topology, threats }) {
  const canvasRef = useRef(null);
  
  useEffect(() => {
    if (!canvasRef.current || !topology.nodes.length) return;
    
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    const width = canvas.width = canvas.offsetWidth;
    const height = canvas.height = canvas.offsetHeight;
    
    // Clear canvas
    ctx.clearRect(0, 0, width, height);
    
    // Create threat lookup
    const threatMap = new Map();
    threats.forEach(threat => {
      threatMap.set(threat.source_ip, threat.threat_score);
    });
    
    // Position nodes in a circle
    const centerX = width / 2;
    const centerY = height / 2;
    const radius = Math.min(width, height) * 0.35;
    
    const nodePositions = new Map();
    topology.nodes.forEach((node, i) => {
      const angle = (i / topology.nodes.length) * 2 * Math.PI;
      const x = centerX + radius * Math.cos(angle);
      const y = centerY + radius * Math.sin(angle);
      nodePositions.set(node.id, { x, y });
    });
    
    // Draw edges
    ctx.strokeStyle = '#e5e7eb';
    ctx.lineWidth = 1;
    topology.edges.forEach(edge => {
      const source = nodePositions.get(edge.source);
      const target = nodePositions.get(edge.target);
      if (source && target) {
        const lineWidth = Math.min(5, Math.max(1, edge.bytes / 20000));
        ctx.lineWidth = lineWidth;
        ctx.beginPath();
        ctx.moveTo(source.x, source.y);
        ctx.lineTo(target.x, target.y);
        ctx.stroke();
      }
    });
    
    // Draw nodes
    topology.nodes.forEach(node => {
      const pos = nodePositions.get(node.id);
      if (!pos) return;
      
      const threatScore = threatMap.get(node.id) || 0;
      const nodeRadius = 20;
      
      // Node color based on threat
      if (threatScore > 70) {
        ctx.fillStyle = '#dc2626';
      } else if (threatScore > 40) {
        ctx.fillStyle = '#f97316';
      } else {
        ctx.fillStyle = '#10b981';
      }
      
      // Draw node
      ctx.beginPath();
      ctx.arc(pos.x, pos.y, nodeRadius, 0, 2 * Math.PI);
      ctx.fill();
      ctx.strokeStyle = 'white';
      ctx.lineWidth = 2;
      ctx.stroke();
      
      // Draw label
      ctx.fillStyle = '#1f2937';
      ctx.font = '11px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(node.label, pos.x, pos.y + nodeRadius + 15);
    });
    
    // Draw legend
    ctx.fillStyle = '#1f2937';
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText('● Low Risk', 20, height - 60);
    ctx.fillStyle = '#f97316';
    ctx.fillText('● Medium Risk', 20, height - 40);
    ctx.fillStyle = '#dc2626';
    ctx.fillText('● High Risk', 20, height - 20);
    
  }, [topology, threats]);
  
  return (
    <div className="traffic-graph">
      <h2>🌐 Network Topology</h2>
      <canvas ref={canvasRef} className="topology-canvas"></canvas>
    </div>
  );
}

export default TrafficGraph;
EOF

# Create TrafficGraph CSS
cat > frontend/src/components/TrafficGraph.css << 'EOF'
.traffic-graph {
  min-height: 400px;
}

.traffic-graph h2 {
  font-size: 22px;
  margin-bottom: 20px;
  color: #1f2937;
}

.topology-canvas {
  width: 100%;
  height: 400px;
  border-radius: 8px;
  background: #f9fafb;
}
EOF

# Create test file
cat > tests/test_traffic_analysis.py << 'EOF'
"""
Test suite for network traffic analysis system
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))

from parsers.syslog_parser import SyslogParser, JSONParser, DNSParser
from detectors.threat_detector import ThreatDetector
from analytics.traffic_analyzer import TrafficAnalyzer

def test_syslog_parser():
    """Test syslog parsing"""
    parser = SyslogParser()
    log = "<134>Jan 30 10:15:30 firewall kernel: [FILTER] SRC=192.168.1.10 DST=8.8.8.8 PROTO=TCP SPT=50000 DPT=53 LEN=60 ACCEPT"
    
    result = parser.parse(log)
    assert result is not None, "Failed to parse syslog"
    assert result["source_ip"] == "192.168.1.10", "Incorrect source IP"
    assert result["dest_ip"] == "8.8.8.8", "Incorrect dest IP"
    assert result["dest_port"] == 53, "Incorrect port"
    print("✓ Syslog parser test passed")

def test_port_scan_detection():
    """Test port scan detection"""
    detector = ThreatDetector()
    
    # Simulate port scan
    connections = []
    for port in range(1, 51):
        connections.append({
            "source_ip": "10.0.0.100",
            "dest_port": port,
            "bytes": 60
        })
    
    metrics = {"connections": connections}
    threats = detector.detect_threats(metrics)
    
    port_scan_threats = [t for t in threats if t["type"] == "port_scan"]
    assert len(port_scan_threats) > 0, "Failed to detect port scan"
    assert port_scan_threats[0]["threat_score"] >= 70, "Threat score too low"
    print("✓ Port scan detection test passed")

def test_dns_tunneling_detection():
    """Test DNS tunneling detection"""
    detector = ThreatDetector()
    
    # Suspicious DNS query
    queries = [{
        "source_ip": "192.168.1.50",
        "query_domain": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0.evil.com"
    }]
    
    metrics = {"dns_queries": queries, "connections": [], "auth_attempts": [], "data_transfers": []}
    threats = detector.detect_threats(metrics)
    
    dns_threats = [t for t in threats if t["type"] == "dns_tunneling"]
    assert len(dns_threats) > 0, "Failed to detect DNS tunneling"
    print("✓ DNS tunneling detection test passed")

def test_traffic_analyzer():
    """Test traffic analyzer metrics"""
    analyzer = TrafficAnalyzer()
    
    # Add sample connections
    for i in range(100):
        analyzer.add_connection({
            "source_ip": f"192.168.1.{i % 50}",
            "dest_ip": "8.8.8.8",
            "dest_port": 443,
            "bytes": 1000,
            "protocol": "TCP"
        })
    
    metrics = analyzer.get_current_metrics()
    assert metrics["total_connections"] == 100, "Incorrect connection count"
    assert metrics["unique_sources"] > 0, "No unique sources detected"
    print("✓ Traffic analyzer test passed")

def run_all_tests():
    """Run all tests"""
    print("\n" + "="*50)
    print("Running Network Traffic Analysis Tests")
    print("="*50 + "\n")
    
    try:
        test_syslog_parser()
        test_port_scan_detection()
        test_dns_tunneling_detection()
        test_traffic_analyzer()
        
        print("\n" + "="*50)
        print("✅ All tests passed!")
        print("="*50 + "\n")
        return True
    except AssertionError as e:
        print(f"\n❌ Test failed: {e}\n")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy backend files
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./backend/
COPY scripts/ ./scripts/

# Expose port
EXPOSE 8000

CMD ["python", "-m", "uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
node_modules
frontend/node_modules
frontend/dist
__pycache__
*.pyc
.git
.env
venv
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  backend:
    build: .
    ports:
      - "8000:8000"
    environment:
      - PYTHONUNBUFFERED=1
    volumes:
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
      interval: 10s
      timeout: 5s
      retries: 3

  frontend:
    image: node:20-slim
    working_dir: /app
    ports:
      - "3000:3000"
    volumes:
      - ./frontend:/app
    command: sh -c "npm install && npm run dev -- --host"
    depends_on:
      - backend
EOF

echo -e "${GREEN}✓ All files created${NC}"

# Create start.sh script
cat > start.sh << 'EOF'
#!/bin/bash

echo "========================================="
echo "Starting Network Traffic Analysis System"
echo "========================================="

# Check if Python 3.11 is available
if ! command -v python3.11 &> /dev/null; then
    echo "Python 3.11 not found. Using default python3..."
    PYTHON_CMD=python3
else
    PYTHON_CMD=python3.11
fi

# Create and activate virtual environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv venv
fi

source venv/bin/activate

# Install backend dependencies
echo "Installing backend dependencies..."
pip install -q --upgrade pip
pip install -q -r backend/requirements.txt

# Install frontend dependencies
echo "Installing frontend dependencies..."
cd frontend
npm install --silent
cd ..

# Run tests
echo ""
echo "Running tests..."
$PYTHON_CMD tests/test_traffic_analysis.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ All tests passed!"
    echo ""
    
    # Start backend
    echo "Starting backend server on http://localhost:8000..."
    $PYTHON_CMD -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 &
    BACKEND_PID=$!
    
    # Wait for backend to start
    sleep 3
    
    # Start frontend
    echo "Starting frontend on http://localhost:3000..."
    cd frontend
    npm run dev &
    FRONTEND_PID=$!
    cd ..
    
    echo ""
    echo "========================================="
    echo "✅ System started successfully!"
    echo "========================================="
    echo ""
    echo "🌐 Dashboard: http://localhost:3000"
    echo "🔌 API: http://localhost:8000"
    echo "📊 API Docs: http://localhost:8000/docs"
    echo ""
    echo "Press Ctrl+C to stop..."
    echo ""
    
    # Save PIDs
    echo $BACKEND_PID > .backend.pid
    echo $FRONTEND_PID > .frontend.pid
    
    # Wait for both processes
    wait $BACKEND_PID $FRONTEND_PID
else
    echo "❌ Tests failed. Please fix errors before starting."
    exit 1
fi
EOF

chmod +x start.sh

# Create stop.sh script
cat > stop.sh << 'EOF'
#!/bin/bash

echo "Stopping Network Traffic Analysis System..."

if [ -f .backend.pid ]; then
    kill $(cat .backend.pid) 2>/dev/null
    rm .backend.pid
fi

if [ -f .frontend.pid ]; then
    kill $(cat .frontend.pid) 2>/dev/null
    rm .frontend.pid
fi

# Kill any remaining processes
pkill -f "uvicorn backend.main:app"
pkill -f "vite"

echo "✓ System stopped"
EOF

chmod +x stop.sh

cd $PROJECT_ROOT

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Project created at:${NC} $PROJECT_ROOT"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. cd $PROJECT_ROOT"
echo "  2. ./start.sh          # Start the system"
echo "  3. Open http://localhost:3000"
echo ""
echo -e "${YELLOW}Or use Docker:${NC}"
echo "  docker-compose up --build"
echo ""
echo -e "${YELLOW}To stop:${NC}"
echo "  ./stop.sh"
echo ""
echo -e "${GREEN}Features:${NC}"
echo "  ✓ Real-time traffic monitoring"
echo "  ✓ Port scan detection"
echo "  ✓ Brute force detection"
echo "  ✓ DNS tunneling detection"
echo "  ✓ Network topology visualization"
echo "  ✓ Live threat alerts"
echo ""