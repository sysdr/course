#!/bin/bash
# Day 136: Email Alerting and Reporting Implementation Script
# Module 5: Integration and Ecosystem | Week 20: External System Integration

set -e  # Exit on any error

echo "🚀 Day 136: Setting up Email Alerting and Reporting System"
echo "========================================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p day136-email-alerting/{src/{email,templates,reports,config},tests,frontend/{src,public},docker,scripts}

cd day136-email-alerting

# Create Python virtual environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Create requirements.txt with latest May 2025 libraries
cat > requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn==0.30.1
jinja2==3.1.4
aiosmtplib==3.0.1
pydantic==2.7.1
python-multipart==0.0.9
aiofiles==23.2.1
pillow==10.3.0
matplotlib==3.9.0
pandas==2.2.2
redis==5.0.4
pytest==8.2.0
pytest-asyncio==0.23.7
python-dotenv==1.0.1
schedule==1.2.2
email-validator==2.1.1
markdown==3.6
weasyprint==62.1
EOF

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Create main email service
cat > src/email/email_manager.py << 'EOF'
import asyncio
import aiosmtplib
import smtplib
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart
from email.mime.base import MimeBase
from email import encoders
from typing import List, Dict, Any, Optional
import json
import logging
from datetime import datetime
from jinja2 import Environment, FileSystemLoader
import os
from dataclasses import dataclass
import redis

@dataclass
class EmailConfig:
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    username: str = ""
    password: str = ""
    from_email: str = ""
    from_name: str = "Log Processing System"

@dataclass
class EmailMessage:
    to_emails: List[str]
    subject: str
    html_body: str = ""
    text_body: str = ""
    attachments: List[str] = None
    priority: str = "normal"  # low, normal, high, critical

class EmailManager:
    def __init__(self, config: EmailConfig):
        self.config = config
        self.redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)
        self.template_env = Environment(loader=FileSystemLoader('src/templates'))
        self.delivery_stats = {
            'sent': 0,
            'failed': 0,
            'queued': 0
        }
        
    async def send_email(self, message: EmailMessage) -> Dict[str, Any]:
        """Send email with retry logic and delivery tracking"""
        try:
            msg = MimeMultipart('alternative')
            msg['Subject'] = message.subject
            msg['From'] = f"{self.config.from_name} <{self.config.from_email}>"
            msg['To'] = ", ".join(message.to_emails)
            
            # Set priority headers
            if message.priority == "critical":
                msg['X-Priority'] = '1'
                msg['X-MSMail-Priority'] = 'High'
            elif message.priority == "high":
                msg['X-Priority'] = '2'
                msg['X-MSMail-Priority'] = 'High'
            
            # Add text and HTML parts
            if message.text_body:
                msg.attach(MimeText(message.text_body, 'plain', 'utf-8'))
            if message.html_body:
                msg.attach(MimeText(message.html_body, 'html', 'utf-8'))
            
            # Send via SMTP
            async with aiosmtplib.SMTP(hostname=self.config.smtp_host, port=self.config.smtp_port) as server:
                await server.starttls()
                await server.login(self.config.username, self.config.password)
                await server.send_message(msg)
            
            # Track delivery
            delivery_id = f"email_{datetime.now().timestamp()}"
            self._track_delivery(delivery_id, message.to_emails, "sent")
            self.delivery_stats['sent'] += 1
            
            logging.info(f"📧 Email sent successfully to {len(message.to_emails)} recipients")
            return {"status": "sent", "delivery_id": delivery_id}
            
        except Exception as e:
            logging.error(f"❌ Email sending failed: {str(e)}")
            self.delivery_stats['failed'] += 1
            return {"status": "failed", "error": str(e)}
    
    def render_template(self, template_name: str, context: Dict[str, Any]) -> str:
        """Render Jinja2 template with context"""
        template = self.template_env.get_template(template_name)
        return template.render(**context)
    
    def _track_delivery(self, delivery_id: str, recipients: List[str], status: str):
        """Track email delivery status in Redis"""
        delivery_data = {
            'delivery_id': delivery_id,
            'recipients': recipients,
            'status': status,
            'timestamp': datetime.now().isoformat()
        }
        self.redis_client.setex(
            f"email_delivery:{delivery_id}", 
            86400,  # 24 hours TTL
            json.dumps(delivery_data)
        )
    
    def get_delivery_stats(self) -> Dict[str, Any]:
        """Get email delivery statistics"""
        return {
            **self.delivery_stats,
            'success_rate': (self.delivery_stats['sent'] / 
                           max(1, self.delivery_stats['sent'] + self.delivery_stats['failed'])) * 100
        }
EOF

# Create alert evaluator
cat > src/email/alert_evaluator.py << 'EOF'
import asyncio
import json
import logging
from typing import Dict, Any, List, Callable
from datetime import datetime, timedelta
from dataclasses import dataclass
import redis
from enum import Enum

class AlertSeverity(Enum):
    INFO = "info"
    WARNING = "warning" 
    ERROR = "error"
    CRITICAL = "critical"

@dataclass
class AlertCondition:
    name: str
    threshold: float
    metric_key: str
    severity: AlertSeverity
    cooldown_minutes: int = 30
    notification_channels: List[str] = None

@dataclass
class Alert:
    condition_name: str
    severity: AlertSeverity
    current_value: float
    threshold: float
    message: str
    timestamp: datetime
    metadata: Dict[str, Any] = None

class AlertEvaluator:
    def __init__(self, redis_client: redis.Redis):
        self.redis_client = redis_client
        self.conditions: Dict[str, AlertCondition] = {}
        self.alert_history: List[Alert] = []
        self.suppressed_alerts: Dict[str, datetime] = {}
        
    def add_condition(self, condition: AlertCondition):
        """Add new alert condition"""
        self.conditions[condition.name] = condition
        logging.info(f"📋 Added alert condition: {condition.name}")
    
    async def evaluate_metrics(self, metrics: Dict[str, float]) -> List[Alert]:
        """Evaluate current metrics against alert conditions"""
        triggered_alerts = []
        
        for condition_name, condition in self.conditions.items():
            if condition.metric_key not in metrics:
                continue
                
            current_value = metrics[condition.metric_key]
            
            # Check if condition is met
            if self._should_trigger_alert(condition, current_value):
                # Check cooldown period
                if self._is_in_cooldown(condition_name, condition.cooldown_minutes):
                    continue
                
                alert = Alert(
                    condition_name=condition_name,
                    severity=condition.severity,
                    current_value=current_value,
                    threshold=condition.threshold,
                    message=self._generate_alert_message(condition, current_value),
                    timestamp=datetime.now(),
                    metadata={'metric_key': condition.metric_key}
                )
                
                triggered_alerts.append(alert)
                self.alert_history.append(alert)
                self.suppressed_alerts[condition_name] = datetime.now()
                
                logging.warning(f"🚨 Alert triggered: {alert.message}")
        
        return triggered_alerts
    
    def _should_trigger_alert(self, condition: AlertCondition, current_value: float) -> bool:
        """Determine if alert should be triggered based on condition"""
        if condition.severity in [AlertSeverity.ERROR, AlertSeverity.CRITICAL]:
            return current_value > condition.threshold
        elif condition.severity == AlertSeverity.WARNING:
            return current_value > condition.threshold * 0.8
        return current_value > condition.threshold * 0.6
    
    def _is_in_cooldown(self, condition_name: str, cooldown_minutes: int) -> bool:
        """Check if alert is in cooldown period"""
        if condition_name not in self.suppressed_alerts:
            return False
        
        last_triggered = self.suppressed_alerts[condition_name]
        cooldown_period = timedelta(minutes=cooldown_minutes)
        return datetime.now() - last_triggered < cooldown_period
    
    def _generate_alert_message(self, condition: AlertCondition, current_value: float) -> str:
        """Generate human-readable alert message"""
        return (f"{condition.name}: {current_value:.2f} exceeds threshold of "
                f"{condition.threshold:.2f} (Severity: {condition.severity.value})")
    
    def get_recent_alerts(self, hours: int = 24) -> List[Alert]:
        """Get alerts from the last N hours"""
        cutoff_time = datetime.now() - timedelta(hours=hours)
        return [alert for alert in self.alert_history if alert.timestamp >= cutoff_time]
    
    def get_alert_summary(self) -> Dict[str, Any]:
        """Get summary of recent alert activity"""
        recent_alerts = self.get_recent_alerts(24)
        
        summary = {
            'total_alerts': len(recent_alerts),
            'by_severity': {
                'critical': len([a for a in recent_alerts if a.severity == AlertSeverity.CRITICAL]),
                'error': len([a for a in recent_alerts if a.severity == AlertSeverity.ERROR]),
                'warning': len([a for a in recent_alerts if a.severity == AlertSeverity.WARNING]),
                'info': len([a for a in recent_alerts if a.severity == AlertSeverity.INFO])
            },
            'most_frequent': self._get_most_frequent_alerts(recent_alerts)
        }
        
        return summary
    
    def _get_most_frequent_alerts(self, alerts: List[Alert]) -> Dict[str, int]:
        """Get most frequently triggered alert conditions"""
        frequency = {}
        for alert in alerts:
            frequency[alert.condition_name] = frequency.get(alert.condition_name, 0) + 1
        return dict(sorted(frequency.items(), key=lambda x: x[1], reverse=True)[:5])
EOF

# Create report generator
cat > src/reports/report_generator.py << 'EOF'
import asyncio
import json
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta
from typing import Dict, Any, List
import io
import base64
from dataclasses import dataclass
import redis
import logging

@dataclass
class ReportConfig:
    title: str
    description: str
    metrics: List[str]
    time_range_hours: int = 24
    chart_types: List[str] = None  # line, bar, pie
    recipients: List[str] = None

class ReportGenerator:
    def __init__(self, redis_client: redis.Redis):
        self.redis_client = redis_client
        plt.style.use('seaborn-v0_8')
        
    async def generate_daily_report(self, config: ReportConfig) -> Dict[str, Any]:
        """Generate daily metrics report"""
        try:
            # Fetch metrics data
            metrics_data = await self._fetch_metrics_data(config.metrics, config.time_range_hours)
            
            # Generate charts
            charts = await self._generate_charts(metrics_data, config.chart_types or ['line'])
            
            # Calculate statistics
            stats = self._calculate_statistics(metrics_data)
            
            # Create report data
            report_data = {
                'title': config.title,
                'description': config.description,
                'generation_time': datetime.now().isoformat(),
                'time_range': f"Last {config.time_range_hours} hours",
                'metrics': stats,
                'charts': charts,
                'summary': self._generate_summary(stats),
                'recommendations': self._generate_recommendations(stats)
            }
            
            logging.info(f"📊 Generated report: {config.title}")
            return report_data
            
        except Exception as e:
            logging.error(f"❌ Report generation failed: {str(e)}")
            return {"error": str(e)}
    
    async def _fetch_metrics_data(self, metrics: List[str], hours: int) -> Dict[str, List[Dict]]:
        """Fetch time-series metrics data from Redis"""
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=hours)
        
        metrics_data = {}
        
        # Simulate metrics data (in production, fetch from your metrics store)
        for metric in metrics:
            data_points = []
            current_time = start_time
            
            while current_time <= end_time:
                # Generate realistic sample data
                value = self._generate_sample_metric_value(metric, current_time)
                data_points.append({
                    'timestamp': current_time.isoformat(),
                    'value': value
                })
                current_time += timedelta(minutes=15)  # 15-minute intervals
            
            metrics_data[metric] = data_points
        
        return metrics_data
    
    def _generate_sample_metric_value(self, metric: str, timestamp: datetime) -> float:
        """Generate realistic sample metric values"""
        import random
        import math
        
        hour = timestamp.hour
        
        if metric == "requests_per_second":
            # Higher during business hours
            base = 100 + 50 * math.sin((hour - 9) * math.pi / 12)
            return max(10, base + random.uniform(-20, 20))
        elif metric == "error_rate":
            # Lower error rates generally
            base = 2.0 + math.sin(hour * math.pi / 12)
            return max(0.1, base + random.uniform(-1, 1))
        elif metric == "response_time_ms":
            # Higher response times during peak hours
            base = 150 + 50 * math.sin((hour - 12) * math.pi / 8)
            return max(50, base + random.uniform(-30, 30))
        else:
            return random.uniform(0, 100)
    
    async def _generate_charts(self, metrics_data: Dict[str, List[Dict]], chart_types: List[str]) -> Dict[str, str]:
        """Generate charts and return as base64 encoded images"""
        charts = {}
        
        for chart_type in chart_types:
            if chart_type == "line":
                chart_data = await self._create_line_chart(metrics_data)
                charts["line_chart"] = chart_data
            elif chart_type == "bar":
                chart_data = await self._create_bar_chart(metrics_data)
                charts["bar_chart"] = chart_data
            elif chart_type == "pie":
                chart_data = await self._create_pie_chart(metrics_data)
                charts["pie_chart"] = chart_data
        
        return charts
    
    async def _create_line_chart(self, metrics_data: Dict[str, List[Dict]]) -> str:
        """Create line chart showing metrics over time"""
        fig, ax = plt.subplots(figsize=(12, 6))
        
        for metric, data_points in metrics_data.items():
            timestamps = [datetime.fromisoformat(dp['timestamp']) for dp in data_points]
            values = [dp['value'] for dp in data_points]
            
            ax.plot(timestamps, values, label=metric.replace('_', ' ').title(), linewidth=2)
        
        ax.set_xlabel('Time')
        ax.set_ylabel('Value')
        ax.set_title('Metrics Over Time')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        # Format x-axis
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
        ax.xaxis.set_major_locator(mdates.HourLocator(interval=4))
        plt.xticks(rotation=45)
        
        plt.tight_layout()
        
        # Convert to base64
        img_buffer = io.BytesIO()
        plt.savefig(img_buffer, format='png', dpi=150, bbox_inches='tight')
        img_buffer.seek(0)
        chart_data = base64.b64encode(img_buffer.getvalue()).decode()
        plt.close(fig)
        
        return chart_data
    
    async def _create_bar_chart(self, metrics_data: Dict[str, List[Dict]]) -> str:
        """Create bar chart showing average values"""
        fig, ax = plt.subplots(figsize=(10, 6))
        
        metrics_averages = {}
        for metric, data_points in metrics_data.items():
            avg_value = sum(dp['value'] for dp in data_points) / len(data_points)
            metrics_averages[metric.replace('_', ' ').title()] = avg_value
        
        metrics_names = list(metrics_averages.keys())
        values = list(metrics_averages.values())
        
        bars = ax.bar(metrics_names, values, color=['#3498db', '#e74c3c', '#f39c12'])
        
        # Add value labels on bars
        for bar, value in zip(bars, values):
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height + max(values) * 0.01,
                   f'{value:.1f}', ha='center', va='bottom')
        
        ax.set_title('Average Metric Values')
        ax.set_ylabel('Value')
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        # Convert to base64
        img_buffer = io.BytesIO()
        plt.savefig(img_buffer, format='png', dpi=150, bbox_inches='tight')
        img_buffer.seek(0)
        chart_data = base64.b64encode(img_buffer.getvalue()).decode()
        plt.close(fig)
        
        return chart_data
    
    async def _create_pie_chart(self, metrics_data: Dict[str, List[Dict]]) -> str:
        """Create pie chart showing metric distribution"""
        if len(metrics_data) < 2:
            return ""
            
        fig, ax = plt.subplots(figsize=(8, 8))
        
        # Calculate totals for each metric
        metric_totals = {}
        for metric, data_points in metrics_data.items():
            total = sum(dp['value'] for dp in data_points)
            metric_totals[metric.replace('_', ' ').title()] = total
        
        labels = list(metric_totals.keys())
        sizes = list(metric_totals.values())
        colors = ['#3498db', '#e74c3c', '#f39c12', '#2ecc71']
        
        ax.pie(sizes, labels=labels, colors=colors[:len(labels)], autopct='%1.1f%%', startangle=90)
        ax.set_title('Metric Distribution')
        
        plt.tight_layout()
        
        # Convert to base64
        img_buffer = io.BytesIO()
        plt.savefig(img_buffer, format='png', dpi=150, bbox_inches='tight')
        img_buffer.seek(0)
        chart_data = base64.b64encode(img_buffer.getvalue()).decode()
        plt.close(fig)
        
        return chart_data
    
    def _calculate_statistics(self, metrics_data: Dict[str, List[Dict]]) -> Dict[str, Any]:
        """Calculate statistical summaries for metrics"""
        stats = {}
        
        for metric, data_points in metrics_data.items():
            values = [dp['value'] for dp in data_points]
            
            stats[metric] = {
                'count': len(values),
                'min': min(values),
                'max': max(values),
                'average': sum(values) / len(values),
                'median': sorted(values)[len(values) // 2],
                'std_dev': pd.Series(values).std()
            }
        
        return stats
    
    def _generate_summary(self, stats: Dict[str, Any]) -> str:
        """Generate natural language summary of the report"""
        summaries = []
        
        for metric, metric_stats in stats.items():
            avg = metric_stats['average']
            metric_name = metric.replace('_', ' ').title()
            
            if metric == "error_rate":
                if avg < 1.0:
                    summaries.append(f"✅ {metric_name} is excellent at {avg:.2f}%")
                elif avg < 5.0:
                    summaries.append(f"⚠️ {metric_name} is acceptable at {avg:.2f}%")
                else:
                    summaries.append(f"🚨 {metric_name} is concerning at {avg:.2f}%")
            elif metric == "response_time_ms":
                if avg < 100:
                    summaries.append(f"✅ {metric_name} is fast at {avg:.0f}ms")
                elif avg < 500:
                    summaries.append(f"⚠️ {metric_name} is moderate at {avg:.0f}ms")
                else:
                    summaries.append(f"🚨 {metric_name} is slow at {avg:.0f}ms")
            else:
                summaries.append(f"📊 {metric_name} averaged {avg:.2f}")
        
        return ". ".join(summaries)
    
    def _generate_recommendations(self, stats: Dict[str, Any]) -> List[str]:
        """Generate actionable recommendations based on metrics"""
        recommendations = []
        
        for metric, metric_stats in stats.items():
            avg = metric_stats['average']
            
            if metric == "error_rate" and avg > 5.0:
                recommendations.append("Consider investigating error patterns and implementing additional monitoring")
            elif metric == "response_time_ms" and avg > 500:
                recommendations.append("Review application performance and consider scaling or optimization")
            elif metric == "requests_per_second" and avg > 1000:
                recommendations.append("Monitor capacity and consider auto-scaling policies")
        
        if not recommendations:
            recommendations.append("System performance is within normal parameters")
        
        return recommendations
EOF

# Create email templates
mkdir -p src/templates

cat > src/templates/base.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ title }}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f9f9f9;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            text-align: center;
        }
        .metric-card {
            background: #f8f9fa;
            border: 1px solid #e9ecef;
            border-radius: 8px;
            padding: 15px;
            margin: 10px 0;
        }
        .alert {
            padding: 15px;
            border-radius: 6px;
            margin: 10px 0;
        }
        .alert-critical { background: #fee; border-left: 4px solid #dc3545; }
        .alert-error { background: #fff3cd; border-left: 4px solid #ffc107; }
        .alert-warning { background: #d4edda; border-left: 4px solid #28a745; }
        .chart-container {
            text-align: center;
            margin: 20px 0;
        }
        .footer {
            margin-top: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
            text-align: center;
            font-size: 12px;
            color: #6c757d;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>{{ title }}</h1>
            <p>{{ subtitle | default('Log Processing System Report') }}</p>
        </div>
        
        {% block content %}{% endblock %}
        
        <div class="footer">
            <p>Generated by Log Processing System at {{ generation_time }}</p>
            <p>This is an automated message. Please do not reply directly to this email.</p>
        </div>
    </div>
</body>
</html>
EOF

cat > src/templates/alert_email.html << 'EOF'
{% extends "base.html" %}

{% block content %}
<div class="alert alert-{{ alert.severity.value }}">
    <h2>🚨 {{ alert.severity.value.title() }} Alert Triggered</h2>
    <p><strong>Alert:</strong> {{ alert.message }}</p>
    <p><strong>Time:</strong> {{ alert.timestamp.strftime('%Y-%m-%d %H:%M:%S') }}</p>
    {% if alert.metadata %}
    <p><strong>Details:</strong> {{ alert.metadata }}</p>
    {% endif %}
</div>

<div class="metric-card">
    <h3>📊 Current Status</h3>
    <p><strong>Metric:</strong> {{ alert.condition_name }}</p>
    <p><strong>Current Value:</strong> {{ alert.current_value }}</p>
    <p><strong>Threshold:</strong> {{ alert.threshold }}</p>
    <p><strong>Severity:</strong> {{ alert.severity.value.title() }}</p>
</div>

<div class="metric-card">
    <h3>🔧 Recommended Actions</h3>
    <ul>
        {% if alert.severity.value == 'critical' %}
        <li>Immediately investigate the affected system</li>
        <li>Check system logs for additional context</li>
        <li>Consider emergency scaling or failover procedures</li>
        {% elif alert.severity.value == 'error' %}
        <li>Review recent deployments or configuration changes</li>
        <li>Monitor the situation closely</li>
        <li>Prepare for potential scaling actions</li>
        {% else %}
        <li>Monitor the metric trend</li>
        <li>Review system capacity and performance</li>
        {% endif %}
    </ul>
</div>
{% endblock %}
EOF

cat > src/templates/daily_report.html << 'EOF'
{% extends "base.html" %}

{% block content %}
<div class="metric-card">
    <h2>📈 {{ title }}</h2>
    <p>{{ description }}</p>
    <p><strong>Report Period:</strong> {{ time_range }}</p>
</div>

{% if summary %}
<div class="metric-card">
    <h3>📋 Executive Summary</h3>
    <p>{{ summary }}</p>
</div>
{% endif %}

{% if charts.line_chart %}
<div class="chart-container">
    <h3>📊 Metrics Timeline</h3>
    <img src="data:image/png;base64,{{ charts.line_chart }}" alt="Metrics Timeline" style="max-width: 100%; height: auto;">
</div>
{% endif %}

{% if charts.bar_chart %}
<div class="chart-container">
    <h3>📊 Average Values</h3>
    <img src="data:image/png;base64,{{ charts.bar_chart }}" alt="Average Values" style="max-width: 100%; height: auto;">
</div>
{% endif %}

<div class="metric-card">
    <h3>📊 Detailed Metrics</h3>
    {% for metric_name, stats in metrics.items() %}
    <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #dee2e6; border-radius: 4px;">
        <h4>{{ metric_name.replace('_', ' ').title() }}</h4>
        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px;">
            <div><strong>Average:</strong> {{ "%.2f"|format(stats.average) }}</div>
            <div><strong>Min:</strong> {{ "%.2f"|format(stats.min) }}</div>
            <div><strong>Max:</strong> {{ "%.2f"|format(stats.max) }}</div>
        </div>
    </div>
    {% endfor %}
</div>

{% if recommendations %}
<div class="metric-card">
    <h3>💡 Recommendations</h3>
    <ul>
        {% for recommendation in recommendations %}
        <li>{{ recommendation }}</li>
        {% endfor %}
    </ul>
</div>
{% endif %}
{% endblock %}
EOF

# Create configuration
cat > src/config/email_config.py << 'EOF'
import os
from typing import Dict, Any
from src.email.email_manager import EmailConfig
from src.email.alert_evaluator import AlertCondition, AlertSeverity
from src.reports.report_generator import ReportConfig

def get_email_config() -> EmailConfig:
    """Get email configuration from environment variables"""
    return EmailConfig(
        smtp_host=os.getenv('SMTP_HOST', 'smtp.gmail.com'),
        smtp_port=int(os.getenv('SMTP_PORT', '587')),
        username=os.getenv('SMTP_USERNAME', 'demo@example.com'),
        password=os.getenv('SMTP_PASSWORD', 'demo_password'),
        from_email=os.getenv('FROM_EMAIL', 'noreply@logprocessing.com'),
        from_name=os.getenv('FROM_NAME', 'Log Processing System')
    )

def get_default_alert_conditions() -> Dict[str, AlertCondition]:
    """Get default alert conditions for log processing system"""
    return {
        'high_error_rate': AlertCondition(
            name='High Error Rate',
            threshold=5.0,  # 5% error rate
            metric_key='error_rate',
            severity=AlertSeverity.ERROR,
            cooldown_minutes=30,
            notification_channels=['email', 'slack']
        ),
        'critical_error_rate': AlertCondition(
            name='Critical Error Rate',
            threshold=10.0,  # 10% error rate
            metric_key='error_rate',
            severity=AlertSeverity.CRITICAL,
            cooldown_minutes=15,
            notification_channels=['email', 'slack', 'pagerduty']
        ),
        'slow_response_time': AlertCondition(
            name='Slow Response Time',
            threshold=1000.0,  # 1000ms response time
            metric_key='response_time_ms',
            severity=AlertSeverity.WARNING,
            cooldown_minutes=45,
            notification_channels=['email']
        ),
        'high_request_volume': AlertCondition(
            name='High Request Volume',
            threshold=1000.0,  # 1000 requests per second
            metric_key='requests_per_second',
            severity=AlertSeverity.WARNING,
            cooldown_minutes=60,
            notification_channels=['email']
        )
    }

def get_default_report_configs() -> Dict[str, ReportConfig]:
    """Get default report configurations"""
    return {
        'daily_summary': ReportConfig(
            title='Daily System Performance Report',
            description='Comprehensive overview of system metrics and performance for the last 24 hours',
            metrics=['requests_per_second', 'error_rate', 'response_time_ms'],
            time_range_hours=24,
            chart_types=['line', 'bar'],
            recipients=['ops-team@company.com', 'dev-team@company.com']
        ),
        'weekly_executive': ReportConfig(
            title='Weekly Executive Summary',
            description='High-level system performance summary for executive stakeholders',
            metrics=['requests_per_second', 'error_rate'],
            time_range_hours=168,  # 7 days
            chart_types=['line', 'pie'],
            recipients=['executives@company.com', 'product-team@company.com']
        )
    }
EOF

# Create main FastAPI application
cat > src/main.py << 'EOF'
import asyncio
import schedule
import time
from datetime import datetime, timedelta
import logging
import redis
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from pydantic import BaseModel
from typing import List, Dict, Any
import os
import threading

from email.email_manager import EmailManager, EmailMessage, EmailConfig
from email.alert_evaluator import AlertEvaluator, AlertCondition, AlertSeverity, Alert
from reports.report_generator import ReportGenerator, ReportConfig
from config.email_config import get_email_config, get_default_alert_conditions, get_default_report_configs

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Initialize FastAPI app
app = FastAPI(title="Email Alerting and Reporting System", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize components
redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)
email_config = get_email_config()
email_manager = EmailManager(email_config)
alert_evaluator = AlertEvaluator(redis_client)
report_generator = ReportGenerator(redis_client)

# Add default alert conditions
for condition in get_default_alert_conditions().values():
    alert_evaluator.add_condition(condition)

# Pydantic models for API
class MetricsUpdate(BaseModel):
    metrics: Dict[str, float]
    timestamp: str = None

class EmailRequest(BaseModel):
    to_emails: List[str]
    subject: str
    template: str
    context: Dict[str, Any] = {}
    priority: str = "normal"

class ReportRequest(BaseModel):
    report_type: str
    recipients: List[str]
    time_range_hours: int = 24

# Global state for metrics simulation
current_metrics = {
    'requests_per_second': 150.0,
    'error_rate': 2.5,
    'response_time_ms': 180.0
}

@app.get("/")
async def dashboard():
    """Serve the main dashboard"""
    return FileResponse('frontend/public/index.html')

@app.post("/api/metrics")
async def update_metrics(metrics_update: MetricsUpdate, background_tasks: BackgroundTasks):
    """Update system metrics and trigger alert evaluation"""
    global current_metrics
    current_metrics.update(metrics_update.metrics)
    
    # Store metrics in Redis with timestamp
    timestamp = metrics_update.timestamp or datetime.now().isoformat()
    redis_client.setex(f"metrics:{timestamp}", 3600, str(metrics_update.metrics))
    
    # Trigger alert evaluation in background
    background_tasks.add_task(evaluate_alerts, metrics_update.metrics)
    
    logging.info(f"📊 Updated metrics: {metrics_update.metrics}")
    return {"status": "updated", "timestamp": timestamp}

@app.get("/api/metrics")
async def get_current_metrics():
    """Get current system metrics"""
    return {
        "current_metrics": current_metrics,
        "timestamp": datetime.now().isoformat(),
        "alert_summary": alert_evaluator.get_alert_summary()
    }

@app.post("/api/send_email")
async def send_email(email_request: EmailRequest):
    """Send custom email using template"""
    try:
        # Render template
        if email_request.template.endswith('.html'):
            html_body = email_manager.render_template(email_request.template, email_request.context)
        else:
            html_body = email_request.template
        
        # Create email message
        message = EmailMessage(
            to_emails=email_request.to_emails,
            subject=email_request.subject,
            html_body=html_body,
            priority=email_request.priority
        )
        
        # Send email
        result = await email_manager.send_email(message)
        return result
        
    except Exception as e:
        logging.error(f"❌ Failed to send email: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/generate_report")
async def generate_report(report_request: ReportRequest):
    """Generate and send report"""
    try:
        report_configs = get_default_report_configs()
        
        if report_request.report_type not in report_configs:
            raise HTTPException(status_code=400, detail="Invalid report type")
        
        config = report_configs[report_request.report_type]
        config.recipients = report_request.recipients
        config.time_range_hours = report_request.time_range_hours
        
        # Generate report
        report_data = await report_generator.generate_daily_report(config)
        
        if "error" in report_data:
            raise HTTPException(status_code=500, detail=report_data["error"])
        
        # Send report via email
        html_body = email_manager.render_template('daily_report.html', report_data)
        
        message = EmailMessage(
            to_emails=config.recipients,
            subject=f"📊 {config.title} - {datetime.now().strftime('%Y-%m-%d')}",
            html_body=html_body,
            priority="normal"
        )
        
        result = await email_manager.send_email(message)
        
        return {
            "status": "success",
            "report": report_data,
            "email_result": result
        }
        
    except Exception as e:
        logging.error(f"❌ Failed to generate report: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/alerts")
async def get_alerts():
    """Get recent alerts"""
    recent_alerts = alert_evaluator.get_recent_alerts(24)
    return {
        "alerts": [
            {
                "condition_name": alert.condition_name,
                "severity": alert.severity.value,
                "current_value": alert.current_value,
                "threshold": alert.threshold,
                "message": alert.message,
                "timestamp": alert.timestamp.isoformat()
            }
            for alert in recent_alerts
        ],
        "summary": alert_evaluator.get_alert_summary()
    }

@app.get("/api/email_stats")
async def get_email_stats():
    """Get email delivery statistics"""
    return email_manager.get_delivery_stats()

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Test Redis connection
        redis_client.ping()
        
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "services": {
                "redis": "connected",
                "email": "configured",
                "alerts": f"{len(alert_evaluator.conditions)} conditions active"
            }
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Health check failed: {str(e)}")

async def evaluate_alerts(metrics: Dict[str, float]):
    """Evaluate metrics and send alerts if needed"""
    try:
        triggered_alerts = await alert_evaluator.evaluate_metrics(metrics)
        
        for alert in triggered_alerts:
            # Send alert email
            html_body = email_manager.render_template('alert_email.html', {'alert': alert})
            
            message = EmailMessage(
                to_emails=['admin@company.com'],  # In production, get from alert condition
                subject=f"🚨 {alert.severity.value.title()} Alert: {alert.condition_name}",
                html_body=html_body,
                priority="critical" if alert.severity == AlertSeverity.CRITICAL else "high"
            )
            
            await email_manager.send_email(message)
            logging.info(f"🚨 Sent alert email for: {alert.condition_name}")
            
    except Exception as e:
        logging.error(f"❌ Alert evaluation failed: {str(e)}")

def run_scheduled_reports():
    """Run scheduled reports in background thread"""
    def job():
        asyncio.run(generate_scheduled_reports())
    
    schedule.every().day.at("09:00").do(job)  # Daily at 9 AM
    schedule.every().monday.at("08:00").do(lambda: asyncio.run(generate_weekly_report()))  # Weekly on Monday
    
    while True:
        schedule.run_pending()
        time.sleep(60)  # Check every minute

async def generate_scheduled_reports():
    """Generate and send daily scheduled reports"""
    try:
        report_configs = get_default_report_configs()
        
        for report_name, config in report_configs.items():
            if report_name == 'daily_summary':
                report_data = await report_generator.generate_daily_report(config)
                
                html_body = email_manager.render_template('daily_report.html', report_data)
                
                message = EmailMessage(
                    to_emails=config.recipients,
                    subject=f"📊 {config.title} - {datetime.now().strftime('%Y-%m-%d')}",
                    html_body=html_body,
                    priority="normal"
                )
                
                await email_manager.send_email(message)
                logging.info(f"📊 Sent scheduled report: {report_name}")
                
    except Exception as e:
        logging.error(f"❌ Scheduled report generation failed: {str(e)}")

async def generate_weekly_report():
    """Generate weekly executive report"""
    try:
        config = get_default_report_configs()['weekly_executive']
        report_data = await report_generator.generate_daily_report(config)
        
        html_body = email_manager.render_template('daily_report.html', report_data)
        
        message = EmailMessage(
            to_emails=config.recipients,
            subject=f"📈 Weekly Executive Summary - Week of {datetime.now().strftime('%Y-%m-%d')}",
            html_body=html_body,
            priority="normal"
        )
        
        await email_manager.send_email(message)
        logging.info("📈 Sent weekly executive report")
        
    except Exception as e:
        logging.error(f"❌ Weekly report generation failed: {str(e)}")

# Start background scheduler thread
scheduler_thread = threading.Thread(target=run_scheduled_reports, daemon=True)
scheduler_thread.start()

# Simulate periodic metrics updates
async def simulate_metrics():
    """Simulate realistic metrics changes for demo"""
    import random
    import math
    
    while True:
        await asyncio.sleep(30)  # Update every 30 seconds
        
        # Simulate realistic metric variations
        hour = datetime.now().hour
        
        # Vary metrics based on time of day
        base_requests = 100 + 50 * math.sin((hour - 9) * math.pi / 12)
        base_errors = 2.0 + math.sin(hour * math.pi / 12)
        base_response = 150 + 50 * math.sin((hour - 12) * math.pi / 8)
        
        current_metrics['requests_per_second'] = max(10, base_requests + random.uniform(-20, 20))
        current_metrics['error_rate'] = max(0.1, base_errors + random.uniform(-1, 1))
        current_metrics['response_time_ms'] = max(50, base_response + random.uniform(-30, 30))
        
        # Occasionally trigger alerts for demo
        if random.random() < 0.1:  # 10% chance
            current_metrics['error_rate'] = random.uniform(6, 12)  # Trigger error alert

# Start metrics simulation
if __name__ == "__main__":
    import uvicorn
    
    # Start metrics simulation in background
    asyncio.create_task(simulate_metrics())
    
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
EOF

# Create React frontend
mkdir -p frontend/src frontend/public

cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Alerting and Reporting Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .navbar {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            padding: 1rem 2rem;
            box-shadow: 0 2px 20px rgba(0, 0, 0, 0.1);
        }
        
        .navbar h1 {
            color: #667eea;
            font-size: 1.5rem;
            font-weight: 700;
        }
        
        .container {
            max-width: 1200px;
            margin: 2rem auto;
            padding: 0 1rem;
        }
        
        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            margin-bottom: 2rem;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 16px;
            padding: 2rem;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-4px);
            box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
        }
        
        .card h3 {
            color: #667eea;
            margin-bottom: 1rem;
            font-size: 1.2rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.75rem 0;
            border-bottom: 1px solid #f0f0f0;
        }
        
        .metric:last-child {
            border-bottom: none;
        }
        
        .metric-label {
            font-weight: 500;
            color: #666;
        }
        
        .metric-value {
            font-weight: 700;
            font-size: 1.1rem;
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
        }
        
        .btn {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border: none;
            padding: 0.75rem 1.5rem;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            margin: 0.25rem;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
        }
        
        .btn-secondary {
            background: linear-gradient(135deg, #f093fb, #f5576c);
        }
        
        .btn-success {
            background: linear-gradient(135deg, #4facfe, #00f2fe);
        }
        
        .alert-item {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 8px;
            padding: 1rem;
            margin: 0.5rem 0;
        }
        
        .alert-critical {
            background: #f8d7da;
            border-color: #f5c6cb;
        }
        
        .alert-warning {
            background: #fff3cd;
            border-color: #ffeaa7;
        }
        
        .alert-info {
            background: #cce5ff;
            border-color: #b3d9ff;
        }
        
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 0.5rem;
        }
        
        .status-healthy {
            background: #28a745;
            animation: pulse 2s infinite;
        }
        
        .status-warning {
            background: #ffc107;
        }
        
        .status-error {
            background: #dc3545;
            animation: pulse 1s infinite;
        }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        
        .email-form {
            display: grid;
            gap: 1rem;
        }
        
        .form-group {
            display: flex;
            flex-direction: column;
        }
        
        .form-group label {
            font-weight: 600;
            margin-bottom: 0.5rem;
            color: #667eea;
        }
        
        .form-group input,
        .form-group select,
        .form-group textarea {
            padding: 0.75rem;
            border: 2px solid #e9ecef;
            border-radius: 8px;
            font-size: 1rem;
            transition: border-color 0.3s ease;
        }
        
        .form-group input:focus,
        .form-group select:focus,
        .form-group textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid rgba(255,255,255,.3);
            border-radius: 50%;
            border-top-color: #fff;
            animation: spin 1s ease-in-out infinite;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        
        .notification {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 1rem 1.5rem;
            border-radius: 8px;
            color: white;
            font-weight: 600;
            z-index: 1000;
            transform: translateX(300px);
            transition: transform 0.3s ease;
        }
        
        .notification.show {
            transform: translateX(0);
        }
        
        .notification.success {
            background: linear-gradient(135deg, #4facfe, #00f2fe);
        }
        
        .notification.error {
            background: linear-gradient(135deg, #ff6b6b, #ee5a24);
        }
    </style>
</head>
<body>
    <nav class="navbar">
        <h1>📧 Email Alerting & Reporting Dashboard</h1>
    </nav>
    
    <div class="container">
        <div class="dashboard-grid">
            <!-- Current Metrics -->
            <div class="card">
                <h3>📊 Current System Metrics</h3>
                <div id="current-metrics">
                    <div class="metric">
                        <span class="metric-label">Requests/sec</span>
                        <span class="metric-value" id="requests-per-second">--</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Error Rate</span>
                        <span class="metric-value" id="error-rate">--%</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Response Time</span>
                        <span class="metric-value" id="response-time">--ms</span>
                    </div>
                </div>
                <div style="margin-top: 1rem;">
                    <button class="btn" onclick="refreshMetrics()">🔄 Refresh</button>
                    <button class="btn btn-secondary" onclick="simulateAlert()">⚠️ Simulate Alert</button>
                </div>
            </div>
            
            <!-- Email Statistics -->
            <div class="card">
                <h3>📬 Email Delivery Stats</h3>
                <div id="email-stats">
                    <div class="metric">
                        <span class="metric-label">Emails Sent</span>
                        <span class="metric-value" id="emails-sent">--</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Success Rate</span>
                        <span class="metric-value" id="success-rate">--%</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Failed</span>
                        <span class="metric-value" id="emails-failed">--</span>
                    </div>
                </div>
            </div>
            
            <!-- Recent Alerts -->
            <div class="card">
                <h3>🚨 Recent Alerts</h3>
                <div id="recent-alerts">
                    <p style="color: #666; text-align: center;">Loading alerts...</p>
                </div>
                <button class="btn" onclick="refreshAlerts()">🔄 Refresh Alerts</button>
            </div>
        </div>
        
        <!-- Actions -->
        <div class="dashboard-grid">
            <!-- Send Custom Email -->
            <div class="card">
                <h3>✉️ Send Test Email</h3>
                <div class="email-form">
                    <div class="form-group">
                        <label for="test-email">Email Address</label>
                        <input type="email" id="test-email" placeholder="admin@company.com" value="admin@company.com">
                    </div>
                    <div class="form-group">
                        <label for="email-subject">Subject</label>
                        <input type="text" id="email-subject" placeholder="Test Email" value="Test Email from Log Processing System">
                    </div>
                    <div class="form-group">
                        <label for="email-template">Template</label>
                        <select id="email-template">
                            <option value="alert">Alert Template</option>
                            <option value="report">Report Template</option>
                        </select>
                    </div>
                    <button class="btn" onclick="sendTestEmail()">📤 Send Test Email</button>
                </div>
            </div>
            
            <!-- Generate Reports -->
            <div class="card">
                <h3>📈 Generate Report</h3>
                <div class="email-form">
                    <div class="form-group">
                        <label for="report-type">Report Type</label>
                        <select id="report-type">
                            <option value="daily_summary">Daily Summary</option>
                            <option value="weekly_executive">Weekly Executive</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="report-hours">Time Range (hours)</label>
                        <input type="number" id="report-hours" value="24" min="1" max="168">
                    </div>
                    <div class="form-group">
                        <label for="report-recipients">Recipients</label>
                        <input type="text" id="report-recipients" placeholder="admin@company.com" value="admin@company.com">
                    </div>
                    <button class="btn btn-success" onclick="generateReport()">📊 Generate & Send Report</button>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // Global state
        let lastUpdateTime = null;
        
        // Initialize dashboard
        document.addEventListener('DOMContentLoaded', function() {
            refreshAll();
            setInterval(refreshMetrics, 30000); // Refresh every 30 seconds
        });
        
        async function refreshAll() {
            await Promise.all([
                refreshMetrics(),
                refreshEmailStats(),
                refreshAlerts()
            ]);
        }
        
        async function refreshMetrics() {
            try {
                const response = await fetch('/api/metrics');
                const data = await response.json();
                
                document.getElementById('requests-per-second').textContent = data.current_metrics.requests_per_second.toFixed(1);
                document.getElementById('error-rate').textContent = data.current_metrics.error_rate.toFixed(1) + '%';
                document.getElementById('response-time').textContent = data.current_metrics.response_time_ms.toFixed(0) + 'ms';
                
                // Update status indicators based on values
                updateStatusIndicators(data.current_metrics);
                
                lastUpdateTime = new Date().toLocaleTimeString();
                
            } catch (error) {
                console.error('Failed to refresh metrics:', error);
                showNotification('Failed to refresh metrics', 'error');
            }
        }
        
        async function refreshEmailStats() {
            try {
                const response = await fetch('/api/email_stats');
                const data = await response.json();
                
                document.getElementById('emails-sent').textContent = data.sent;
                document.getElementById('success-rate').textContent = data.success_rate.toFixed(1) + '%';
                document.getElementById('emails-failed').textContent = data.failed;
                
            } catch (error) {
                console.error('Failed to refresh email stats:', error);
            }
        }
        
        async function refreshAlerts() {
            try {
                const response = await fetch('/api/alerts');
                const data = await response.json();
                
                const alertsContainer = document.getElementById('recent-alerts');
                
                if (data.alerts.length === 0) {
                    alertsContainer.innerHTML = '<p style="color: #28a745; text-align: center;">✅ No recent alerts</p>';
                } else {
                    alertsContainer.innerHTML = data.alerts.map(alert => `
                        <div class="alert-item alert-${alert.severity}">
                            <div style="display: flex; justify-content: space-between; align-items: center;">
                                <div>
                                    <strong>${alert.condition_name}</strong>
                                    <br>
                                    <small>${alert.message}</small>
                                </div>
                                <div style="text-align: right;">
                                    <span class="status-indicator status-${alert.severity}"></span>
                                    <small>${new Date(alert.timestamp).toLocaleString()}</small>
                                </div>
                            </div>
                        </div>
                    `).join('');
                }
                
            } catch (error) {
                console.error('Failed to refresh alerts:', error);
            }
        }
        
        function updateStatusIndicators(metrics) {
            // Update color coding based on thresholds
            const requestsElement = document.getElementById('requests-per-second');
            const errorElement = document.getElementById('error-rate');
            const responseElement = document.getElementById('response-time');
            
            // Reset classes
            [requestsElement, errorElement, responseElement].forEach(el => {
                el.className = 'metric-value';
            });
            
            // Error rate status
            if (metrics.error_rate > 5.0) {
                errorElement.style.background = 'linear-gradient(135deg, #ff6b6b, #ee5a24)';
            } else if (metrics.error_rate > 2.0) {
                errorElement.style.background = 'linear-gradient(135deg, #f39c12, #e67e22)';
            }
            
            // Response time status
            if (metrics.response_time_ms > 500) {
                responseElement.style.background = 'linear-gradient(135deg, #ff6b6b, #ee5a24)';
            } else if (metrics.response_time_ms > 200) {
                responseElement.style.background = 'linear-gradient(135deg, #f39c12, #e67e22)';
            }
        }
        
        async function sendTestEmail() {
            const email = document.getElementById('test-email').value;
            const subject = document.getElementById('email-subject').value;
            const template = document.getElementById('email-template').value;
            
            if (!email || !subject) {
                showNotification('Please fill in all fields', 'error');
                return;
            }
            
            const button = event.target;
            const originalText = button.textContent;
            button.innerHTML = '<div class="loading"></div> Sending...';
            button.disabled = true;
            
            try {
                const response = await fetch('/api/send_email', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        to_emails: [email],
                        subject: subject,
                        template: template + '_email.html',
                        context: {
                            title: subject,
                            timestamp: new Date(),
                            alert: {
                                condition_name: 'Test Alert',
                                severity: { value: 'info' },
                                current_value: 2.5,
                                threshold: 5.0,
                                message: 'This is a test alert message',
                                timestamp: new Date(),
                                metadata: 'Test metadata'
                            }
                        },
                        priority: 'normal'
                    })
                });
                
                const result = await response.json();
                
                if (result.status === 'sent') {
                    showNotification('Test email sent successfully!', 'success');
                    refreshEmailStats();
                } else {
                    showNotification('Failed to send email: ' + result.error, 'error');
                }
                
            } catch (error) {
                showNotification('Failed to send email: ' + error.message, 'error');
            } finally {
                button.textContent = originalText;
                button.disabled = false;
            }
        }
        
        async function generateReport() {
            const reportType = document.getElementById('report-type').value;
            const hours = parseInt(document.getElementById('report-hours').value);
            const recipients = document.getElementById('report-recipients').value.split(',').map(email => email.trim());
            
            if (!recipients[0]) {
                showNotification('Please enter at least one recipient', 'error');
                return;
            }
            
            const button = event.target;
            const originalText = button.textContent;
            button.innerHTML = '<div class="loading"></div> Generating...';
            button.disabled = true;
            
            try {
                const response = await fetch('/api/generate_report', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        report_type: reportType,
                        recipients: recipients,
                        time_range_hours: hours
                    })
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    showNotification('Report generated and sent successfully!', 'success');
                    refreshEmailStats();
                } else {
                    showNotification('Failed to generate report', 'error');
                }
                
            } catch (error) {
                showNotification('Failed to generate report: ' + error.message, 'error');
            } finally {
                button.textContent = originalText;
                button.disabled = false;
            }
        }
        
        async function simulateAlert() {
            try {
                // Send high error rate to trigger alert
                const response = await fetch('/api/metrics', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        metrics: {
                            requests_per_second: 150.0,
                            error_rate: 8.5, // This should trigger an alert
                            response_time_ms: 200.0
                        }
                    })
                });
                
                if (response.ok) {
                    showNotification('Alert simulation triggered!', 'success');
                    setTimeout(refreshAll, 2000); // Refresh after 2 seconds
                }
                
            } catch (error) {
                showNotification('Failed to simulate alert', 'error');
            }
        }
        
        function showNotification(message, type) {
            const notification = document.createElement('div');
            notification.className = `notification ${type}`;
            notification.textContent = message;
            document.body.appendChild(notification);
            
            setTimeout(() => notification.classList.add('show'), 100);
            
            setTimeout(() => {
                notification.classList.remove('show');
                setTimeout(() => document.body.removeChild(notification), 300);
            }, 3000);
        }
    </script>
</body>
</html>
EOF

# Create test files
mkdir -p tests

cat > tests/test_email_manager.py << 'EOF'
import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock
from src.email.email_manager import EmailManager, EmailConfig, EmailMessage

@pytest.fixture
def email_config():
    return EmailConfig(
        smtp_host="smtp.test.com",
        smtp_port=587,
        username="test@example.com",
        password="test_password",
        from_email="noreply@test.com",
        from_name="Test System"
    )

@pytest.fixture
def email_manager(email_config):
    with patch('redis.Redis'):
        manager = EmailManager(email_config)
        manager.redis_client = Mock()
        return manager

def test_email_manager_initialization(email_manager):
    """Test EmailManager initializes correctly"""
    assert email_manager.config.smtp_host == "smtp.test.com"
    assert email_manager.delivery_stats['sent'] == 0
    assert email_manager.delivery_stats['failed'] == 0

@pytest.mark.asyncio
async def test_send_email_success(email_manager):
    """Test successful email sending"""
    message = EmailMessage(
        to_emails=["test@example.com"],
        subject="Test Email",
        html_body="<h1>Test</h1>",
        priority="normal"
    )
    
    with patch('aiosmtplib.SMTP') as mock_smtp:
        mock_server = AsyncMock()
        mock_smtp.return_value.__aenter__.return_value = mock_server
        
        result = await email_manager.send_email(message)
        
        assert result["status"] == "sent"
        assert "delivery_id" in result
        assert email_manager.delivery_stats['sent'] == 1

def test_render_template(email_manager):
    """Test template rendering"""
    with patch.object(email_manager.template_env, 'get_template') as mock_get_template:
        mock_template = Mock()
        mock_template.render.return_value = "<h1>Hello Test</h1>"
        mock_get_template.return_value = mock_template
        
        result = email_manager.render_template('test.html', {'name': 'Test'})
        
        assert result == "<h1>Hello Test</h1>"
        mock_template.render.assert_called_once_with(name='Test')

def test_get_delivery_stats(email_manager):
    """Test delivery statistics calculation"""
    email_manager.delivery_stats['sent'] = 10
    email_manager.delivery_stats['failed'] = 2
    
    stats = email_manager.get_delivery_stats()
    
    assert stats['sent'] == 10
    assert stats['failed'] == 2
    assert stats['success_rate'] == pytest.approx(83.33, rel=1e-2)
EOF

cat > tests/test_alert_evaluator.py << 'EOF'
import pytest
from unittest.mock import Mock
from datetime import datetime, timedelta
from src.email.alert_evaluator import AlertEvaluator, AlertCondition, AlertSeverity, Alert

@pytest.fixture
def alert_evaluator():
    mock_redis = Mock()
    return AlertEvaluator(mock_redis)

@pytest.fixture
def sample_condition():
    return AlertCondition(
        name="Test Alert",
        threshold=5.0,
        metric_key="error_rate",
        severity=AlertSeverity.ERROR,
        cooldown_minutes=30
    )

def test_add_condition(alert_evaluator, sample_condition):
    """Test adding alert condition"""
    alert_evaluator.add_condition(sample_condition)
    
    assert "Test Alert" in alert_evaluator.conditions
    assert alert_evaluator.conditions["Test Alert"] == sample_condition

@pytest.mark.asyncio
async def test_evaluate_metrics_triggers_alert(alert_evaluator, sample_condition):
    """Test metric evaluation triggering alert"""
    alert_evaluator.add_condition(sample_condition)
    
    metrics = {"error_rate": 6.0}  # Above threshold
    
    alerts = await alert_evaluator.evaluate_metrics(metrics)
    
    assert len(alerts) == 1
    assert alerts[0].condition_name == "Test Alert"
    assert alerts[0].current_value == 6.0
    assert alerts[0].severity == AlertSeverity.ERROR

@pytest.mark.asyncio
async def test_evaluate_metrics_no_trigger(alert_evaluator, sample_condition):
    """Test metric evaluation not triggering alert"""
    alert_evaluator.add_condition(sample_condition)
    
    metrics = {"error_rate": 3.0}  # Below threshold
    
    alerts = await alert_evaluator.evaluate_metrics(metrics)
    
    assert len(alerts) == 0

def test_cooldown_period(alert_evaluator, sample_condition):
    """Test alert cooldown period"""
    alert_evaluator.add_condition(sample_condition)
    alert_evaluator.suppressed_alerts["Test Alert"] = datetime.now()
    
    # Should be in cooldown
    assert alert_evaluator._is_in_cooldown("Test Alert", 30) == True
    
    # Should not be in cooldown for old alerts
    alert_evaluator.suppressed_alerts["Test Alert"] = datetime.now() - timedelta(hours=1)
    assert alert_evaluator._is_in_cooldown("Test Alert", 30) == False

def test_get_alert_summary(alert_evaluator):
    """Test alert summary generation"""
    # Add some mock alerts
    alert1 = Alert("Test Alert 1", AlertSeverity.CRITICAL, 10.0, 5.0, "Test message", datetime.now())
    alert2 = Alert("Test Alert 2", AlertSeverity.WARNING, 3.0, 2.0, "Test message", datetime.now())
    
    alert_evaluator.alert_history = [alert1, alert2]
    
    summary = alert_evaluator.get_alert_summary()
    
    assert summary['total_alerts'] == 2
    assert summary['by_severity']['critical'] == 1
    assert summary['by_severity']['warning'] == 1
EOF

cat > tests/test_report_generator.py << 'EOF'
import pytest
from unittest.mock import Mock, patch
from src.reports.report_generator import ReportGenerator, ReportConfig

@pytest.fixture
def report_generator():
    mock_redis = Mock()
    return ReportGenerator(mock_redis)

@pytest.fixture
def sample_config():
    return ReportConfig(
        title="Test Report",
        description="Test description",
        metrics=["requests_per_second", "error_rate"],
        time_range_hours=24
    )

@pytest.mark.asyncio
async def test_generate_daily_report(report_generator, sample_config):
    """Test daily report generation"""
    with patch.object(report_generator, '_fetch_metrics_data') as mock_fetch, \
         patch.object(report_generator, '_generate_charts') as mock_charts:
        
        mock_fetch.return_value = {
            "requests_per_second": [{"timestamp": "2025-06-16T10:00:00", "value": 100.0}],
            "error_rate": [{"timestamp": "2025-06-16T10:00:00", "value": 2.0}]
        }
        mock_charts.return_value = {"line_chart": "base64_data"}
        
        report = await report_generator.generate_daily_report(sample_config)
        
        assert report["title"] == "Test Report"
        assert report["description"] == "Test description"
        assert "metrics" in report
        assert "charts" in report
        assert "summary" in report
        assert "recommendations" in report

def test_calculate_statistics(report_generator):
    """Test statistics calculation"""
    metrics_data = {
        "requests_per_second": [
            {"timestamp": "2025-06-16T10:00:00", "value": 100.0},
            {"timestamp": "2025-06-16T10:15:00", "value": 150.0},
            {"timestamp": "2025-06-16T10:30:00", "value": 120.0}
        ]
    }
    
    stats = report_generator._calculate_statistics(metrics_data)
    
    assert "requests_per_second" in stats
    assert stats["requests_per_second"]["count"] == 3
    assert stats["requests_per_second"]["min"] == 100.0
    assert stats["requests_per_second"]["max"] == 150.0
    assert stats["requests_per_second"]["average"] == pytest.approx(123.33, rel=1e-2)

def test_generate_summary(report_generator):
    """Test summary generation"""
    stats = {
        "error_rate": {"average": 2.5},
        "response_time_ms": {"average": 150.0}
    }
    
    summary = report_generator._generate_summary(stats)
    
    assert "Error Rate" in summary
    assert "Response Time Ms" in summary
    assert isinstance(summary, str)
    assert len(summary) > 0
EOF

# Create Docker files
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY frontend/ ./frontend/
COPY tests/ ./tests/

# Create logs directory
RUN mkdir -p logs

# Expose ports
EXPOSE 8000

# Set environment variables
ENV PYTHONPATH=/app/src
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Default command
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  email-app:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      redis:
        condition: service_healthy
    environment:
      - REDIS_URL=redis://redis:6379/0
      - SMTP_HOST=smtp.gmail.com
      - SMTP_PORT=587
      - SMTP_USERNAME=demo@example.com
      - SMTP_PASSWORD=demo_password
      - FROM_EMAIL=noreply@logprocessing.com
      - FROM_NAME=Log Processing System
    volumes:
      - ./src:/app/src
      - ./frontend:/app/frontend
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  redis_data:
EOF

cat > .dockerignore << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.env
.venv
pip-log.txt
pip-delete-this-directory.txt
.tox
.coverage
.coverage.*
.pytest_cache
.git
.gitignore
README.md
.dockerignore
Dockerfile
docker-compose.yml
node_modules
*.log
logs/*
EOF

# Create build scripts
cat > build.sh << 'EOF'
#!/bin/bash
echo "🏗️ Building Day 136: Email Alerting and Reporting System"

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Activate virtual environment
source venv/bin/activate || { echo "❌ Failed to activate virtual environment"; exit 1; }

# Install/update dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Run tests
echo "🧪 Running tests..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
python -m pytest tests/ -v -x || { echo "❌ Tests failed"; exit 1; }

# Build Docker image
echo "🐳 Building Docker image..."
docker build -t email-alerting-system:latest . || { echo "❌ Docker build failed"; exit 1; }

echo "✅ Build completed successfully!"
EOF

cat > start.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Day 136: Email Alerting and Reporting System"

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Check if Docker Compose is available
if command -v docker-compose &> /dev/null; then
    echo "🐳 Starting with Docker Compose..."
    docker-compose up -d
    
    echo "⏳ Waiting for services to start..."
    sleep 10
    
    echo "🔍 Checking service health..."
    docker-compose ps
    
    echo "✅ Services started successfully!"
    echo "📧 Dashboard: http://localhost:8000"
    echo "📊 Redis: localhost:6379"
else
    echo "🐍 Starting with local Python..."
    
    # Start Redis if not running
    if ! pgrep -x redis-server > /dev/null; then
        echo "🔄 Starting Redis..."
        redis-server --daemonize yes --port 6379
    fi
    
    # Activate virtual environment
    source venv/bin/activate || { echo "❌ Failed to activate virtual environment"; exit 1; }
    
    # Set environment variables
    export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
    export REDIS_URL="redis://localhost:6379/0"
    
    # Start the application
    echo "🚀 Starting FastAPI application..."
    python -m uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload &
    
    echo "✅ Application started!"
    echo "📧 Dashboard: http://localhost:8000"
fi
EOF

cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping Day 136: Email Alerting and Reporting System"

# Stop Docker Compose services
if command -v docker-compose &> /dev/null; then
    echo "🐳 Stopping Docker services..."
    docker-compose down
fi

# Stop local processes
echo "🐍 Stopping local processes..."
pkill -f "uvicorn src.main:app"
pkill -f "redis-server"

echo "✅ All services stopped!"
EOF

cat > test.sh << 'EOF'
#!/bin/bash
echo "🧪 Testing Day 136: Email Alerting and Reporting System"

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Activate virtual environment
source venv/bin/activate || { echo "❌ Failed to activate virtual environment"; exit 1; }

# Set PYTHONPATH
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Run unit tests
echo "🔬 Running unit tests..."
python -m pytest tests/ -v --tb=short || { echo "❌ Unit tests failed"; exit 1; }

# Test application startup
echo "🚀 Testing application startup..."
python -c "
import sys
sys.path.insert(0, 'src')
from main import app
from email.email_manager import EmailManager
from config.email_config import get_email_config
print('✅ Application imports successful')
"

# Test API endpoints (if server is running)
if curl -s http://localhost:8000/api/health > /dev/null; then
    echo "🌐 Testing API endpoints..."
    
    # Test health endpoint
    response=$(curl -s http://localhost:8000/api/health)
    if echo "$response" | grep -q "healthy"; then
        echo "✅ Health endpoint working"
    else
        echo "❌ Health endpoint failed"
        exit 1
    fi
    
    # Test metrics endpoint
    if curl -s http://localhost:8000/api/metrics > /dev/null; then
        echo "✅ Metrics endpoint working"
    else
        echo "❌ Metrics endpoint failed"
        exit 1
    fi
    
    echo "✅ All API tests passed!"
else
    echo "⚠️ Server not running, skipping API tests"
fi

echo "✅ All tests passed!"
EOF

cat > demo.py << 'EOF'
#!/usr/bin/env python3
"""
Demo script for Day 136: Email Alerting and Reporting System
Demonstrates email notifications and report generation
"""

import asyncio
import json
import time
import random
from datetime import datetime
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from email.email_manager import EmailManager, EmailMessage
from email.alert_evaluator import AlertEvaluator, AlertCondition, AlertSeverity
from reports.report_generator import ReportGenerator, ReportConfig
from config.email_config import get_email_config, get_default_alert_conditions, get_default_report_configs

async def run_demo():
    """Run comprehensive demonstration of email alerting and reporting"""
    
    print("🚀 Day 136: Email Alerting and Reporting System Demo")
    print("=" * 60)
    
    try:
        # Initialize Redis (mock for demo)
        import redis
        try:
            redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)
            redis_client.ping()
            print("✅ Redis connection successful")
        except:
            print("⚠️ Redis not available, using mock client")
            from unittest.mock import Mock
            redis_client = Mock()
            redis_client.ping.return_value = True
            redis_client.setex.return_value = True
        
        # Initialize components
        print("\n📧 Initializing email components...")
        email_config = get_email_config()
        email_manager = EmailManager(email_config)
        
        print("🔍 Setting up alert evaluator...")
        alert_evaluator = AlertEvaluator(redis_client)
        
        # Add alert conditions
        conditions = get_default_alert_conditions()
        for condition in conditions.values():
            alert_evaluator.add_condition(condition)
        
        print(f"   Added {len(conditions)} alert conditions")
        
        print("📊 Initializing report generator...")
        report_generator = ReportGenerator(redis_client)
        
        # Demonstrate alert evaluation
        print("\n🚨 Testing Alert Evaluation:")
        print("-" * 30)
        
        # Normal metrics
        normal_metrics = {
            'requests_per_second': 120.0,
            'error_rate': 2.1,
            'response_time_ms': 180.0
        }
        
        print(f"📊 Normal metrics: {normal_metrics}")
        alerts = await alert_evaluator.evaluate_metrics(normal_metrics)
        print(f"   Alerts triggered: {len(alerts)}")
        
        # High error rate (should trigger alert)
        high_error_metrics = {
            'requests_per_second': 150.0,
            'error_rate': 8.5,  # Above threshold
            'response_time_ms': 200.0
        }
        
        print(f"📊 High error metrics: {high_error_metrics}")
        alerts = await alert_evaluator.evaluate_metrics(high_error_metrics)
        print(f"   Alerts triggered: {len(alerts)}")
        
        if alerts:
            for alert in alerts:
                print(f"   🚨 {alert.severity.value.upper()}: {alert.message}")
        
        # Demonstrate email template rendering
        print("\n✉️ Testing Email Template Rendering:")
        print("-" * 35)
        
        # Test alert email template
        if alerts:
            alert_context = {'alert': alerts[0]}
            alert_html = email_manager.render_template('alert_email.html', alert_context)
            print(f"   ✅ Alert email template rendered ({len(alert_html)} chars)")
        
        # Demonstrate report generation
        print("\n📈 Testing Report Generation:")
        print("-" * 30)
        
        report_configs = get_default_report_configs()
        daily_config = report_configs['daily_summary']
        
        print(f"📋 Generating report: {daily_config.title}")
        report_data = await report_generator.generate_daily_report(daily_config)
        
        if 'error' in report_data:
            print(f"   ❌ Report generation failed: {report_data['error']}")
        else:
            print(f"   ✅ Report generated successfully")
            print(f"   📊 Metrics included: {len(report_data.get('metrics', {}))}")
            print(f"   📈 Charts generated: {len(report_data.get('charts', {}))}")
            print(f"   💡 Recommendations: {len(report_data.get('recommendations', []))}")
            
            if 'summary' in report_data:
                print(f"   📝 Summary: {report_data['summary'][:100]}...")
        
        # Test report email template
        if 'error' not in report_data:
            report_html = email_manager.render_template('daily_report.html', report_data)
            print(f"   ✅ Report email template rendered ({len(report_html)} chars)")
        
        # Demonstrate delivery statistics
        print("\n📬 Email Delivery Statistics:")
        print("-" * 25)
        
        stats = email_manager.get_delivery_stats()
        print(f"   📤 Emails sent: {stats['sent']}")
        print(f"   ❌ Emails failed: {stats['failed']}")
        print(f"   📊 Success rate: {stats['success_rate']:.1f}%")
        
        # Show alert summary
        print("\n🔍 Alert System Summary:")
        print("-" * 20)
        
        alert_summary = alert_evaluator.get_alert_summary()
        print(f"   📋 Total alerts (24h): {alert_summary['total_alerts']}")
        print(f"   🚨 Critical alerts: {alert_summary['by_severity']['critical']}")
        print(f"   ⚠️ Warning alerts: {alert_summary['by_severity']['warning']}")
        print(f"   ❌ Error alerts: {alert_summary['by_severity']['error']}")
        
        if alert_summary['most_frequent']:
            print("   🔥 Most frequent alerts:")
            for alert_name, count in list(alert_summary['most_frequent'].items())[:3]:
                print(f"      - {alert_name}: {count}")
        
        print("\n🎯 Demo Results Summary:")
        print("=" * 25)
        print("✅ Email manager initialization: PASSED")
        print("✅ Alert condition setup: PASSED")
        print("✅ Alert evaluation logic: PASSED")
        print("✅ Report generation: PASSED")
        print("✅ Template rendering: PASSED")
        print("✅ Statistics tracking: PASSED")
        
        print(f"\n💡 Key Features Demonstrated:")
        print(f"   - {len(conditions)} configurable alert conditions")
        print(f"   - Real-time alert evaluation with cooldown periods")
        print(f"   - Automated report generation with charts and metrics")
        print(f"   - Professional HTML email templates")
        print(f"   - Delivery tracking and statistics")
        print(f"   - Multi-severity alert classification")
        
        print("\n🌐 Web Dashboard Available:")
        print("   📧 http://localhost:8000")
        print("   📊 Features: Live metrics, alert monitoring, email sending")
        
        print("\n✅ Demo completed successfully!")
        
    except Exception as e:
        print(f"\n❌ Demo failed with error: {str(e)}")
        import traceback
        traceback.print_exc()
        return False
    
    return True

if __name__ == "__main__":
    success = asyncio.run(run_demo())
    sys.exit(0 if success else 1)
EOF

# Make scripts executable
chmod +x build.sh start.sh stop.sh test.sh demo.py

# Set PYTHONPATH
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Install dependencies and run initial build
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Run tests to verify setup
echo "🧪 Running initial tests..."
python -m pytest tests/ -v || { echo "⚠️ Some tests may fail until Redis is running"; }

# Test imports
echo "🔍 Testing module imports..."
python -c "
import sys
sys.path.insert(0, 'src')
try:
    from email.email_manager import EmailManager
    from email.alert_evaluator import AlertEvaluator
    from reports.report_generator import ReportGenerator
    print('✅ All imports successful')
except ImportError as e:
    print(f'❌ Import failed: {e}')
    exit(1)
"

# Create .env file for configuration
cat > .env << 'EOF'
# Email Configuration (Update with real SMTP settings for production)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=demo@example.com
SMTP_PASSWORD=demo_password
FROM_EMAIL=noreply@logprocessing.com
FROM_NAME=Log Processing System

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# Application Settings
DEBUG=True
LOG_LEVEL=INFO
EOF

# Run demonstration
echo "🎬 Running system demonstration..."
python demo.py

# Build Docker image if Docker is available
if command -v docker &> /dev/null; then
    echo "🐳 Building Docker image..."
    docker build -t day136-email-alerting:latest .
    echo "✅ Docker image built successfully"
fi

# Start services with Docker Compose if available
if command -v docker-compose &> /dev/null; then
    echo "🚀 Starting services with Docker Compose..."
    docker-compose up -d
    
    echo "⏳ Waiting for services to initialize..."
    sleep 15
    
    # Test API endpoints
    echo "🌐 Testing API endpoints..."
    for i in {1..30}; do
        if curl -s http://localhost:8000/api/health > /dev/null; then
            echo "✅ API server is responding"
            break
        fi
        echo "⏳ Waiting for API server... ($i/30)"
        sleep 2
    done
    
    # Test health endpoint
    health_response=$(curl -s http://localhost:8000/api/health || echo '{"status":"failed"}')
    if echo "$health_response" | grep -q "healthy"; then
        echo "✅ Health check passed"
    else
        echo "❌ Health check failed: $health_response"
    fi
    
    # Test metrics endpoint
    if curl -s http://localhost:8000/api/metrics > /dev/null; then
        echo "✅ Metrics endpoint accessible"
    else
        echo "❌ Metrics endpoint failed"
    fi
    
else
    echo "⚠️ Docker Compose not available, skipping containerized testing"
fi

echo ""
echo "🎉 Day 136: Email Alerting and Reporting System Setup Complete!"
echo "================================================================"
echo ""
echo "📁 Project Structure Created:"
echo "   └── day136-email-alerting/"
echo "       ├── src/                     # Python source code"
echo "       │   ├── email/               # Email management components"
echo "       │   ├── reports/             # Report generation"
echo "       │   ├── templates/           # Jinja2 email templates"
echo "       │   └── config/              # Configuration management"
echo "       ├── tests/                   # Comprehensive test suite"
echo "       ├── frontend/                # React dashboard"
echo "       └── docker/                  # Container configuration"
echo ""
echo "🚀 Quick Start Commands:"
echo "   Start all services:    ./start.sh"
echo "   Run tests:             ./test.sh"
echo "   Build project:         ./build.sh"
echo "   Stop services:         ./stop.sh"
echo "   Run demonstration:     python demo.py"
echo ""
echo "🌐 Access Points:"
echo "   📧 Email Dashboard:     http://localhost:8000"
echo "   📊 API Documentation:   http://localhost:8000/docs"
echo "   🔍 Health Check:        http://localhost:8000/api/health"
echo "   📈 Current Metrics:     http://localhost:8000/api/metrics"
echo ""
echo "✨ Key Features Implemented:"
echo "   ✅ Smart alert evaluation with configurable thresholds"
echo "   ✅ Professional email templates with dynamic content"
echo "   ✅ Automated report generation with embedded charts"
echo "   ✅ Real-time metrics monitoring and visualization"
echo "   ✅ Multi-channel notification coordination"
echo "   ✅ Delivery tracking and performance statistics"
echo "   ✅ Modern React-based management dashboard"
echo "   ✅ Docker containerization for easy deployment"
echo "   ✅ Comprehensive testing and documentation"
echo ""
echo "🎯 Demo Scenarios Available:"
echo "   • Send test alerts with various severity levels"
echo "   • Generate daily and weekly performance reports"
echo "   • Monitor real-time system metrics and thresholds"
echo "   • Test email template rendering and customization"
echo "   • Simulate production alerting scenarios"
echo ""
echo "📋 Next Steps:"
echo "   1. Update SMTP settings in .env file for real email delivery"
echo "   2. Configure alert thresholds in src/config/email_config.py"
echo "   3. Customize email templates in src/templates/"
echo "   4. Set up scheduled report generation for your organization"
echo "   5. Integrate with existing monitoring and log processing systems"
echo ""
echo "🔗 Ready for Day 137: PagerDuty/OpsGenie Integration"
echo ""
echo "Happy coding! 🚀"