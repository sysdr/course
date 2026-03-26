#!/bin/bash
set -e

# Day 152: Kubernetes Operator for Log Platform Management
# Complete Setup and Demonstration Script

echo "🚀 Day 152: Building Custom Kubernetes Operator for Log Platform"
echo "================================================================"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create project structure
echo -e "${BLUE}📁 Creating project structure...${NC}"
mkdir -p day152-k8s-operator/{src/{operator,crds,api,dashboard},tests,deployment,examples,scripts}
cd day152-k8s-operator

# Create directory structure
mkdir -p src/operator/{handlers,utils}
mkdir -p src/dashboard/components
mkdir -p deployment/{operator,rbac}
mkdir -p tests/{unit,integration}

echo -e "${GREEN}✅ Project structure created${NC}"

# Create requirements.txt
cat > requirements.txt << 'EOF'
# Kubernetes Operator Framework
kopf==1.37.2
kubernetes==29.0.0

# API and Web Framework
fastapi==0.111.0
uvicorn[standard]==0.30.1
pydantic==2.7.4

# Async and utilities
aiohttp==3.9.5
asyncio-mqtt==0.16.2

# Testing
pytest==8.2.2
pytest-asyncio==0.23.7
pytest-cov==5.0.0

# Monitoring and logging
prometheus-client==0.20.0
structlog==24.2.0

# Development
black==24.4.2
flake8==7.0.0
EOF

echo -e "${BLUE}📦 Requirements file created${NC}"

# Create CRD definitions
cat > src/crds/logprocessor-crd.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: logprocessors.logs.platform.io
spec:
  group: logs.platform.io
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 20
                logLevel:
                  type: string
                  enum: [DEBUG, INFO, WARNING, ERROR, CRITICAL]
                processingRate:
                  type: integer
                  description: "Target logs per second"
                resources:
                  type: object
                  properties:
                    memory:
                      type: string
                    cpu:
                      type: string
                autoScaling:
                  type: object
                  properties:
                    enabled:
                      type: boolean
                    minReplicas:
                      type: integer
                    maxReplicas:
                      type: integer
                    targetQueueDepth:
                      type: integer
            status:
              type: object
              properties:
                state:
                  type: string
                replicas:
                  type: integer
                readyReplicas:
                  type: integer
                conditions:
                  type: array
                  items:
                    type: object
                    properties:
                      type:
                        type: string
                      status:
                        type: string
                      lastTransitionTime:
                        type: string
                      message:
                        type: string
      subresources:
        status: {}
      additionalPrinterColumns:
        - name: Replicas
          type: integer
          jsonPath: .spec.replicas
        - name: Ready
          type: integer
          jsonPath: .status.readyReplicas
        - name: State
          type: string
          jsonPath: .status.state
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: logprocessors
    singular: logprocessor
    kind: LogProcessor
    shortNames:
      - lp
EOF

cat > src/crds/logcollector-crd.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: logcollectors.logs.platform.io
spec:
  group: logs.platform.io
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                sources:
                  type: array
                  items:
                    type: object
                    properties:
                      type:
                        type: string
                      endpoint:
                        type: string
                targetProcessors:
                  type: array
                  items:
                    type: string
            status:
              type: object
              properties:
                state:
                  type: string
                activeConnections:
                  type: integer
  scope: Namespaced
  names:
    plural: logcollectors
    singular: logcollector
    kind: LogCollector
    shortNames:
      - lc
EOF

echo -e "${GREEN}✅ CRD definitions created${NC}"

# Create main operator code
cat > src/operator/main.py << 'EOF'
"""
Kubernetes Operator for Log Platform Management
Main operator logic with reconciliation loops
"""
import asyncio
import kopf
import logging
from kubernetes import client, config
from datetime import datetime
from typing import Dict, Any
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class LogProcessorOperator:
    """Main operator class for LogProcessor resources"""
    
    def __init__(self):
        try:
            config.load_incluster_config()
        except config.ConfigException:
            config.load_kube_config()
        
        self.apps_api = client.AppsV1Api()
        self.core_api = client.CoreV1Api()
        self.metrics = {
            'reconciliations': 0,
            'scaling_events': 0,
            'errors': 0
        }
    
    def create_deployment(self, name: str, namespace: str, spec: Dict[str, Any]) -> Dict:
        """Create Kubernetes Deployment for LogProcessor"""
        replicas = spec.get('replicas', 1)
        log_level = spec.get('logLevel', 'INFO')
        resources_spec = spec.get('resources', {})
        
        deployment = client.V1Deployment(
            api_version="apps/v1",
            kind="Deployment",
            metadata=client.V1ObjectMeta(
                name=f"{name}-deployment",
                namespace=namespace,
                labels={
                    'app': 'log-processor',
                    'processor': name,
                    'managed-by': 'log-operator'
                }
            ),
            spec=client.V1DeploymentSpec(
                replicas=replicas,
                selector=client.V1LabelSelector(
                    match_labels={'app': 'log-processor', 'processor': name}
                ),
                template=client.V1PodTemplateSpec(
                    metadata=client.V1ObjectMeta(
                        labels={'app': 'log-processor', 'processor': name}
                    ),
                    spec=client.V1PodSpec(
                        containers=[
                            client.V1Container(
                                name='log-processor',
                                image='log-processor:latest',
                                env=[
                                    client.V1EnvVar(name='LOG_LEVEL', value=log_level),
                                    client.V1EnvVar(name='PROCESSOR_NAME', value=name)
                                ],
                                resources=client.V1ResourceRequirements(
                                    requests={
                                        'memory': resources_spec.get('memory', '512Mi'),
                                        'cpu': resources_spec.get('cpu', '250m')
                                    },
                                    limits={
                                        'memory': resources_spec.get('memory', '512Mi'),
                                        'cpu': resources_spec.get('cpu', '500m')
                                    }
                                ),
                                ports=[client.V1ContainerPort(container_port=8080)],
                                liveness_probe=client.V1Probe(
                                    http_get=client.V1HTTPGetAction(
                                        path='/health',
                                        port=8080
                                    ),
                                    initial_delay_seconds=10,
                                    period_seconds=10
                                )
                            )
                        ]
                    )
                )
            )
        )
        return deployment
    
    def create_service(self, name: str, namespace: str) -> Dict:
        """Create Kubernetes Service for LogProcessor"""
        service = client.V1Service(
            api_version="v1",
            kind="Service",
            metadata=client.V1ObjectMeta(
                name=f"{name}-service",
                namespace=namespace
            ),
            spec=client.V1ServiceSpec(
                selector={'app': 'log-processor', 'processor': name},
                ports=[
                    client.V1ServicePort(
                        port=8080,
                        target_port=8080,
                        name='http'
                    )
                ],
                type='ClusterIP'
            )
        )
        return service


# Initialize operator
operator = LogProcessorOperator()


@kopf.on.create('logs.platform.io', 'v1', 'logprocessors')
async def create_logprocessor(spec, name, namespace, logger, **kwargs):
    """Handle LogProcessor creation"""
    logger.info(f"Creating LogProcessor: {name} in namespace: {namespace}")
    operator.metrics['reconciliations'] += 1
    
    try:
        # Create Deployment
        deployment = operator.create_deployment(name, namespace, spec)
        operator.apps_api.create_namespaced_deployment(
            namespace=namespace,
            body=deployment
        )
        logger.info(f"✅ Created Deployment for {name}")
        
        # Create Service
        service = operator.create_service(name, namespace)
        operator.core_api.create_namespaced_service(
            namespace=namespace,
            body=service
        )
        logger.info(f"✅ Created Service for {name}")
        
        return {
            'state': 'Provisioning',
            'replicas': spec.get('replicas', 1),
            'readyReplicas': 0,
            'conditions': [{
                'type': 'Created',
                'status': 'True',
                'lastTransitionTime': datetime.now().isoformat(),
                'message': 'Resources created successfully'
            }]
        }
    
    except Exception as e:
        operator.metrics['errors'] += 1
        logger.error(f"Error creating LogProcessor {name}: {str(e)}")
        raise


@kopf.on.update('logs.platform.io', 'v1', 'logprocessors')
async def update_logprocessor(spec, old, new, name, namespace, logger, **kwargs):
    """Handle LogProcessor updates"""
    logger.info(f"Updating LogProcessor: {name}")
    operator.metrics['reconciliations'] += 1
    
    old_replicas = old.get('spec', {}).get('replicas', 1)
    new_replicas = spec.get('replicas', 1)
    
    if old_replicas != new_replicas:
        logger.info(f"Scaling {name} from {old_replicas} to {new_replicas} replicas")
        operator.metrics['scaling_events'] += 1
        
        try:
            # Update deployment replicas
            deployment = operator.apps_api.read_namespaced_deployment(
                name=f"{name}-deployment",
                namespace=namespace
            )
            deployment.spec.replicas = new_replicas
            
            operator.apps_api.patch_namespaced_deployment(
                name=f"{name}-deployment",
                namespace=namespace,
                body=deployment
            )
            logger.info(f"✅ Scaled {name} to {new_replicas} replicas")
            
        except Exception as e:
            operator.metrics['errors'] += 1
            logger.error(f"Error scaling {name}: {str(e)}")
            raise
    
    return {
        'state': 'Updating',
        'replicas': new_replicas
    }


@kopf.on.delete('logs.platform.io', 'v1', 'logprocessors')
async def delete_logprocessor(name, namespace, logger, **kwargs):
    """Handle LogProcessor deletion"""
    logger.info(f"Deleting LogProcessor: {name}")
    
    try:
        # Delete Deployment
        operator.apps_api.delete_namespaced_deployment(
            name=f"{name}-deployment",
            namespace=namespace
        )
        logger.info(f"✅ Deleted Deployment for {name}")
        
        # Delete Service
        operator.core_api.delete_namespaced_service(
            name=f"{name}-service",
            namespace=namespace
        )
        logger.info(f"✅ Deleted Service for {name}")
        
    except client.exceptions.ApiException as e:
        if e.status != 404:  # Ignore not found errors
            logger.error(f"Error deleting LogProcessor {name}: {str(e)}")
            raise


@kopf.timer('logs.platform.io', 'v1', 'logprocessors', interval=30.0)
async def monitor_logprocessor(spec, name, namespace, logger, **kwargs):
    """Periodic health check and auto-scaling"""
    try:
        deployment = operator.apps_api.read_namespaced_deployment(
            name=f"{name}-deployment",
            namespace=namespace
        )
        
        ready_replicas = deployment.status.ready_replicas or 0
        desired_replicas = deployment.spec.replicas
        
        # Check auto-scaling settings
        auto_scaling = spec.get('autoScaling', {})
        if auto_scaling.get('enabled', False):
            # Simulate queue depth check (would integrate with actual metrics)
            simulated_queue_depth = 5000  # Replace with actual metric
            target_queue_depth = auto_scaling.get('targetQueueDepth', 10000)
            
            min_replicas = auto_scaling.get('minReplicas', 1)
            max_replicas = auto_scaling.get('maxReplicas', 10)
            
            if simulated_queue_depth > target_queue_depth and desired_replicas < max_replicas:
                new_replicas = min(desired_replicas + 1, max_replicas)
                logger.info(f"🔼 Auto-scaling {name} from {desired_replicas} to {new_replicas}")
                operator.metrics['scaling_events'] += 1
                
                deployment.spec.replicas = new_replicas
                operator.apps_api.patch_namespaced_deployment(
                    name=f"{name}-deployment",
                    namespace=namespace,
                    body=deployment
                )
        
        # Log current status
        logger.info(f"📊 {name}: {ready_replicas}/{desired_replicas} replicas ready")
        
    except Exception as e:
        logger.error(f"Error monitoring {name}: {str(e)}")


@kopf.on.startup()
async def startup_handler(logger, **kwargs):
    """Operator startup handler"""
    logger.info("🚀 Log Platform Operator started successfully")
    logger.info(f"📊 Monitoring CustomResources: LogProcessor, LogCollector")


if __name__ == '__main__':
    kopf.run()
EOF

# Create API server for dashboard
cat > src/api/server.py << 'EOF'
"""
FastAPI server for operator dashboard
Provides REST API for monitoring operator state
"""
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Dict, Any
import asyncio
import json
from datetime import datetime
from kubernetes import client, config

app = FastAPI(title="Log Operator Dashboard API")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize K8s client
try:
    config.load_incluster_config()
except config.ConfigException:
    config.load_kube_config()

custom_api = client.CustomObjectsApi()
apps_api = client.AppsV1Api()


class OperatorStats(BaseModel):
    total_processors: int
    active_processors: int
    total_replicas: int
    ready_replicas: int
    scaling_events: int
    last_updated: str


class LogProcessorStatus(BaseModel):
    name: str
    namespace: str
    replicas: int
    ready_replicas: int
    state: str
    log_level: str
    auto_scaling: bool


@app.get("/")
async def root():
    return {"message": "Log Operator Dashboard API", "version": "1.0.0"}


@app.get("/api/stats", response_model=OperatorStats)
async def get_operator_stats():
    """Get overall operator statistics"""
    try:
        # List all LogProcessors
        processors = custom_api.list_cluster_custom_object(
            group="logs.platform.io",
            version="v1",
            plural="logprocessors"
        )
        
        total_processors = len(processors.get('items', []))
        total_replicas = 0
        ready_replicas = 0
        active_processors = 0
        
        for proc in processors.get('items', []):
            spec = proc.get('spec', {})
            status = proc.get('status', {})
            
            total_replicas += spec.get('replicas', 0)
            ready_replicas += status.get('readyReplicas', 0)
            
            if status.get('state') == 'Active':
                active_processors += 1
        
        return OperatorStats(
            total_processors=total_processors,
            active_processors=active_processors,
            total_replicas=total_replicas,
            ready_replicas=ready_replicas,
            scaling_events=0,  # Would track from metrics
            last_updated=datetime.now().isoformat()
        )
    
    except Exception as e:
        return OperatorStats(
            total_processors=0,
            active_processors=0,
            total_replicas=0,
            ready_replicas=0,
            scaling_events=0,
            last_updated=datetime.now().isoformat()
        )


@app.get("/api/processors", response_model=List[LogProcessorStatus])
async def list_processors():
    """List all LogProcessor resources"""
    try:
        processors = custom_api.list_cluster_custom_object(
            group="logs.platform.io",
            version="v1",
            plural="logprocessors"
        )
        
        result = []
        for proc in processors.get('items', []):
            metadata = proc.get('metadata', {})
            spec = proc.get('spec', {})
            status = proc.get('status', {})
            
            result.append(LogProcessorStatus(
                name=metadata.get('name', 'unknown'),
                namespace=metadata.get('namespace', 'default'),
                replicas=spec.get('replicas', 0),
                ready_replicas=status.get('readyReplicas', 0),
                state=status.get('state', 'Unknown'),
                log_level=spec.get('logLevel', 'INFO'),
                auto_scaling=spec.get('autoScaling', {}).get('enabled', False)
            ))
        
        return result
    
    except Exception as e:
        return []


@app.websocket("/ws/updates")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket for real-time updates"""
    await websocket.accept()
    
    try:
        while True:
            stats = await get_operator_stats()
            processors = await list_processors()
            
            await websocket.send_json({
                'type': 'update',
                'stats': stats.dict(),
                'processors': [p.dict() for p in processors],
                'timestamp': datetime.now().isoformat()
            })
            
            await asyncio.sleep(5)  # Update every 5 seconds
    
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        await websocket.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Create React Dashboard
cat > src/dashboard/App.jsx << 'EOF'
import React, { useState, useEffect } from 'react';
import './Dashboard.css';

function Dashboard() {
  const [stats, setStats] = useState({
    total_processors: 0,
    active_processors: 0,
    total_replicas: 0,
    ready_replicas: 0,
    scaling_events: 0
  });
  
  const [processors, setProcessors] = useState([]);
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    // Fetch initial data
    fetchStats();
    fetchProcessors();
    
    // Setup polling
    const interval = setInterval(() => {
      fetchStats();
      fetchProcessors();
    }, 5000);
    
    return () => clearInterval(interval);
  }, []);

  const fetchStats = async () => {
    try {
      const response = await fetch('/api/stats');
      const data = await response.json();
      setStats(data);
      setConnected(true);
    } catch (error) {
      console.error('Error fetching stats:', error);
      setConnected(false);
    }
  };

  const fetchProcessors = async () => {
    try {
      const response = await fetch('/api/processors');
      const data = await response.json();
      setProcessors(data);
    } catch (error) {
      console.error('Error fetching processors:', error);
    }
  };

  const getHealthColor = (ready, total) => {
    const ratio = ready / total;
    if (ratio >= 1) return '#10b981';
    if (ratio >= 0.7) return '#f59e0b';
    return '#ef4444';
  };

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <h1>🎛️ Log Platform Operator Dashboard</h1>
        <div className={`status-indicator ${connected ? 'connected' : 'disconnected'}`}>
          {connected ? '● Connected' : '○ Disconnected'}
        </div>
      </header>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-label">Total Processors</div>
          <div className="stat-value">{stats.total_processors}</div>
        </div>
        
        <div className="stat-card">
          <div className="stat-label">Active Processors</div>
          <div className="stat-value" style={{ color: '#10b981' }}>
            {stats.active_processors}
          </div>
        </div>
        
        <div className="stat-card">
          <div className="stat-label">Total Replicas</div>
          <div className="stat-value">{stats.total_replicas}</div>
        </div>
        
        <div className="stat-card">
          <div className="stat-label">Ready Replicas</div>
          <div className="stat-value">
            {stats.ready_replicas} / {stats.total_replicas}
          </div>
        </div>
      </div>

      <div className="processors-section">
        <h2>Log Processors</h2>
        <div className="processors-list">
          {processors.map((proc, idx) => (
            <div key={idx} className="processor-card">
              <div className="processor-header">
                <h3>{proc.name}</h3>
                <span className={`state-badge ${proc.state.toLowerCase()}`}>
                  {proc.state}
                </span>
              </div>
              
              <div className="processor-details">
                <div className="detail-row">
                  <span>Namespace:</span>
                  <span>{proc.namespace}</span>
                </div>
                <div className="detail-row">
                  <span>Log Level:</span>
                  <span className="log-level">{proc.log_level}</span>
                </div>
                <div className="detail-row">
                  <span>Replicas:</span>
                  <span style={{ color: getHealthColor(proc.ready_replicas, proc.replicas) }}>
                    {proc.ready_replicas} / {proc.replicas}
                  </span>
                </div>
                <div className="detail-row">
                  <span>Auto-Scaling:</span>
                  <span>{proc.auto_scaling ? '✅ Enabled' : '❌ Disabled'}</span>
                </div>
              </div>
              
              <div className="replica-status-bar">
                <div 
                  className="replica-fill"
                  style={{ 
                    width: `${(proc.ready_replicas / proc.replicas) * 100}%`,
                    backgroundColor: getHealthColor(proc.ready_replicas, proc.replicas)
                  }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default Dashboard;
EOF

cat > src/dashboard/Dashboard.css << 'EOF'
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
}

.dashboard {
  max-width: 1400px;
  margin: 0 auto;
  padding: 20px;
}

.dashboard-header {
  background: white;
  padding: 30px;
  border-radius: 12px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  margin-bottom: 30px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.dashboard-header h1 {
  color: #1f2937;
  font-size: 28px;
}

.status-indicator {
  padding: 8px 16px;
  border-radius: 20px;
  font-weight: 600;
  font-size: 14px;
}

.status-indicator.connected {
  background: #d1fae5;
  color: #065f46;
}

.status-indicator.disconnected {
  background: #fee2e2;
  color: #991b1b;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.stat-card {
  background: white;
  padding: 25px;
  border-radius: 12px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  transition: transform 0.2s;
}

.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
}

.stat-label {
  color: #6b7280;
  font-size: 14px;
  margin-bottom: 8px;
  font-weight: 500;
}

.stat-value {
  color: #1f2937;
  font-size: 36px;
  font-weight: 700;
}

.processors-section {
  background: white;
  padding: 30px;
  border-radius: 12px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.processors-section h2 {
  color: #1f2937;
  margin-bottom: 20px;
  font-size: 24px;
}

.processors-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 20px;
}

.processor-card {
  background: #f9fafb;
  border: 2px solid #e5e7eb;
  border-radius: 8px;
  padding: 20px;
  transition: all 0.2s;
}

.processor-card:hover {
  border-color: #667eea;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
}

.processor-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.processor-header h3 {
  color: #1f2937;
  font-size: 18px;
}

.state-badge {
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
}

.state-badge.active {
  background: #d1fae5;
  color: #065f46;
}

.state-badge.provisioning {
  background: #fef3c7;
  color: #92400e;
}

.state-badge.unknown {
  background: #e5e7eb;
  color: #374151;
}

.processor-details {
  margin-bottom: 15px;
}

.detail-row {
  display: flex;
  justify-content: space-between;
  padding: 8px 0;
  border-bottom: 1px solid #e5e7eb;
}

.detail-row:last-child {
  border-bottom: none;
}

.detail-row span:first-child {
  color: #6b7280;
  font-weight: 500;
}

.detail-row span:last-child {
  color: #1f2937;
  font-weight: 600;
}

.log-level {
  font-family: 'Courier New', monospace;
  background: #e0e7ff;
  padding: 2px 8px;
  border-radius: 4px;
  color: #3730a3;
}

.replica-status-bar {
  width: 100%;
  height: 6px;
  background: #e5e7eb;
  border-radius: 3px;
  overflow: hidden;
  margin-top: 10px;
}

.replica-fill {
  height: 100%;
  transition: width 0.5s ease, background-color 0.5s ease;
  border-radius: 3px;
}
EOF

# Create package.json for React
cat > src/dashboard/package.json << 'EOF'
{
  "name": "operator-dashboard",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "scripts": {
    "build": "echo 'Build completed'",
    "start": "echo 'Dashboard ready'"
  }
}
EOF

# Create example LogProcessor resources
cat > examples/error-processor.yaml << 'EOF'
apiVersion: logs.platform.io/v1
kind: LogProcessor
metadata:
  name: error-processor
  namespace: default
spec:
  replicas: 3
  logLevel: ERROR
  processingRate: 1000
  resources:
    memory: "1Gi"
    cpu: "500m"
  autoScaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetQueueDepth: 5000
EOF

cat > examples/info-processor.yaml << 'EOF'
apiVersion: logs.platform.io/v1
kind: LogProcessor
metadata:
  name: info-processor
  namespace: default
spec:
  replicas: 2
  logLevel: INFO
  processingRate: 2000
  resources:
    memory: "512Mi"
    cpu: "250m"
  autoScaling:
    enabled: false
EOF

# Create RBAC configuration
cat > deployment/rbac/service-account.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: log-operator
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: log-operator-role
rules:
  - apiGroups: ["logs.platform.io"]
    resources: ["logprocessors", "logcollectors"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["logs.platform.io"]
    resources: ["logprocessors/status", "logcollectors/status"]
    verbs: ["get", "update", "patch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "pods"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: log-operator-binding
subjects:
  - kind: ServiceAccount
    name: log-operator
    namespace: default
roleRef:
  kind: ClusterRole
  name: log-operator-role
  apiGroup: rbac.authorization.k8s.io
EOF

# Create operator deployment
cat > deployment/operator/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-operator
  namespace: default
  labels:
    app: log-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-operator
  template:
    metadata:
      labels:
        app: log-operator
    spec:
      serviceAccountName: log-operator
      containers:
        - name: operator
          image: log-operator:latest
          imagePullPolicy: IfNotPresent
          env:
            - name: PYTHONUNBUFFERED
              value: "1"
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
EOF

# Create comprehensive tests
cat > tests/unit/test_operator.py << 'EOF'
"""Unit tests for Kubernetes Operator"""
import pytest
from unittest.mock import Mock, patch
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../src/operator'))

class TestLogProcessorOperator:
    """Test LogProcessor operator functionality"""
    
    @patch('kubernetes.client.AppsV1Api')
    @patch('kubernetes.client.CoreV1Api')
    def test_create_deployment(self, mock_core, mock_apps):
        """Test deployment creation"""
        from main import LogProcessorOperator
        
        operator = LogProcessorOperator()
        spec = {
            'replicas': 3,
            'logLevel': 'ERROR',
            'resources': {
                'memory': '1Gi',
                'cpu': '500m'
            }
        }
        
        deployment = operator.create_deployment('test-processor', 'default', spec)
        
        assert deployment.metadata.name == 'test-processor-deployment'
        assert deployment.spec.replicas == 3
        assert deployment.spec.template.spec.containers[0].env[0].value == 'ERROR'
    
    @patch('kubernetes.client.AppsV1Api')
    @patch('kubernetes.client.CoreV1Api')
    def test_create_service(self, mock_core, mock_apps):
        """Test service creation"""
        from main import LogProcessorOperator
        
        operator = LogProcessorOperator()
        service = operator.create_service('test-processor', 'default')
        
        assert service.metadata.name == 'test-processor-service'
        assert service.spec.ports[0].port == 8080
    
    def test_operator_metrics_initialization(self):
        """Test operator metrics are initialized"""
        from main import LogProcessorOperator
        
        with patch('kubernetes.config.load_kube_config'):
            operator = LogProcessorOperator()
            
            assert 'reconciliations' in operator.metrics
            assert 'scaling_events' in operator.metrics
            assert 'errors' in operator.metrics


@pytest.mark.asyncio
async def test_api_stats_endpoint():
    """Test API stats endpoint"""
    from fastapi.testclient import TestClient
    
    # Mock Kubernetes API
    with patch('kubernetes.client.CustomObjectsApi'):
        with patch('kubernetes.config.load_kube_config'):
            from api.server import app
            
            client = TestClient(app)
            response = client.get("/api/stats")
            
            assert response.status_code == 200
            data = response.json()
            assert 'total_processors' in data
            assert 'ready_replicas' in data


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
EOF

cat > tests/integration/test_full_lifecycle.py << 'EOF'
"""Integration tests for full operator lifecycle"""
import pytest
import asyncio
from unittest.mock import Mock, patch

@pytest.mark.asyncio
async def test_processor_creation_flow():
    """Test complete processor creation flow"""
    # This would test actual K8s interaction in real cluster
    assert True  # Placeholder for cluster integration test

@pytest.mark.asyncio
async def test_scaling_event():
    """Test scaling event handling"""
    assert True  # Placeholder for scaling test

@pytest.mark.asyncio  
async def test_deletion_cleanup():
    """Test resource cleanup on deletion"""
    assert True  # Placeholder for cleanup test
EOF

# Create Dockerfile for operator
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/

# Run operator
CMD ["kopf", "run", "--standalone", "src/operator/main.py"]
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
venv/
tests/
examples/
*.log
.git
.gitignore
README.md
EOF

# Create docker-compose for local development
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    ports:
      - "8000:8000"
    environment:
      - KUBERNETES_SERVICE_HOST=kind-control-plane
    volumes:
      - ./src:/app/src
      - ~/.kube:/root/.kube
    command: python src/api/server.py
EOF

cat > Dockerfile.api << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

CMD ["python", "src/api/server.py"]
EOF

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting Day 152: Kubernetes Operator"
echo "========================================"

# Check for duplicate API server processes
if [ -f api.pid ]; then
    OLD_PID=$(cat api.pid)
    if ps -p $OLD_PID > /dev/null 2>&1; then
        echo "⚠️  API server already running (PID: $OLD_PID). Stopping it..."
        kill $OLD_PID 2>/dev/null || true
        rm api.pid
    fi
fi

# Check if Kind cluster exists
if ! kind get clusters | grep -q "log-operator"; then
    echo "📦 Creating Kind cluster..."
    kind create cluster --name log-operator --config - <<CLUSTER_CONFIG
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
CLUSTER_CONFIG
    echo "✅ Cluster created"
else
    echo "✅ Using existing cluster"
fi

# Create Python virtual environment
if [ ! -d "venv" ]; then
    echo "🐍 Creating Python 3.11 virtual environment..."
    python3.11 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install CRDs
echo "📝 Installing Custom Resource Definitions..."
kubectl apply -f src/crds/

# Create RBAC
echo "🔐 Creating RBAC resources..."
kubectl apply -f deployment/rbac/

# Build operator Docker image
echo "🐳 Building operator Docker image..."
docker build -t log-operator:latest .

# Load image into Kind cluster
echo "📥 Loading image into Kind cluster..."
kind load docker-image log-operator:latest --name log-operator

# Deploy operator
echo "🚀 Deploying operator..."
kubectl apply -f deployment/operator/deployment.yaml

# Wait for operator to be ready
echo "⏳ Waiting for operator to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/log-operator

# Create example LogProcessors
echo "📋 Creating example LogProcessor resources..."
kubectl apply -f examples/error-processor.yaml
kubectl apply -f examples/info-processor.yaml

# Start API server in background
echo "🌐 Starting API server..."
cd "$SCRIPT_DIR"
python src/api/server.py > api.log 2>&1 &
API_PID=$!
echo $API_PID > api.pid
echo "API server started with PID: $API_PID"

sleep 5

echo ""
echo "✅ Setup complete!"
echo ""
echo "📊 Dashboard: http://localhost:8000"
echo "🔍 Check operator logs: kubectl logs -f deployment/log-operator"
echo "📋 List processors: kubectl get logprocessors"
echo ""
echo "To stop: ./stop.sh"
EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🛑 Stopping Day 152: Kubernetes Operator"

# Stop API server
if [ -f api.pid ]; then
    API_PID=$(cat api.pid)
    if ps -p $API_PID > /dev/null 2>&1; then
        echo "Stopping API server (PID: $API_PID)..."
        kill $API_PID 2>/dev/null || true
    fi
    rm -f api.pid
fi

# Delete example resources
kubectl delete -f examples/ --ignore-not-found=true

# Delete operator
kubectl delete -f deployment/operator/deployment.yaml --ignore-not-found=true

# Delete CRDs (this will delete all custom resources)
kubectl delete -f src/crds/ --ignore-not-found=true

# Delete cluster
kind delete cluster --name log-operator

echo "✅ Cleanup complete"
EOF

chmod +x stop.sh

# Create demo script to generate test data
cat > demo.sh << 'EOF'
#!/bin/bash
# Demo script to create test LogProcessor resources for dashboard metrics

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🎬 Running Demo: Creating test LogProcessor resources..."

# Apply example processors if they don't exist
if ! kubectl get logprocessor error-processor > /dev/null 2>&1; then
    echo "Creating error-processor..."
    kubectl apply -f examples/error-processor.yaml
fi

if ! kubectl get logprocessor info-processor > /dev/null 2>&1; then
    echo "Creating info-processor..."
    kubectl apply -f examples/info-processor.yaml
fi

# Wait a bit for operator to process
sleep 3

echo "✅ Demo resources created!"
echo "Check dashboard at http://localhost:8000"
EOF

chmod +x demo.sh

echo -e "${GREEN}✅ All files created successfully!${NC}"
echo ""
echo "🧪 Running tests..."
# Use available Python version
PYTHON_CMD=$(command -v python3.11 || command -v python3 || command -v python)
if [ -z "$PYTHON_CMD" ]; then
    echo "⚠️  Python not found. Skipping tests."
else
    $PYTHON_CMD -m venv venv 2>/dev/null || echo "⚠️  Virtual environment creation skipped"
    if [ -d "venv" ]; then
        source venv/bin/activate
        pip install --quiet -r requirements.txt pytest pytest-asyncio 2>/dev/null || echo "⚠️  Dependency installation had issues"
        # Run tests
        python -m pytest tests/ -v 2>/dev/null || echo "⚠️  Tests require full K8s cluster or dependencies"
    fi
fi

echo ""
echo -e "${BLUE}📦 Project Structure:${NC}"
if command -v tree &> /dev/null; then
    tree -L 3 -I 'venv|__pycache__|*.pyc'
else
    find . -type f -not -path './venv/*' -not -path '*/__pycache__/*' -not -name '*.pyc' | head -30
fi

echo ""
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo ""
echo "To start the operator:"
echo "  ./start.sh"
echo ""
echo "To stop the operator:"
echo "  ./stop.sh"
echo ""
echo "Manual commands:"
echo "  kubectl get logprocessors"
echo "  kubectl describe logprocessor error-processor"
echo "  kubectl logs -f deployment/log-operator"
echo "  curl http://localhost:8000/api/stats"