#!/usr/bin/env python3
"""
Monitoring dashboard for UDP Log Server
"""

from flask import Flask, render_template, jsonify
import threading
import time
import os
import json
from collections import defaultdict, deque
from datetime import datetime

app = Flask(__name__)

# Global reference to the UDP server
udp_server = None

# Routes
@app.route('/')
def index():
   """Render the dashboard homepage."""
   return render_template('index.html')

@app.route('/api/stats')
def stats():
   """Return current stats as JSON."""
   if udp_server:
       return jsonify(udp_server.get_stats())
   else:
       return jsonify({
           'log_count': 0,
           'current_rate': 0,
           'level_distribution': {},
           'error_logs': []
       })

def create_templates():
   """Create the HTML templates for the dashboard."""
   template_dir = os.path.join(os.getcwd(), 'templates')
   os.makedirs(template_dir, exist_ok=True)
   
   with open(os.path.join(template_dir, 'index.html'), 'w') as f:
       f.write('''
<!DOCTYPE html>
<html>
<head>
   <title>UDP Log Server Dashboard</title>
   <meta charset="UTF-8">
   <meta name="viewport" content="width=device-width, initial-scale=1.0">
   <style>
       body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
       .container { max-width: 1200px; margin: 0 auto; }
       .panel { background: #f5f5f5; border-radius: 5px; padding: 15px; margin-bottom: 20px; }
       h1, h2 { color: #333; }
       .stats { display: flex; justify-content: space-between; flex-wrap: wrap; }
       .stat-box { flex: 1; min-width: 200px; margin: 10px; padding: 15px; background: white; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
       .error-logs { background: white; border-radius: 5px; padding: 15px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
       .error-log { margin-bottom: 10px; padding: 10px; background: #ffebe6; border-left: 4px solid #ff3e1d; }
       .log-count { font-size: 32px; font-weight: bold; }
       .log-rate { font-size: 24px; color: #0066cc; }
       #level-chart { height: 300px; }
   </style>
   <script src="https://cdn.jsdelivr.net/npm/chart.js@3.7.1/dist/chart.min.js"></script>
</head>
<body>
   <div class="container">
       <h1>UDP Log Server Dashboard</h1>
       
       <div class="stats">
           <div class="stat-box">
               <h2>Log Count</h2>
               <div class="log-count" id="log-count">0</div>
           </div>
           <div class="stat-box">
               <h2>Current Rate</h2>
               <div class="log-rate" id="log-rate">0 logs/sec</div>
           </div>
       </div>
       
       <div class="panel">
           <h2>Log Level Distribution</h2>
           <canvas id="level-chart"></canvas>
       </div>
       
       <div class="panel">
           <h2>Recent ERROR Logs</h2>
           <div class="error-logs" id="error-logs">
               <div class="error-log">No ERROR logs yet</div>
           </div>
       </div>
   </div>
   
   <script>
       // Initialize chart
       const ctx = document.getElementById('level-chart').getContext('2d');
       const levelChart = new Chart(ctx, {
           type: 'bar',
           data: {
               labels: [],
               datasets: [{
                   label: 'Count',
                   data: [],
                   backgroundColor: [
                       'rgba(75, 192, 192, 0.6)',  // INFO
                       'rgba(255, 206, 86, 0.6)',  // WARNING
                       'rgba(255, 99, 132, 0.6)',  // ERROR
                       'rgba(54, 162, 235, 0.6)'   // DEBUG
                   ],
                   borderWidth: 1
               }]
           },
           options: {
               scales: {
                   y: {
                       beginAtZero: true
                   }
               }
           }
       });
       
       // Update data every second
       setInterval(async () => {
           try {
               const response = await fetch('/api/stats');
               const data = await response.json();
               
               // Update log count
               document.getElementById('log-count').textContent = data.log_count;
               
               // Update log rate
               document.getElementById('log-rate').textContent = 
                   `${data.current_rate.toFixed(2)} logs/sec`;
               
               // Update level chart
               const levels = Object.keys(data.level_distribution);
               const counts = levels.map(level => data.level_distribution[level]);
               
               levelChart.data.labels = levels;
               levelChart.data.datasets[0].data = counts;
               levelChart.update();
               
               // Update error logs
               const errorLogsContainer = document.getElementById('error-logs');
               if (data.error_logs && data.error_logs.length > 0) {
                   errorLogsContainer.innerHTML = '';
                   data.error_logs.forEach(log => {
                       const logDiv = document.createElement('div');
                       logDiv.className = 'error-log';
                       logDiv.innerHTML = `
                           <strong>Time:</strong> ${new Date(log.timestamp).toLocaleTimeString()}<br>
                           <strong>App:</strong> ${log.app || 'unknown'}<br>
                           <strong>Host:</strong> ${log.host || 'unknown'}<br>
                           <strong>Message:</strong> ${log.message || 'No message'}
                       `;
                       errorLogsContainer.appendChild(logDiv);
                   });
               }
           } catch (error) {
               console.error("Failed to fetch stats:", error);
           }
       }, 1000);
   </script>
</body>
</html>
   ''')
   print(f"Template created at {os.path.join(template_dir, 'index.html')}")

# Data storage for dashboard
class DashboardData:
   def __init__(self):
       self.log_count = 0
       self.error_logs = []
       self.level_counts = defaultdict(int)
       # Store timestamps of recent logs for rate calculation
       self.recent_timestamps = deque(maxlen=10000)  # Store last 10,000 timestamps
       
   def add_log(self, log_data):
       """Add a log entry to the dashboard data."""
       self.log_count += 1
       
       # Store timestamp for rate calculation
       self.recent_timestamps.append(time.time())
       
       # Update level counts
       level = log_data.get('level', 'UNKNOWN')
       self.level_counts[level] += 1
       
       # Store ERROR logs
       if level == 'ERROR':
           self.error_logs.append(log_data)
           # Keep only the latest 100 ERROR logs
           if len(self.error_logs) > 100:
               self.error_logs.pop(0)
   
   def get_current_rate(self):
       """Calculate the current log reception rate."""
       now = time.time()
       
       # Handle empty case
       if not self.recent_timestamps:
           return 0
           
       # Count logs received in the last RATE_WINDOW seconds
       RATE_WINDOW = 60
       count = sum(1 for ts in self.recent_timestamps if now - ts <= RATE_WINDOW)
       
       # Calculate rate per second
       return count / min(RATE_WINDOW, now - self.recent_timestamps[0])
       
dashboard_data = DashboardData()

def run_dashboard(server, host='0.0.0.0', port=8080):
   """Run the dashboard server."""
   global udp_server
   udp_server = server
   
   # Create the templates
   create_templates()
   
   # Set Flask to not use threading
   app.run(host=host, port=port, threaded=True)

def start_dashboard_thread(server, port=8080):
   """Start the dashboard in a separate thread."""
   dashboard_thread = threading.Thread(target=run_dashboard, args=(server, '0.0.0.0', port))
   dashboard_thread.daemon = True
   dashboard_thread.start()
   print(f"Dashboard started on http://0.0.0.0:{port}")
   return dashboard_thread

if __name__ == "__main__":
   # If running directly, create a mock server for testing
   class MockServer:
       def get_stats(self):
           return {
               'log_count': 12345,
               'current_rate': 123.45,
               'level_distribution': {
                   'INFO': 10000,
                   'WARNING': 2000,
                   'ERROR': 300,
                   'DEBUG': 45
               },
               'error_logs': [
                   {
                       'timestamp': datetime.now().isoformat(),
                       'app': 'test-app',
                       'level': 'ERROR',
                       'message': 'This is a test error message',
                       'host': 'localhost'
                   }
               ]
           }
   
   run_dashboard(MockServer())