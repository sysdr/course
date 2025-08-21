"""
Basic tests for the Log Dashboard System
"""

import pytest
from app.models.dashboard import Dashboard, Widget
from app.services.data_generator import LogDataGenerator

def test_dashboard_creation():
    """Test dashboard creation"""
    from datetime import datetime
    now = datetime.now()
    
    dashboard = Dashboard(
        id="test-1",
        name="Test Dashboard",
        description="A test dashboard",
        widgets=[],
        created_at=now,
        updated_at=now
    )
    assert dashboard.name == "Test Dashboard"
    assert dashboard.description == "A test dashboard"

def test_widget_creation():
    """Test widget creation"""
    from app.models.dashboard import WidgetConfig
    
    config = WidgetConfig(x=0, y=0, w=6, h=4)
    widget = Widget(
        id="widget-1",
        type="metrics",
        title="Test Widget",
        config=config
    )
    assert widget.type == "metrics"
    assert widget.title == "Test Widget"

def test_data_generator():
    """Test data generator service"""
    generator = LogDataGenerator()
    data = generator.generate_log_entry()
    
    assert "timestamp" in data
    assert "level" in data
    assert "message" in data
    assert "service" in data

def test_dashboard_with_widgets():
    """Test dashboard with widgets"""
    from datetime import datetime
    from app.models.dashboard import WidgetConfig
    
    now = datetime.now()
    
    config1 = WidgetConfig(x=0, y=0, w=6, h=4)
    widget1 = Widget(
        id="w1",
        type="metrics",
        title="CPU Usage",
        config=config1
    )
    
    config2 = WidgetConfig(x=6, y=0, w=6, h=4)
    widget2 = Widget(
        id="w2",
        type="log_stream",
        title="Log Stream",
        config=config2
    )
    
    dashboard = Dashboard(
        id="test-2",
        name="Dashboard with Widgets",
        description="Testing widget integration",
        widgets=[widget1, widget2],
        created_at=now,
        updated_at=now
    )
    
    assert len(dashboard.widgets) == 2
    assert dashboard.widgets[0].title == "CPU Usage"
    assert dashboard.widgets[1].type == "log_stream"
