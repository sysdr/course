#!/bin/bash

# Day 95: Customizable Dashboard Implementation Script
# Creates complete drag-and-drop dashboard system for log processing

set -e

PROJECT_NAME="log-dashboard-system"
PYTHON_VERSION="3.11"

echo "🚀 Day 95: Building Customizable Dashboard System"
echo "=================================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# Create directory structure
mkdir -p {backend/{app,tests,config},frontend/{src/{components,pages,hooks,utils,styles},public,build},docker,scripts}
mkdir -p backend/app/{api,models,services,websocket}
mkdir -p frontend/src/components/{widgets,dashboard,layout}

echo "✅ Project structure created"

# Create Python virtual environment
echo "🐍 Setting up Python virtual environment..."
python$PYTHON_VERSION -m venv venv
source venv/bin/activate

# Backend requirements.txt
cat > backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
websockets==12.0
pydantic==2.5.0
sqlalchemy==2.0.23
aiosqlite==0.19.0
python-multipart==0.0.6
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
pytest==7.4.3
pytest-asyncio==0.21.1
httpx==0.25.2
faker==20.1.0
EOF

# Frontend package.json
cat > frontend/package.json << 'EOF'
{
  "name": "log-dashboard-frontend",
  "version": "1.0.0",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "test": "jest"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-grid-layout": "^1.4.4",
    "react-resizable": "^3.0.5",
    "recharts": "^2.8.0",
    "socket.io-client": "^4.7.4",
    "axios": "^1.6.2",
    "date-fns": "^2.30.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.1.1",
    "vite": "^5.0.0",
    "jest": "^29.7.0",
    "@testing-library/react": "^13.4.0"
  }
}
EOF

# Install Python dependencies
echo "📦 Installing backend dependencies..."
pip install -r backend/requirements.txt

# Backend main application
cat > backend/app/main.py << 'EOF'
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import json
import uuid
from datetime import datetime, timedelta
import random
from typing import Dict, List
from .models.dashboard import Dashboard, Widget
from .services.data_generator import LogDataGenerator
from .api.dashboards import router as dashboard_router

app = FastAPI(title="Log Dashboard System")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# WebSocket connections
connections: Dict[str, WebSocket] = {}
data_generator = LogDataGenerator()

@app.get("/")
async def root():
    return {"message": "Log Dashboard System API"}

@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

app.include_router(dashboard_router, prefix="/api")

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    connections[client_id] = websocket
    
    try:
        while True:
            # Generate and send live log data
            log_data = data_generator.generate_log_batch(10)
            metrics = data_generator.generate_metrics()
            
            message = {
                "type": "live_data",
                "logs": log_data,
                "metrics": metrics,
                "timestamp": datetime.now().isoformat()
            }
            
            await websocket.send_text(json.dumps(message))
            await asyncio.sleep(2)  # Update every 2 seconds
            
    except WebSocketDisconnect:
        del connections[client_id]

# Background task to simulate log processing
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(broadcast_system_status())

async def broadcast_system_status():
    while True:
        if connections:
            status = {
                "type": "system_status",
                "active_connections": len(connections),
                "system_load": random.uniform(0.1, 0.9),
                "timestamp": datetime.now().isoformat()
            }
            
            disconnected = []
            for client_id, websocket in connections.items():
                try:
                    await websocket.send_text(json.dumps(status))
                except:
                    disconnected.append(client_id)
            
            for client_id in disconnected:
                del connections[client_id]
        
        await asyncio.sleep(5)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
EOF

# Dashboard models
cat > backend/app/models/dashboard.py << 'EOF'
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime

class WidgetConfig(BaseModel):
    x: int
    y: int
    w: int
    h: int
    minW: int = 2
    minH: int = 2

class Widget(BaseModel):
    id: str
    type: str  # 'log_stream', 'metrics', 'chart', 'alert'
    title: str
    config: WidgetConfig
    filters: Dict[str, Any] = {}
    settings: Dict[str, Any] = {}

class Dashboard(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    widgets: List[Widget]
    layout_settings: Dict[str, Any] = {}
    created_at: datetime
    updated_at: datetime
    owner: str = "user"
    shared: bool = False

class DashboardTemplate(BaseModel):
    id: str
    name: str
    description: str
    category: str  # 'devops', 'security', 'product'
    widgets: List[Widget]
EOF

# Data generator service
cat > backend/app/services/data_generator.py << 'EOF'
import random
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any
from faker import Faker

fake = Faker()

class LogDataGenerator:
    def __init__(self):
        self.services = ['web-api', 'auth-service', 'db-service', 'cache-service']
        self.log_levels = ['INFO', 'WARNING', 'ERROR', 'DEBUG']
        self.endpoints = ['/api/users', '/api/orders', '/api/products', '/health']
        
    def generate_log_entry(self) -> Dict[str, Any]:
        return {
            'id': fake.uuid4(),
            'timestamp': datetime.now().isoformat(),
            'level': random.choice(self.log_levels),
            'service': random.choice(self.services),
            'endpoint': random.choice(self.endpoints),
            'message': fake.sentence(),
            'response_time': random.uniform(10, 500),
            'status_code': random.choices([200, 201, 400, 404, 500], weights=[70, 10, 10, 5, 5])[0],
            'user_id': fake.uuid4() if random.random() > 0.3 else None,
            'ip_address': fake.ipv4(),
        }
    
    def generate_log_batch(self, count: int = 10) -> List[Dict[str, Any]]:
        return [self.generate_log_entry() for _ in range(count)]
    
    def generate_metrics(self) -> Dict[str, Any]:
        return {
            'requests_per_second': random.uniform(100, 1000),
            'error_rate': random.uniform(0.01, 0.1),
            'avg_response_time': random.uniform(50, 200),
            'active_users': random.randint(500, 5000),
            'cpu_usage': random.uniform(0.1, 0.9),
            'memory_usage': random.uniform(0.3, 0.8),
            'disk_usage': random.uniform(0.2, 0.7),
        }
EOF

# Dashboard API endpoints
cat > backend/app/api/dashboards.py << 'EOF'
from fastapi import APIRouter, HTTPException, Depends
from typing import List, Optional
import json
import os
from datetime import datetime
from ..models.dashboard import Dashboard, Widget, DashboardTemplate
import uuid

router = APIRouter()

DASHBOARDS_FILE = "dashboards.json"
TEMPLATES_FILE = "dashboard_templates.json"

def load_dashboards() -> List[Dashboard]:
    if os.path.exists(DASHBOARDS_FILE):
        with open(DASHBOARDS_FILE, 'r') as f:
            data = json.load(f)
            return [Dashboard(**d) for d in data]
    return []

def save_dashboards(dashboards: List[Dashboard]):
    with open(DASHBOARDS_FILE, 'w') as f:
        json.dump([d.dict() for d in dashboards], f, default=str)

def load_templates() -> List[DashboardTemplate]:
    templates = [
        {
            "id": "devops-template",
            "name": "DevOps Monitoring",
            "description": "System metrics and error tracking",
            "category": "devops",
            "widgets": [
                {
                    "id": "metrics-1",
                    "type": "metrics",
                    "title": "System Metrics",
                    "config": {"x": 0, "y": 0, "w": 6, "h": 4},
                    "settings": {"chart_type": "line"}
                },
                {
                    "id": "logs-1", 
                    "type": "log_stream",
                    "title": "Error Logs",
                    "config": {"x": 6, "y": 0, "w": 6, "h": 4},
                    "filters": {"level": "ERROR"}
                }
            ]
        },
        {
            "id": "security-template",
            "name": "Security Dashboard", 
            "description": "Auth failures and security events",
            "category": "security",
            "widgets": [
                {
                    "id": "auth-logs",
                    "type": "log_stream",
                    "title": "Auth Failures",
                    "config": {"x": 0, "y": 0, "w": 12, "h": 6},
                    "filters": {"service": "auth-service", "status_code": 401}
                }
            ]
        }
    ]
    return [DashboardTemplate(**t) for t in templates]

@router.get("/dashboards", response_model=List[Dashboard])
async def get_dashboards():
    return load_dashboards()

@router.post("/dashboards", response_model=Dashboard)
async def create_dashboard(dashboard_data: dict):
    dashboards = load_dashboards()
    
    new_dashboard = Dashboard(
        id=str(uuid.uuid4()),
        name=dashboard_data["name"],
        description=dashboard_data.get("description", ""),
        widgets=dashboard_data.get("widgets", []),
        created_at=datetime.now(),
        updated_at=datetime.now()
    )
    
    dashboards.append(new_dashboard)
    save_dashboards(dashboards)
    return new_dashboard

@router.put("/dashboards/{dashboard_id}", response_model=Dashboard)
async def update_dashboard(dashboard_id: str, dashboard_data: dict):
    dashboards = load_dashboards()
    
    for i, dashboard in enumerate(dashboards):
        if dashboard.id == dashboard_id:
            dashboards[i].name = dashboard_data.get("name", dashboard.name)
            dashboards[i].widgets = dashboard_data.get("widgets", dashboard.widgets)
            dashboards[i].updated_at = datetime.now()
            save_dashboards(dashboards)
            return dashboards[i]
    
    raise HTTPException(status_code=404, detail="Dashboard not found")

@router.delete("/dashboards/{dashboard_id}")
async def delete_dashboard(dashboard_id: str):
    dashboards = load_dashboards()
    dashboards = [d for d in dashboards if d.id != dashboard_id]
    save_dashboards(dashboards)
    return {"message": "Dashboard deleted"}

@router.get("/templates", response_model=List[DashboardTemplate])
async def get_templates():
    return load_templates()

@router.post("/dashboards/from-template/{template_id}", response_model=Dashboard)
async def create_from_template(template_id: str, name: str):
    templates = load_templates()
    template = next((t for t in templates if t.id == template_id), None)
    
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    
    new_dashboard = Dashboard(
        id=str(uuid.uuid4()),
        name=name,
        description=f"Created from {template.name} template",
        widgets=template.widgets,
        created_at=datetime.now(),
        updated_at=datetime.now()
    )
    
    dashboards = load_dashboards()
    dashboards.append(new_dashboard)
    save_dashboards(dashboards)
    return new_dashboard
EOF

# Frontend index.html
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Log Dashboard System</title>
    <link rel="stylesheet" href="/src/styles/dashboard.css">
</head>
<body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
</body>
</html>
EOF

# Frontend Vite config
cat > frontend/vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    proxy: {
      '/api': 'http://localhost:8000',
      '/ws': {
        target: 'ws://localhost:8000',
        ws: true
      }
    }
  }
})
EOF

# Main React app
cat > frontend/src/main.jsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './styles/dashboard.css'

ReactDOM.createRoot(document.getElementById('root')).render(<App />)
EOF

# App component
cat > frontend/src/App.jsx << 'EOF'
import React, { useState, useEffect } from 'react'
import DashboardBuilder from './components/dashboard/DashboardBuilder'
import DashboardList from './components/dashboard/DashboardList'
import { DashboardProvider } from './hooks/useDashboard'

function App() {
  const [currentView, setCurrentView] = useState('list')
  const [selectedDashboard, setSelectedDashboard] = useState(null)

  return (
    <DashboardProvider>
      <div className="app">
        <header className="app-header">
          <h1>Log Dashboard System</h1>
          <nav>
            <button 
              onClick={() => setCurrentView('list')}
              className={currentView === 'list' ? 'active' : ''}
            >
              Dashboards
            </button>
            <button 
              onClick={() => {
                setCurrentView('builder')
                setSelectedDashboard(null)
              }}
              className={currentView === 'builder' ? 'active' : ''}
            >
              New Dashboard
            </button>
          </nav>
        </header>

        <main className="app-main">
          {currentView === 'list' ? (
            <DashboardList 
              onEdit={(dashboard) => {
                setSelectedDashboard(dashboard)
                setCurrentView('builder')
              }}
            />
          ) : (
            <DashboardBuilder 
              dashboard={selectedDashboard}
              onSave={() => setCurrentView('list')}
            />
          )}
        </main>
      </div>
    </DashboardProvider>
  )
}

export default App
EOF

# Dashboard context/hooks
cat > frontend/src/hooks/useDashboard.js << 'EOF'
import React, { createContext, useContext, useState, useEffect } from 'react'
import axios from 'axios'
import io from 'socket.io-client'

const DashboardContext = createContext()

export const useDashboard = () => {
  const context = useContext(DashboardContext)
  if (!context) {
    throw new Error('useDashboard must be used within DashboardProvider')
  }
  return context
}

export const DashboardProvider = ({ children }) => {
  const [dashboards, setDashboards] = useState([])
  const [templates, setTemplates] = useState([])
  const [liveData, setLiveData] = useState({})
  const [socket, setSocket] = useState(null)

  useEffect(() => {
    loadDashboards()
    loadTemplates()
    
    const newSocket = io('http://localhost:8000')
    setSocket(newSocket)
    
    newSocket.on('live_data', (data) => {
      setLiveData(data)
    })

    return () => {
      newSocket.disconnect()
    }
  }, [])

  const loadDashboards = async () => {
    try {
      const response = await axios.get('/api/dashboards')
      setDashboards(response.data)
    } catch (error) {
      console.error('Error loading dashboards:', error)
    }
  }

  const loadTemplates = async () => {
    try {
      const response = await axios.get('/api/templates')
      setTemplates(response.data)
    } catch (error) {
      console.error('Error loading templates:', error)
    }
  }

  const saveDashboard = async (dashboard) => {
    try {
      if (dashboard.id) {
        await axios.put(`/api/dashboards/${dashboard.id}`, dashboard)
      } else {
        await axios.post('/api/dashboards', dashboard)
      }
      loadDashboards()
    } catch (error) {
      console.error('Error saving dashboard:', error)
      throw error
    }
  }

  const deleteDashboard = async (id) => {
    try {
      await axios.delete(`/api/dashboards/${id}`)
      loadDashboards()
    } catch (error) {
      console.error('Error deleting dashboard:', error)
      throw error
    }
  }

  const createFromTemplate = async (templateId, name) => {
    try {
      await axios.post(`/api/dashboards/from-template/${templateId}`, { name })
      loadDashboards()
    } catch (error) {
      console.error('Error creating from template:', error)
      throw error
    }
  }

  return (
    <DashboardContext.Provider value={{
      dashboards,
      templates,
      liveData,
      saveDashboard,
      deleteDashboard,
      createFromTemplate,
      loadDashboards
    }}>
      {children}
    </DashboardContext.Provider>
  )
}
EOF

# Dashboard Builder Component
cat > frontend/src/components/dashboard/DashboardBuilder.jsx << 'EOF'
import React, { useState, useEffect } from 'react'
import { Responsive, WidthProvider } from 'react-grid-layout'
import Widget from '../widgets/Widget'
import WidgetSelector from './WidgetSelector'
import { useDashboard } from '../../hooks/useDashboard'
import 'react-grid-layout/css/styles.css'
import 'react-resizable/css/styles.css'

const ResponsiveGridLayout = WidthProvider(Responsive)

const DashboardBuilder = ({ dashboard, onSave }) => {
  const { saveDashboard } = useDashboard()
  const [name, setName] = useState(dashboard?.name || 'New Dashboard')
  const [widgets, setWidgets] = useState(dashboard?.widgets || [])
  const [layouts, setLayouts] = useState({})
  const [showWidgetSelector, setShowWidgetSelector] = useState(false)

  const handleLayoutChange = (layout, layouts) => {
    setLayouts(layouts)
    
    // Update widget configs with new layout
    const updatedWidgets = widgets.map(widget => {
      const layoutItem = layout.find(item => item.i === widget.id)
      if (layoutItem) {
        return {
          ...widget,
          config: {
            ...widget.config,
            x: layoutItem.x,
            y: layoutItem.y,
            w: layoutItem.w,
            h: layoutItem.h
          }
        }
      }
      return widget
    })
    setWidgets(updatedWidgets)
  }

  const addWidget = (widgetType) => {
    const newWidget = {
      id: `widget-${Date.now()}`,
      type: widgetType,
      title: `${widgetType.charAt(0).toUpperCase() + widgetType.slice(1)} Widget`,
      config: {
        x: 0,
        y: 0,
        w: 4,
        h: 4,
        minW: 2,
        minH: 2
      },
      filters: {},
      settings: {}
    }
    setWidgets([...widgets, newWidget])
    setShowWidgetSelector(false)
  }

  const removeWidget = (widgetId) => {
    setWidgets(widgets.filter(w => w.id !== widgetId))
  }

  const updateWidget = (widgetId, updates) => {
    setWidgets(widgets.map(w => 
      w.id === widgetId ? { ...w, ...updates } : w
    ))
  }

  const handleSave = async () => {
    try {
      const dashboardData = {
        id: dashboard?.id,
        name,
        widgets,
        layout_settings: layouts
      }
      await saveDashboard(dashboardData)
      onSave()
    } catch (error) {
      console.error('Error saving dashboard:', error)
    }
  }

  const gridLayout = widgets.map(widget => ({
    i: widget.id,
    x: widget.config.x,
    y: widget.config.y,
    w: widget.config.w,
    h: widget.config.h,
    minW: widget.config.minW || 2,
    minH: widget.config.minH || 2
  }))

  return (
    <div className="dashboard-builder">
      <div className="builder-header">
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Dashboard Name"
          className="dashboard-name-input"
        />
        <div className="builder-actions">
          <button 
            onClick={() => setShowWidgetSelector(true)}
            className="add-widget-btn"
          >
            Add Widget
          </button>
          <button onClick={handleSave} className="save-btn">
            Save Dashboard
          </button>
        </div>
      </div>

      <div className="grid-container">
        <ResponsiveGridLayout
          className="layout"
          layouts={layouts}
          onLayoutChange={handleLayoutChange}
          breakpoints={{ lg: 1200, md: 996, sm: 768, xs: 480, xxs: 0 }}
          cols={{ lg: 12, md: 10, sm: 6, xs: 4, xxs: 2 }}
          rowHeight={60}
          margin={[16, 16]}
        >
          {widgets.map(widget => (
            <div key={widget.id} className="widget-container">
              <Widget
                widget={widget}
                onRemove={() => removeWidget(widget.id)}
                onUpdate={(updates) => updateWidget(widget.id, updates)}
              />
            </div>
          ))}
        </ResponsiveGridLayout>
      </div>

      {showWidgetSelector && (
        <WidgetSelector
          onSelect={addWidget}
          onClose={() => setShowWidgetSelector(false)}
        />
      )}
    </div>
  )
}

export default DashboardBuilder
EOF

# Widget Selector Component
cat > frontend/src/components/dashboard/WidgetSelector.jsx << 'EOF'
import React from 'react'

const WIDGET_TYPES = [
  {
    type: 'log_stream',
    name: 'Log Stream',
    description: 'Real-time log entries with filtering',
    icon: '📄'
  },
  {
    type: 'metrics',
    name: 'Metrics Chart',
    description: 'System metrics and performance data',
    icon: '📊'
  },
  {
    type: 'alerts',
    name: 'Alerts',
    description: 'Critical alerts and notifications',
    icon: '🚨'
  },
  {
    type: 'status',
    name: 'Status Board',
    description: 'Service health status overview',
    icon: '🔍'
  }
]

const WidgetSelector = ({ onSelect, onClose }) => {
  return (
    <div className="widget-selector-overlay">
      <div className="widget-selector">
        <div className="selector-header">
          <h3>Add Widget</h3>
          <button onClick={onClose} className="close-btn">×</button>
        </div>
        
        <div className="widget-types">
          {WIDGET_TYPES.map(widgetType => (
            <div
              key={widgetType.type}
              className="widget-type-card"
              onClick={() => onSelect(widgetType.type)}
            >
              <div className="widget-icon">{widgetType.icon}</div>
              <h4>{widgetType.name}</h4>
              <p>{widgetType.description}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

export default WidgetSelector
EOF

# Base Widget Component
cat > frontend/src/components/widgets/Widget.jsx << 'EOF'
import React, { useState } from 'react'
import LogStreamWidget from './LogStreamWidget'
import MetricsWidget from './MetricsWidget'
import AlertsWidget from './AlertsWidget'
import StatusWidget from './StatusWidget'

const Widget = ({ widget, onRemove, onUpdate }) => {
  const [showSettings, setShowSettings] = useState(false)

  const renderWidget = () => {
    switch (widget.type) {
      case 'log_stream':
        return <LogStreamWidget widget={widget} />
      case 'metrics':
        return <MetricsWidget widget={widget} />
      case 'alerts':
        return <AlertsWidget widget={widget} />
      case 'status':
        return <StatusWidget widget={widget} />
      default:
        return <div>Unknown widget type</div>
    }
  }

  return (
    <div className="widget">
      <div className="widget-header">
        <h4 className="widget-title">{widget.title}</h4>
        <div className="widget-controls">
          <button 
            onClick={() => setShowSettings(!showSettings)}
            className="widget-btn"
          >
            ⚙️
          </button>
          <button 
            onClick={onRemove}
            className="widget-btn remove-btn"
          >
            ×
          </button>
        </div>
      </div>

      <div className="widget-content">
        {renderWidget()}
      </div>

      {showSettings && (
        <div className="widget-settings">
          <input
            type="text"
            value={widget.title}
            onChange={(e) => onUpdate({ title: e.target.value })}
            placeholder="Widget Title"
          />
          {/* Add widget-specific settings here */}
        </div>
      )}
    </div>
  )
}

export default Widget
EOF

# Log Stream Widget
cat > frontend/src/components/widgets/LogStreamWidget.jsx << 'EOF'
import React, { useEffect, useState } from 'react'
import { useDashboard } from '../../hooks/useDashboard'
import { format } from 'date-fns'

const LogStreamWidget = ({ widget }) => {
  const { liveData } = useDashboard()
  const [logs, setLogs] = useState([])

  useEffect(() => {
    if (liveData.logs) {
      // Apply widget filters
      let filteredLogs = liveData.logs
      
      if (widget.filters.level) {
        filteredLogs = filteredLogs.filter(log => log.level === widget.filters.level)
      }
      if (widget.filters.service) {
        filteredLogs = filteredLogs.filter(log => log.service === widget.filters.service)
      }
      
      setLogs(prevLogs => {
        const newLogs = [...filteredLogs, ...prevLogs].slice(0, 50)
        return newLogs
      })
    }
  }, [liveData, widget.filters])

  const getLevelColor = (level) => {
    switch (level) {
      case 'ERROR': return '#ff4444'
      case 'WARNING': return '#ff8800'
      case 'INFO': return '#0088ff'
      case 'DEBUG': return '#888888'
      default: return '#000000'
    }
  }

  return (
    <div className="log-stream-widget">
      <div className="log-entries">
        {logs.map((log, index) => (
          <div key={`${log.id}-${index}`} className="log-entry">
            <span 
              className="log-level"
              style={{ color: getLevelColor(log.level) }}
            >
              {log.level}
            </span>
            <span className="log-timestamp">
              {format(new Date(log.timestamp), 'HH:mm:ss')}
            </span>
            <span className="log-service">{log.service}</span>
            <span className="log-message">{log.message}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

export default LogStreamWidget
EOF

# Metrics Widget
cat > frontend/src/components/widgets/MetricsWidget.jsx << 'EOF'
import React, { useEffect, useState } from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { useDashboard } from '../../hooks/useDashboard'

const MetricsWidget = ({ widget }) => {
  const { liveData } = useDashboard()
  const [metricsHistory, setMetricsHistory] = useState([])

  useEffect(() => {
    if (liveData.metrics) {
      const timestamp = new Date().toLocaleTimeString()
      const dataPoint = {
        time: timestamp,
        ...liveData.metrics
      }
      
      setMetricsHistory(prev => {
        const newHistory = [...prev, dataPoint].slice(-20)
        return newHistory
      })
    }
  }, [liveData])

  return (
    <div className="metrics-widget">
      <div className="current-metrics">
        {liveData.metrics && (
          <div className="metrics-grid">
            <div className="metric-item">
              <span className="metric-label">RPS</span>
              <span className="metric-value">
                {Math.round(liveData.metrics.requests_per_second)}
              </span>
            </div>
            <div className="metric-item">
              <span className="metric-label">Error Rate</span>
              <span className="metric-value">
                {(liveData.metrics.error_rate * 100).toFixed(1)}%
              </span>
            </div>
            <div className="metric-item">
              <span className="metric-label">Avg Response</span>
              <span className="metric-value">
                {Math.round(liveData.metrics.avg_response_time)}ms
              </span>
            </div>
            <div className="metric-item">
              <span className="metric-label">CPU</span>
              <span className="metric-value">
                {(liveData.metrics.cpu_usage * 100).toFixed(0)}%
              </span>
            </div>
          </div>
        )}
      </div>
      
      <div className="metrics-chart">
        <ResponsiveContainer width="100%" height={200}>
          <LineChart data={metricsHistory}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="time" />
            <YAxis />
            <Tooltip />
            <Line 
              type="monotone" 
              dataKey="requests_per_second" 
              stroke="#8884d8" 
              strokeWidth={2}
              dot={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}

export default MetricsWidget
EOF

# Status Widget
cat > frontend/src/components/widgets/StatusWidget.jsx << 'EOF'
import React from 'react'
import { useDashboard } from '../../hooks/useDashboard'

const StatusWidget = ({ widget }) => {
  const { liveData } = useDashboard()

  const services = [
    { name: 'Web API', status: 'healthy' },
    { name: 'Auth Service', status: 'healthy' },
    { name: 'Database', status: 'warning' },
    { name: 'Cache', status: 'healthy' }
  ]

  const getStatusColor = (status) => {
    switch (status) {
      case 'healthy': return '#00aa00'
      case 'warning': return '#ff8800'
      case 'error': return '#ff4444'
      default: return '#888888'
    }
  }

  return (
    <div className="status-widget">
      <div className="service-statuses">
        {services.map(service => (
          <div key={service.name} className="service-status">
            <div 
              className="status-indicator"
              style={{ backgroundColor: getStatusColor(service.status) }}
            ></div>
            <span className="service-name">{service.name}</span>
            <span className="status-text">{service.status}</span>
          </div>
        ))}
      </div>
      
      {liveData.metrics && (
        <div className="system-overview">
          <div className="overview-item">
            <span>System Load</span>
            <span>{(liveData.metrics.cpu_usage * 100).toFixed(0)}%</span>
          </div>
          <div className="overview-item">
            <span>Memory Usage</span>
            <span>{(liveData.metrics.memory_usage * 100).toFixed(0)}%</span>
          </div>
        </div>
      )}
    </div>
  )
}

export default StatusWidget
EOF

# Alerts Widget
cat > frontend/src/components/widgets/AlertsWidget.jsx << 'EOF'
import React, { useEffect, useState } from 'react'
import { useDashboard } from '../../hooks/useDashboard'

const AlertsWidget = ({ widget }) => {
  const { liveData } = useDashboard()
  const [alerts, setAlerts] = useState([])

  useEffect(() => {
    if (liveData.metrics) {
      const newAlerts = []
      
      if (liveData.metrics.error_rate > 0.05) {
        newAlerts.push({
          id: 'error-rate',
          level: 'warning',
          message: `High error rate: ${(liveData.metrics.error_rate * 100).toFixed(1)}%`,
          timestamp: new Date()
        })
      }
      
      if (liveData.metrics.cpu_usage > 0.8) {
        newAlerts.push({
          id: 'cpu-usage',
          level: 'critical',
          message: `High CPU usage: ${(liveData.metrics.cpu_usage * 100).toFixed(0)}%`,
          timestamp: new Date()
        })
      }
      
      if (liveData.metrics.avg_response_time > 150) {
        newAlerts.push({
          id: 'response-time',
          level: 'warning',
          message: `Slow response time: ${Math.round(liveData.metrics.avg_response_time)}ms`,
          timestamp: new Date()
        })
      }
      
      setAlerts(newAlerts)
    }
  }, [liveData])

  const getAlertColor = (level) => {
    switch (level) {
      case 'critical': return '#ff4444'
      case 'warning': return '#ff8800'
      case 'info': return '#0088ff'
      default: return '#888888'
    }
  }

  return (
    <div className="alerts-widget">
      {alerts.length === 0 ? (
        <div className="no-alerts">
          <span className="status-icon">✅</span>
          <span>All systems operational</span>
        </div>
      ) : (
        <div className="alert-list">
          {alerts.map(alert => (
            <div 
              key={alert.id} 
              className="alert-item"
              style={{ borderLeft: `4px solid ${getAlertColor(alert.level)}` }}
            >
              <div className="alert-content">
                <span className="alert-level" style={{ color: getAlertColor(alert.level) }}>
                  {alert.level.toUpperCase()}
                </span>
                <span className="alert-message">{alert.message}</span>
              </div>
              <div className="alert-time">
                {alert.timestamp.toLocaleTimeString()}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default AlertsWidget
EOF

# Dashboard List Component
cat > frontend/src/components/dashboard/DashboardList.jsx << 'EOF'
import React, { useState } from 'react'
import { useDashboard } from '../../hooks/useDashboard'
import { format } from 'date-fns'

const DashboardList = ({ onEdit }) => {
  const { dashboards, templates, deleteDashboard, createFromTemplate } = useDashboard()
  const [showTemplates, setShowTemplates] = useState(false)

  const handleCreateFromTemplate = async (template) => {
    const name = prompt(`Name for new dashboard based on ${template.name}:`)
    if (name) {
      await createFromTemplate(template.id, name)
    }
  }

  return (
    <div className="dashboard-list">
      <div className="list-header">
        <h2>My Dashboards</h2>
        <button 
          onClick={() => setShowTemplates(!showTemplates)}
          className="templates-btn"
        >
          {showTemplates ? 'Hide Templates' : 'Show Templates'}
        </button>
      </div>

      {showTemplates && (
        <div className="templates-section">
          <h3>Dashboard Templates</h3>
          <div className="templates-grid">
            {templates.map(template => (
              <div key={template.id} className="template-card">
                <h4>{template.name}</h4>
                <p>{template.description}</p>
                <div className="template-category">{template.category}</div>
                <button 
                  onClick={() => handleCreateFromTemplate(template)}
                  className="use-template-btn"
                >
                  Use Template
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="dashboards-grid">
        {dashboards.map(dashboard => (
          <div key={dashboard.id} className="dashboard-card">
            <div className="card-content">
              <h3>{dashboard.name}</h3>
              <p>{dashboard.description || 'No description'}</p>
              <div className="card-meta">
                <span>{dashboard.widgets?.length || 0} widgets</span>
                <span>Modified {format(new Date(dashboard.updated_at), 'MMM dd, yyyy')}</span>
              </div>
            </div>
            <div className="card-actions">
              <button 
                onClick={() => onEdit(dashboard)}
                className="edit-btn"
              >
                Edit
              </button>
              <button 
                onClick={() => {
                  if (confirm('Delete this dashboard?')) {
                    deleteDashboard(dashboard.id)
                  }
                }}
                className="delete-btn"
              >
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>

      {dashboards.length === 0 && (
        <div className="empty-state">
          <p>No dashboards yet. Create your first dashboard or use a template!</p>
        </div>
      )}
    </div>
  )
}

export default DashboardList
EOF

# CSS Styles
cat > frontend/src/styles/dashboard.css << 'EOF'
/* Global Styles */
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background-color: #f5f7fa;
  color: #2d3748;
}

.app {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-header {
  background: white;
  padding: 1rem 2rem;
  border-bottom: 1px solid #e2e8f0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.app-header h1 {
  color: #2b6cb0;
  font-size: 1.5rem;
}

.app-header nav {
  display: flex;
  gap: 1rem;
}

.app-header nav button {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 6px;
  background: #f7fafc;
  color: #4a5568;
  cursor: pointer;
  transition: all 0.2s;
}

.app-header nav button:hover {
  background: #edf2f7;
}

.app-header nav button.active {
  background: #3182ce;
  color: white;
}

.app-main {
  flex: 1;
  padding: 2rem;
}

/* Dashboard Builder */
.dashboard-builder {
  height: 100%;
}

.builder-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  background: white;
  padding: 1rem;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.dashboard-name-input {
  font-size: 1.2rem;
  font-weight: 600;
  border: none;
  background: transparent;
  color: #2d3748;
  padding: 0.5rem;
  border-radius: 4px;
}

.dashboard-name-input:focus {
  outline: 2px solid #3182ce;
  background: #f7fafc;
}

.builder-actions {
  display: flex;
  gap: 1rem;
}

.add-widget-btn, .save-btn {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.add-widget-btn {
  background: #48bb78;
  color: white;
}

.add-widget-btn:hover {
  background: #38a169;
}

.save-btn {
  background: #3182ce;
  color: white;
}

.save-btn:hover {
  background: #2c5282;
}

/* Grid Container */
.grid-container {
  background: #f7fafc;
  border-radius: 8px;
  padding: 1rem;
  min-height: 600px;
}

/* Widget Styles */
.widget-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow: hidden;
}

.widget {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.widget-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 1rem;
  background: #f7fafc;
  border-bottom: 1px solid #e2e8f0;
}

.widget-title {
  font-size: 0.9rem;
  font-weight: 600;
  color: #2d3748;
}

.widget-controls {
  display: flex;
  gap: 0.5rem;
}

.widget-btn {
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.25rem;
  border-radius: 3px;
  color: #718096;
  font-size: 0.8rem;
}

.widget-btn:hover {
  background: #e2e8f0;
}

.remove-btn:hover {
  color: #e53e3e;
  background: #fed7d7;
}

.widget-content {
  flex: 1;
  padding: 1rem;
  overflow: auto;
}

/* Widget Types */
.log-stream-widget {
  height: 100%;
}

.log-entries {
  height: 100%;
  overflow-y: auto;
  font-family: 'Monaco', 'Consolas', monospace;
  font-size: 0.75rem;
}

.log-entry {
  display: flex;
  gap: 0.5rem;
  padding: 0.25rem 0;
  border-bottom: 1px solid #f1f5f9;
}

.log-level {
  font-weight: 600;
  min-width: 60px;
}

.log-timestamp {
  color: #718096;
  min-width: 70px;
}

.log-service {
  color: #3182ce;
  min-width: 80px;
}

.log-message {
  flex: 1;
}

.metrics-widget {
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
}

.metric-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0.5rem;
  background: #f7fafc;
  border-radius: 6px;
}

.metric-label {
  font-size: 0.75rem;
  color: #718096;
  text-transform: uppercase;
  font-weight: 600;
}

.metric-value {
  font-size: 1.2rem;
  font-weight: 700;
  color: #2d3748;
}

.metrics-chart {
  flex: 1;
  min-height: 150px;
}

.status-widget {
  height: 100%;
}

.service-statuses {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.service-status {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem;
  background: #f7fafc;
  border-radius: 6px;
}

.status-indicator {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.service-name {
  font-weight: 500;
  flex: 1;
}

.status-text {
  font-size: 0.8rem;
  color: #718096;
  text-transform: capitalize;
}

.system-overview {
  border-top: 1px solid #e2e8f0;
  padding-top: 1rem;
}

.overview-item {
  display: flex;
  justify-content: space-between;
  padding: 0.5rem 0;
}

.alerts-widget {
  height: 100%;
}

.no-alerts {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #718096;
}

.status-icon {
  font-size: 2rem;
  margin-bottom: 0.5rem;
}

.alert-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.alert-item {
  padding: 0.75rem;
  background: #f7fafc;
  border-radius: 6px;
  border-left: 4px solid;
}

.alert-content {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  margin-bottom: 0.25rem;
}

.alert-level {
  font-size: 0.75rem;
  font-weight: 600;
}

.alert-message {
  flex: 1;
}

.alert-time {
  font-size: 0.75rem;
  color: #718096;
}

/* Widget Selector */
.widget-selector-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.widget-selector {
  background: white;
  border-radius: 8px;
  padding: 2rem;
  max-width: 600px;
  width: 90%;
  max-height: 90vh;
  overflow-y: auto;
}

.selector-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #718096;
}

.widget-types {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1rem;
}

.widget-type-card {
  padding: 1.5rem;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  text-align: center;
}

.widget-type-card:hover {
  border-color: #3182ce;
  background: #f7fafc;
}

.widget-icon {
  font-size: 2rem;
  margin-bottom: 0.5rem;
}

.widget-type-card h4 {
  margin-bottom: 0.5rem;
  color: #2d3748;
}

.widget-type-card p {
  color: #718096;
  font-size: 0.9rem;
}

/* Dashboard List */
.dashboard-list {
  max-width: 1200px;
}

.list-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.templates-btn {
  padding: 0.75rem 1.5rem;
  border: 2px solid #3182ce;
  background: transparent;
  color: #3182ce;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
}

.templates-btn:hover {
  background: #3182ce;
  color: white;
}

.templates-section {
  margin-bottom: 2rem;
  padding: 1.5rem;
  background: white;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.templates-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1rem;
  margin-top: 1rem;
}

.template-card {
  padding: 1.5rem;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: #f7fafc;
}

.template-card h4 {
  margin-bottom: 0.5rem;
  color: #2d3748;
}

.template-card p {
  color: #718096;
  margin-bottom: 1rem;
}

.template-category {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  background: #3182ce;
  color: white;
  border-radius: 12px;
  font-size: 0.75rem;
  margin-bottom: 1rem;
}

.use-template-btn {
  background: #48bb78;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 500;
}

.use-template-btn:hover {
  background: #38a169;
}

.dashboards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 1.5rem;
}

.dashboard-card {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transition: transform 0.2s, box-shadow 0.2s;
}

.dashboard-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0,0,0,0.15);
}

.card-content h3 {
  margin-bottom: 0.5rem;
  color: #2d3748;
}

.card-content p {
  color: #718096;
  margin-bottom: 1rem;
}

.card-meta {
  display: flex;
  justify-content: space-between;
  font-size: 0.8rem;
  color: #a0aec0;
  margin-bottom: 1rem;
}

.card-actions {
  display: flex;
  gap: 0.5rem;
}

.edit-btn {
  flex: 1;
  padding: 0.5rem;
  background: #3182ce;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.edit-btn:hover {
  background: #2c5282;
}

.delete-btn {
  padding: 0.5rem 1rem;
  background: transparent;
  color: #e53e3e;
  border: 1px solid #e53e3e;
  border-radius: 4px;
  cursor: pointer;
}

.delete-btn:hover {
  background: #e53e3e;
  color: white;
}

.empty-state {
  text-align: center;
  padding: 4rem;
  color: #718096;
}

/* Responsive Design */
@media (max-width: 768px) {
  .app-header {
    flex-direction: column;
    gap: 1rem;
  }
  
  .builder-header {
    flex-direction: column;
    gap: 1rem;
  }
  
  .metrics-grid {
    grid-template-columns: 1fr;
  }
  
  .widget-types {
    grid-template-columns: 1fr;
  }
  
  .dashboards-grid {
    grid-template-columns: 1fr;
  }
}
EOF

# Install frontend dependencies
echo "📦 Installing frontend dependencies..."
cd frontend
npm install

# Build frontend
echo "🔨 Building frontend..."
npm run build

# Return to root
cd ..

# Backend tests
cat > backend/tests/test_dashboard_api.py << 'EOF'
import pytest
import json
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_endpoint():
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_create_dashboard():
    dashboard_data = {
        "name": "Test Dashboard",
        "description": "Test dashboard description",
        "widgets": []
    }
    
    response = client.post("/api/dashboards", json=dashboard_data)
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Test Dashboard"
    assert "id" in data

def test_get_dashboards():
    response = client.get("/api/dashboards")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_get_templates():
    response = client.get("/api/templates")
    assert response.status_code == 200
    templates = response.json()
    assert len(templates) >= 2
    assert any(t["category"] == "devops" for t in templates)
EOF

# Create test script
cat > run_tests.py << 'EOF'
import subprocess
import sys
import os

def run_command(cmd, description):
    print(f"\n{'='*50}")
    print(f"🧪 {description}")
    print('='*50)
    
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            print("STDERR:", result.stderr)
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: {e}")
        print(f"STDOUT: {e.stdout}")
        print(f"STDERR: {e.stderr}")
        return False

def main():
    # Ensure we're in the right directory
    os.chdir('backend')
    
    print("🚀 Running Dashboard System Tests")
    
    tests = [
        ("python -m pytest tests/ -v", "Running backend tests"),
        ("python -c \"from app.main import app; print('✅ Backend imports successfully')\"", "Testing backend imports"),
    ]
    
    all_passed = True
    for cmd, desc in tests:
        if not run_command(cmd, desc):
            all_passed = False
    
    if all_passed:
        print("\n🎉 All tests passed!")
    else:
        print("\n❌ Some tests failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

# Demo script
cat > demo.py << 'EOF'
import asyncio
import subprocess
import time
import sys
import webbrowser
from threading import Thread

def start_backend():
    """Start the backend server"""
    print("🚀 Starting backend server...")
    import os
    os.chdir('backend')
    subprocess.run([sys.executable, "-m", "app.main"])

def start_frontend():
    """Start the frontend development server"""
    print("🎨 Starting frontend server...")
    import os
    os.chdir('frontend')
    subprocess.run(["npm", "run", "dev"])

def main():
    print("🎯 Day 95: Dashboard System Demo")
    print("=" * 50)
    
    # Start backend in a separate thread
    backend_thread = Thread(target=start_backend)
    backend_thread.daemon = True
    backend_thread.start()
    
    # Wait for backend to start
    time.sleep(5)
    
    # Start frontend in a separate thread
    frontend_thread = Thread(target=start_frontend)
    frontend_thread.daemon = True
    frontend_thread.start()
    
    # Wait for frontend to start
    time.sleep(10)
    
    print("\n🌐 Opening dashboard in browser...")
    print("Frontend: http://localhost:3000")
    print("Backend API: http://localhost:8000")
    
    try:
        webbrowser.open("http://localhost:3000")
    except:
        print("Could not open browser automatically")
    
    print("\n📝 Demo Features:")
    print("1. Create new dashboards")
    print("2. Add various widget types")
    print("3. Drag and resize widgets") 
    print("4. Use dashboard templates")
    print("5. View real-time log data")
    print("\n⌨️  Press Ctrl+C to stop servers")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Stopping servers...")

if __name__ == "__main__":
    main()
EOF

# Docker setup
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
    environment:
      - PYTHONPATH=/app

  frontend:
    build:
      context: ./frontend  
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    depends_on:
      - backend
EOF

# Backend Dockerfile
cat > backend/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONPATH=/app

EXPOSE 8000

CMD ["python", "-m", "app.main"]
EOF

# Frontend Dockerfile
cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
EOF

# Create .dockerignore files
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.venv
venv
__pycache__
*.pyc
.pytest_cache
EOF

# Main start script
cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Day 95: Starting Customizable Dashboard System"
echo "=================================================="

# Check if virtual environment exists, create if not
if [ ! -d "venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3.11 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install/upgrade pip
pip install --upgrade pip

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend && pip install -r requirements.txt && cd ..

# Run tests
echo "🧪 Running tests..."
python run_tests.py

# Start the demo
echo "🎬 Starting demo..."
python demo.py
EOF

# Stop script
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Dashboard System..."

# Kill any running Python processes for our app
pkill -f "app.main"
pkill -f "npm run dev"

# Kill processes on specific ports
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
lsof -ti:3000 | xargs kill -9 2>/dev/null || true

echo "✅ All services stopped"
EOF

# Make scripts executable
chmod +x start.sh stop.sh

echo "✅ Project setup complete!"
echo ""
echo "📁 Project structure:"
find . -type f -name "*.py" -o -name "*.jsx" -o -name "*.js" -o -name "*.json" -o -name "*.css" | head -20
echo "... and more files"
echo ""
echo "🚀 To start the system:"
echo "   ./start.sh"
echo ""
echo "🛑 To stop the system:"
echo "   ./stop.sh"
echo ""
echo "🐳 To run with Docker:"
echo "   docker-compose up --build"
echo ""
echo "🎯 Features implemented:"
echo "   ✅ Drag-and-drop dashboard builder"
echo "   ✅ Multiple widget types"
echo "   ✅ Real-time data streaming"
echo "   ✅ Dashboard templates"
echo "   ✅ Responsive design"
echo "   ✅ Save/load functionality"