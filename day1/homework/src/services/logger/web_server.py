"""
Simple web server to display logs and configuration.
"""
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import config


class LoggerWebServer:
    def __init__(self, logger):
        """Initialize the web server with a reference to the logger."""
        self.logger = logger
        self.config = config.get_config()
        
    def start(self):
        """Start the web server."""
        host = self.config["web_host"]
        port = self.config["web_port"]
        
        # Create request handler with reference to logger
        handler = self.create_request_handler()
        
        # Create and start server
        server = HTTPServer((host, port), handler)
        self.logger.info(f"Web server started at http://{host}:{port}")
        
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            self.logger.info("Web server stopping")
            server.shutdown()
    
    def create_request_handler(self):
        """Create a request handler class with access to the logger."""
        logger = self.logger
        
        class LoggerRequestHandler(BaseHTTPRequestHandler):
            def do_GET(self):
                """Handle GET requests."""
                if self.path == "/":
                    self.send_response(200)
                    self.send_header("Content-type", "text/html")
                    self.end_headers()
                    
                    self.wfile.write(self.get_html_content().encode())
                elif self.path == "/api/logs":
                    self.send_response(200)
                    self.send_header("Content-type", "application/json")
                    self.end_headers()
                    
                    logs = logger.get_recent_logs()
                    self.wfile.write(json.dumps(logs).encode())
                elif self.path == "/api/config":
                    self.send_response(200)
                    self.send_header("Content-type", "application/json")
                    self.end_headers()
                    
                    # Filter out sensitive information if needed
                    safe_config = {k: v for k, v in config.get_config().items()}
                    self.wfile.write(json.dumps(safe_config).encode())
                else:
                    self.send_response(404)
                    self.send_header("Content-type", "text/html")
                    self.end_headers()
                    self.wfile.write(b"Not Found")
            
            def log_message(self, format, *args):
                """Override log_message to use our logger."""
                logger.info(f"Web request: {format % args}")
            
            def get_html_content(self):
                """Generate HTML content for the web interface."""
                return """
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Distributed Logger - Web Interface</title>
                    <style>
                        body {
                            font-family: Arial, sans-serif;
                            margin: 0;
                            padding: 20px;
                            background-color: #f5f5f5;
                        }
                        .container {
                            max-width: 1200px;
                            margin: 0 auto;
                        }
                        h1 {
                            color: #333;
                        }
                        .panel {
                            background-color: white;
                            border-radius: 4px;
                            box-shadow: 0 1px 3px rgba(0,0,0,0.12);
                            padding: 15px;
                            margin-bottom: 20px;
                        }
                        .logs-container {
                            height: 400px;
                            overflow: auto;
                        }
                        table {
                            width: 100%;
                            border-collapse: collapse;
                        }
                        th, td {
                            padding: 8px;
                            text-align: left;
                            border-bottom: 1px solid #ddd;
                        }
                        th {
                            background-color: #f2f2f2;
                        }
                        tr:hover {
                            background-color: #f5f5f5;
                        }
                        .config-grid {
                            display: grid;
                            grid-template-columns: 1fr 1fr;
                            gap: 10px;
                        }
                        .config-item {
                            display: flex;
                            justify-content: space-between;
                            padding: 5px 0;
                            border-bottom: 1px solid #eee;
                        }
                        .config-name {
                            font-weight: bold;
                        }
                        .log-level-DEBUG {
                            color: #6c757d;
                        }
                        .log-level-INFO {
                            color: #28a745;
                        }
                        .log-level-WARNING {
                            color: #ffc107;
                        }
                        .log-level-ERROR {
                            color: #dc3545;
                        }
                        .log-level-CRITICAL {
                            color: #dc3545;
                            font-weight: bold;
                        }
                        .refresh-button {
                            background-color: #007bff;
                            color: white;
                            border: none;
                            padding: 8px 16px;
                            border-radius: 4px;
                            cursor: pointer;
                            margin-bottom: 10px;
                        }
                        .refresh-button:hover {
                            background-color: #0069d9;
                        }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1>Distributed Logger - Web Interface</h1>
                        
                        <div class="panel">
                            <h2>Log Messages</h2>
                            <button id="refreshButton" class="refresh-button">Refresh Logs</button>
                            <div class="logs-container">
                                <table id="logsTable">
                                    <thead>
                                        <tr>
                                            <th>Timestamp</th>
                                            <th>Level</th>
                                            <th>Message</th>
                                        </tr>
                                    </thead>
                                    <tbody id="logsTableBody">
                                        <!-- Logs will be populated here -->
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        
                        <div class="panel">
                            <h2>Configuration</h2>
                            <div class="config-grid" id="configContainer">
                                <!-- Config will be populated here -->
                            </div>
                        </div>
                    </div>
                    
                    <script>
                        // Function to fetch and display logs
                        function fetchLogs() {
                            fetch('/api/logs')
                                .then(response => response.json())
                                .then(logs => {
                                    const logsTableBody = document.getElementById('logsTableBody');
                                    logsTableBody.innerHTML = '';
                                    
                                    // Sort logs by timestamp (newest first)
                                    logs.sort((a, b) => {
                                        return new Date(b.timestamp) - new Date(a.timestamp);
                                    });
                                    
                                    logs.forEach(log => {
                                        const row = document.createElement('tr');
                                        
                                        // Timestamp
                                        const timestampCell = document.createElement('td');
                                        timestampCell.textContent = log.timestamp;
                                        row.appendChild(timestampCell);
                                        
                                        // Level
                                        const levelCell = document.createElement('td');
                                        levelCell.textContent = log.level;
                                        levelCell.className = `log-level-${log.level}`;
                                        row.appendChild(levelCell);
                                        
                                        // Message
                                        const messageCell = document.createElement('td');
                                        messageCell.textContent = log.message;
                                        row.appendChild(messageCell);
                                        
                                        logsTableBody.appendChild(row);
                                    });
                                })
                                .catch(error => {
                                    console.error('Error fetching logs:', error);
                                });
                        }
                        
                        // Function to fetch and display configuration
                        function fetchConfig() {
                            fetch('/api/config')
                                .then(response => response.json())
                                .then(config => {
                                    const configContainer = document.getElementById('configContainer');
                                    configContainer.innerHTML = '';
                                    
                                    // Sort config keys alphabetically
                                    const sortedKeys = Object.keys(config).sort();
                                    
                                    sortedKeys.forEach(key => {
                                        const configItem = document.createElement('div');
                                        configItem.className = 'config-item';
                                        
                                        const configName = document.createElement('div');
                                        configName.className = 'config-name';
                                        configName.textContent = key;
                                        configItem.appendChild(configName);
                                        
                                        const configValue = document.createElement('div');
                                        configValue.className = 'config-value';
                                        configValue.textContent = config[key];
                                        configItem.appendChild(configValue);
                                        
                                        configContainer.appendChild(configItem);
                                    });
                                })
                                .catch(error => {
                                    console.error('Error fetching config:', error);
                                });
                        }
                        
                        // Initial fetch
                        fetchLogs();
                        fetchConfig();
                        
                        // Set up refresh button
                        document.getElementById('refreshButton').addEventListener('click', fetchLogs);
                        
                        // Auto-refresh logs every 10 seconds
                        setInterval(fetchLogs, 10000);
                    </script>
                </body>
                </html>
                """
        
        return LoggerRequestHandler