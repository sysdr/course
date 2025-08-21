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
