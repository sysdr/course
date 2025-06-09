class ClusterDashboard {
    constructor() {
        this.nodes = [
            { id: 'storage_node_1', port: 5001, type: 'primary' },
            { id: 'storage_node_2', port: 5002, type: 'replica' },
            { id: 'storage_node_3', port: 5003, type: 'replica' }
        ];
        this.refreshInterval = 5000; // 5 seconds
        this.init();
    }
    
    init() {
        this.renderNodes();
        this.startAutoRefresh();
        this.refreshData();
    }
    
    renderNodes() {
        const nodesGrid = document.getElementById('nodesGrid');
        nodesGrid.innerHTML = '';
        
        this.nodes.forEach(node => {
            const nodeCard = document.createElement('div');
            nodeCard.className = `node-card ${node.type}`;
            nodeCard.innerHTML = `
                <div class="node-header">
                    <div class="node-title">
                        ${node.id}
                        ${node.type === 'primary' ? '👑' : '🔄'}
                    </div>
                    <div class="node-status status-healthy" id="status-${node.id}">
                        Checking...
                    </div>
                </div>
                <div class="node-stats">
                    <div class="stat-item">
                        <div class="stat-value" id="writes-${node.id}">-</div>
                        <div class="stat-label">Writes</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="reads-${node.id}">-</div>
                        <div class="stat-label">Reads</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="replications-${node.id}">-</div>
                        <div class="stat-label">Replications</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="uptime-${node.id}">-</div>
                        <div class="stat-label">Uptime</div>
                    </div>
                </div>
            `;
            nodesGrid.appendChild(nodeCard);
        });
    }
    
    async refreshData() {
        const indicator = document.getElementById('refreshIndicator');
        indicator.classList.remove('hidden');
        
        let healthyCount = 0;
        let totalWrites = 0;
        
        for (const node of this.nodes) {
            try {
                const response = await fetch(`http://localhost:${node.port}/health`);
                if (response.ok) {
                    const data = await response.json();
                    this.updateNodeStatus(node.id, true, data);
                    healthyCount++;
                    
                    // Get detailed stats
                    const statsResponse = await fetch(`http://localhost:${node.port}/stats`);
                    if (statsResponse.ok) {
                        const statsData = await statsResponse.json();
                        this.updateNodeStats(node.id, statsData.stats);
                        totalWrites += statsData.stats.writes || 0;
                    }
                } else {
                    this.updateNodeStatus(node.id, false);
                }
            } catch (error) {
                this.updateNodeStatus(node.id, false);
                console.error(`Error checking node ${node.id}:`, error);
            }
        }
        
        // Update overview
        document.getElementById('healthyNodes').textContent = healthyCount;
        document.getElementById('totalWrites').textContent = totalWrites;
        
        indicator.classList.add('hidden');
        this.addActivityLog(`Cluster status updated - ${healthyCount}/${this.nodes.length} nodes healthy`);
    }
    
    updateNodeStatus(nodeId, isHealthy, data = null) {
        const statusElement = document.getElementById(`status-${nodeId}`);
        if (isHealthy) {
            statusElement.textContent = 'Healthy';
            statusElement.className = 'node-status status-healthy';
        } else {
            statusElement.textContent = 'Unhealthy';
            statusElement.className = 'node-status status-unhealthy';
        }
    }
    
    updateNodeStats(nodeId, stats) {
        document.getElementById(`writes-${nodeId}`).textContent = stats.writes || 0;
        document.getElementById(`reads-${nodeId}`).textContent = stats.reads || 0;
        document.getElementById(`replications-${nodeId}`).textContent = stats.replications_received || 0;
        
        if (stats.start_time) {
            const startTime = new Date(stats.start_time);
            const uptime = Math.floor((Date.now() - startTime.getTime()) / 1000);
            document.getElementById(`uptime-${nodeId}`).textContent = this.formatUptime(uptime);
        }
    }
    
    formatUptime(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        
        if (hours > 0) {
            return `${hours}h ${minutes}m`;
        } else if (minutes > 0) {
            return `${minutes}m ${secs}s`;
        } else {
            return `${secs}s`;
        }
    }
    
    addActivityLog(message) {
        const logsContainer = document.getElementById('activityLogs');
        const timestamp = new Date().toLocaleTimeString();
        const logEntry = document.createElement('div');
        logEntry.className = 'log-entry';
        logEntry.textContent = `[${timestamp}] ${message}`;
        
        logsContainer.insertBefore(logEntry, logsContainer.firstChild);
        
        // Keep only last 10 logs
        const logs = logsContainer.children;
        if (logs.length > 10) {
            logsContainer.removeChild(logs[logs.length - 1]);
        }
    }
    
    async testWrite() {
        const testData = {
            message: `Test log entry from dashboard`,
            level: 'info',
            timestamp: new Date().toISOString(),
            source: 'dashboard'
        };
        
        try {
            const response = await fetch(`http://localhost:${this.nodes[0].port}/write`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(testData)
            });
            
            if (response.ok) {
                const result = await response.json();
                this.addActivityLog(`✅ Test write successful: ${result.file_path}`);
                setTimeout(() => this.refreshData(), 1000);
            } else {
                this.addActivityLog(`❌ Test write failed: HTTP ${response.status}`);
            }
        } catch (error) {
            this.addActivityLog(`❌ Test write error: ${error.message}`);
        }
    }
    
    async simulateLoad() {
        this.addActivityLog('🔄 Starting load simulation...');
        
        const promises = [];
        for (let i = 0; i < 10; i++) {
            const testData = {
                message: `Load test message ${i + 1}`,
                level: ['info', 'warn', 'error'][Math.floor(Math.random() * 3)],
                timestamp: new Date().toISOString(),
                source: 'load_test'
            };
            
            const promise = fetch(`http://localhost:${this.nodes[0].port}/write`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(testData)
            });
            
            promises.push(promise);
        }
        
        try {
            const results = await Promise.all(promises);
            const successful = results.filter(r => r.ok).length;
            this.addActivityLog(`✅ Load simulation complete: ${successful}/10 writes successful`);
            setTimeout(() => this.refreshData(), 2000);
        } catch (error) {
            this.addActivityLog(`❌ Load simulation error: ${error.message}`);
        }
    }
    
    startAutoRefresh() {
        setInterval(() => {
            this.refreshData();
        }, this.refreshInterval);
    }
}

// Global functions for buttons
function refreshData() {
    dashboard.refreshData();
}

function testWrite() {
    dashboard.testWrite();
}

function simulateLoad() {
    dashboard.simulateLoad();
}

// Initialize dashboard when page loads
let dashboard;
document.addEventListener('DOMContentLoaded', () => {
    dashboard = new ClusterDashboard();
});
