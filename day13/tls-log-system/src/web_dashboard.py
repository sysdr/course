#!/usr/bin/env python3
"""
Web Dashboard for TLS Log System Monitoring
Provides real-time metrics and log viewing
"""

import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, List
from flask import Flask, render_template, jsonify
from flask_cors import CORS
import threading
import glob

app = Flask(__name__)
CORS(app)

class LogDashboard:
    """Dashboard for monitoring TLS log system"""
    
    def __init__(self):
        self.logs_dir = Path('logs')
        self.logs_dir.mkdir(exist_ok=True)
    
    def get_recent_logs(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Get recent log entries"""
        logs = []
        
        try:
            # Find all log files
            log_files = sorted(glob.glob(str(self.logs_dir / "*.jsonl")), reverse=True)
            
            for log_file in log_files[:5]:  # Check last 5 files
                try:
                    with open(log_file, 'r') as f:
                        for line in f:
                            if line.strip():
                                log_entry = json.loads(line.strip())
                                logs.append(log_entry)
                                
                                if len(logs) >= limit:
                                    break
                    
                    if len(logs) >= limit:
                        break
                        
                except Exception as e:
                    print(f"Error reading log file {log_file}: {e}")
                    
        except Exception as e:
            print(f"Error getting recent logs: {e}")
        
        # Sort by timestamp
        logs.sort(key=lambda x: x.get('timestamp', 0), reverse=True)
        return logs[:limit]
    
    def get_log_statistics(self) -> Dict[str, Any]:
        """Calculate log statistics"""
        logs = self.get_recent_logs(1000)  # Analyze last 1000 logs
        
        if not logs:
            return {
                "total_logs": 0,
                "log_levels": {},
                "sources": {},
                "hourly_distribution": {},
                "average_compression": 0
            }
        
        # Calculate statistics
        log_levels = {}
        sources = {}
        hourly_distribution = {}
        compression_ratios = []
        
        for log in logs:
            # Count log levels
            level = log.get('level', 'UNKNOWN')
            log_levels[level] = log_levels.get(level, 0) + 1
            
            # Count sources
            source = log.get('source', 'unknown')
            sources[source] = sources.get(source, 0) + 1
            
            # Hourly distribution
            timestamp = log.get('timestamp', 0)
            if timestamp:
                hour = datetime.fromtimestamp(timestamp).strftime('%H:00')
                hourly_distribution[hour] = hourly_distribution.get(hour, 0) + 1
            
            # Compression ratios
            compression = log.get('compression_ratio')
            if compression is not None:
                compression_ratios.append(compression)
        
        avg_compression = sum(compression_ratios) / len(compression_ratios) if compression_ratios else 0
        
        return {
            "total_logs": len(logs),
            "log_levels": log_levels,
            "sources": sources,
            "hourly_distribution": hourly_distribution,
            "average_compression": avg_compression
        }

dashboard = LogDashboard()

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('dashboard.html')

@app.route('/api/logs')
def api_logs():
    """API endpoint for recent logs"""
    limit = request.args.get('limit', 50, type=int)
    logs = dashboard.get_recent_logs(limit)
    return jsonify(logs)

@app.route('/api/stats')
def api_stats():
    """API endpoint for log statistics"""
    stats = dashboard.get_log_statistics()
    return jsonify(stats)

@app.route('/api/health')
def api_health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "tls-log-dashboard"
    })

def create_dashboard_template():
    """Create HTML template for dashboard"""
    template_dir = Path('templates')
    template_dir.mkdir(exist_ok=True)
    
    html_content = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TLS Log System Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #2c3e50, #3498db);
            color: white;
            padding: 20px;
            text-align: center;
        }
        
        .header h1 {
            margin: 0;
            font-size: 2.5rem;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 20px;
        }
        
        .stat-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            border-left: 4px solid #3498db;
        }
        
        .stat-value {
            font-size: 2rem;
            font-weight: bold;
            color: #2c3e50;
        }
        
        .stat-label {
            color: #7f8c8d;
            margin-top: 5px;
        }
        
        .charts-section {
            padding: 20px;
        }
        
        .chart-container {
            margin-bottom: 30px;
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        .logs-section {
            padding: 20px;
        }
        
        .log-entry {
            background: #f8f9fa;
            border-radius: 5px;
            padding: 15px;
            margin-bottom: 10px;
            border-left: 4px solid #3498db;
        }
        
        .log-level {
            font-weight: bold;
            padding: 2px 8px;
            border-radius: 3px;
            font-size: 0.8rem;
        }
        
        .log-level.INFO { background: #d4edda; color: #155724; }
        .log-level.WARNING { background: #fff3cd; color: #856404; }
        .log-level.ERROR { background: #f8d7da; color: #721c24; }
        .log-level.HEALTHCARE { background: #cce5ff; color: #004085; }
        
        .log-timestamp {
            color: #6c757d;
            font-size: 0.9rem;
        }
        
        .refresh-btn {
            background: #3498db;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1rem;
        }
        
        .refresh-btn:hover {
            background: #2980b9;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 TLS Log System Dashboard</h1>
            <p>Real-time monitoring of secure log transmission</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value" id="total-logs">-</div>
                <div class="stat-label">Total Logs</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="avg-compression">-</div>
                <div class="stat-label">Avg Compression</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="active-sources">-</div>
                <div class="stat-label">Active Sources</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="last-update">-</div>
                <div class="stat-label">Last Update</div>
            </div>
        </div>
        
        <div class="charts-section">
            <div class="chart-container">
                <h3>Log Levels Distribution</h3>
                <canvas id="logLevelsChart" width="400" height="200"></canvas>
            </div>
            
            <div class="chart-container">
                <h3>Hourly Activity</h3>
                <canvas id="hourlyChart" width="400" height="200"></canvas>
            </div>
        </div>
        
        <div class="logs-section">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                <h3>Recent Logs</h3>
                <button class="refresh-btn" onclick="refreshData()">Refresh</button>
            </div>
            <div id="recent-logs"></div>
        </div>
    </div>

    <script>
        let logLevelsChart, hourlyChart;
        
        function initCharts() {
            // Log Levels Chart
            const ctx1 = document.getElementById('logLevelsChart').getContext('2d');
            logLevelsChart = new Chart(ctx1, {
                type: 'doughnut',
                data: {
                    labels: [],
                    datasets: [{
                        data: [],
                        backgroundColor: [
                            '#28a745', '#ffc107', '#dc3545', '#17a2b8', '#6f42c1'
                        ]
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false
                }
            });
            
            // Hourly Chart
            const ctx2 = document.getElementById('hourlyChart').getContext('2d');
            hourlyChart = new Chart(ctx2, {
                type: 'bar',
                data: {
                    labels: [],
                    datasets: [{
                        label: 'Logs per Hour',
                        data: [],
                        backgroundColor: '#3498db'
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: {
                            beginAtZero: true
                        }
                    }
                }
            });
        }
        
        async function fetchStats() {
            try {
                const response = await fetch('/api/stats');
                return await response.json();
            } catch (error) {
                console.error('Error fetching stats:', error);
                return null;
            }
        }
        
        async function fetchLogs() {
            try {
                const response = await fetch('/api/logs?limit=20');
                return await response.json();
            } catch (error) {
                console.error('Error fetching logs:', error);
                return [];
            }
        }
        
        function updateStats(stats) {
            document.getElementById('total-logs').textContent = stats.total_logs.toLocaleString();
            document.getElementById('avg-compression').textContent = (stats.average_compression * 100).toFixed(1) + '%';
            document.getElementById('active-sources').textContent = Object.keys(stats.sources).length;
            document.getElementById('last-update').textContent = new Date().toLocaleTimeString();
            
            // Update charts
            logLevelsChart.data.labels = Object.keys(stats.log_levels);
            logLevelsChart.data.datasets[0].data = Object.values(stats.log_levels);
            logLevelsChart.update();
            
            const hours = Array.from({length: 24}, (_, i) => String(i).padStart(2, '0') + ':00');
            const hourlyData = hours.map(hour => stats.hourly_distribution[hour] || 0);
            
            hourlyChart.data.labels = hours;
            hourlyChart.data.datasets[0].data = hourlyData;
            hourlyChart.update();
        }
        
        function updateLogs(logs) {
            const container = document.getElementById('recent-logs');
            container.innerHTML = '';
            
            logs.forEach(log => {
                const logDiv = document.createElement('div');
                logDiv.className = 'log-entry';
                
                const timestamp = new Date(log.timestamp * 1000).toLocaleString();
                const level = log.level || 'INFO';
                
                logDiv.innerHTML = `
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                        <span class="log-level ${level}">${level}</span>
                        <span class="log-timestamp">${timestamp}</span>
                    </div>
                    <div><strong>Source:</strong> ${log.source}</div>
                    <div><strong>Message:</strong> ${log.message}</div>
                    ${log.client_ip ? `<div><strong>Client:</strong> ${log.client_ip}</div>` : ''}
                `;
                
                container.appendChild(logDiv);
            });
        }
        
        async function refreshData() {
            const stats = await fetchStats();
            const logs = await fetchLogs();
            
            if (stats) updateStats(stats);
            updateLogs(logs);
        }
        
        // Initialize
        window.onload = function() {
            initCharts();
            refreshData();
            
            // Auto-refresh every 30 seconds
            setInterval(refreshData, 30000);
        };
    </script>
</body>
</html>
'''
    
    with open(template_dir / 'dashboard.html', 'w') as f:
        f.write(html_content)

if __name__ == "__main__":
    import os
    from flask import request
    
    create_dashboard_template()
    
    port = int(os.getenv('DASHBOARD_PORT', '8080'))
    app.run(host='0.0.0.0', port=port, debug=False)
