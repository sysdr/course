const socket = io();
let charts = {};

// Initialize charts
function initCharts() {
    // Error rate chart
    charts.errorChart = Plotly.newPlot('error-chart', [{
        x: [],
        y: [],
        type: 'scatter',
        mode: 'lines+markers',
        line: { color: '#e74c3c', width: 3 },
        marker: { size: 6 }
    }], {
        margin: { t: 20, r: 20, b: 40, l: 50 },
        xaxis: { title: 'Time' },
        yaxis: { title: 'Error Rate (%)' }
    });
    
    // Response time chart
    charts.responseChart = Plotly.newPlot('response-chart', [{
        x: [],
        y: [],
        type: 'scatter',
        mode: 'lines+markers',
        line: { color: '#3498db', width: 3 },
        marker: { size: 6 }
    }], {
        margin: { t: 20, r: 20, b: 40, l: 50 },
        xaxis: { title: 'Time' },
        yaxis: { title: 'Response Time (ms)' }
    });
    
    // Volume chart
    charts.volumeChart = Plotly.newPlot('volume-chart', [{
        x: [],
        y: [],
        type: 'bar',
        marker: { color: '#27ae60' }
    }], {
        margin: { t: 20, r: 20, b: 40, l: 50 },
        xaxis: { title: 'Time' },
        yaxis: { title: 'Event Count' }
    });
}

// Update metric cards
function updateMetrics(metrics) {
    document.getElementById('event-rate').textContent = 
        (metrics['log-events_count_rate'] || 0).toFixed(1);
    
    document.getElementById('error-rate').textContent = 
        (metrics.error_rate_percentage || 0).toFixed(1) + '%';
    
    document.getElementById('response-time').textContent = 
        (metrics.avg_response_time || 0).toFixed(0) + 'ms';
    
    // Update top errors
    const topErrorsDiv = document.getElementById('top-errors');
    if (metrics.top_errors && Object.keys(metrics.top_errors).length > 0) {
        topErrorsDiv.innerHTML = Object.entries(metrics.top_errors)
            .map(([error, count]) => 
                `<div class="error-item">
                    <span>${error}</span>
                    <span>${count}</span>
                </div>`
            ).join('');
    } else {
        topErrorsDiv.innerHTML = 'No errors detected';
    }
}

// Update charts
function updateCharts(historical) {
    if (!historical.timestamps) return;
    
    // Update error rate chart
    Plotly.react('error-chart', [{
        x: historical.timestamps,
        y: historical.error_rates,
        type: 'scatter',
        mode: 'lines+markers',
        line: { color: '#e74c3c', width: 3 },
        marker: { size: 6 }
    }], {
        margin: { t: 20, r: 20, b: 40, l: 50 },
        xaxis: { title: 'Time' },
        yaxis: { title: 'Error Rate (%)' }
    });
    
    // Update response time chart
    Plotly.react('response-chart', [{
        x: historical.timestamps,
        y: historical.response_times,
        type: 'scatter',
        mode: 'lines+markers',
        line: { color: '#3498db', width: 3 },
        marker: { size: 6 }
    }], {
        margin: { t: 20, r: 20, b: 40, l: 50 },
        xaxis: { title: 'Time' },
        yaxis: { title: 'Response Time (ms)' }
    });
    
    // Update volume chart
    Plotly.react('volume-chart', [{
        x: historical.timestamps,
        y: historical.event_counts,
        type: 'bar',
        marker: { color: '#27ae60' }
    }], {
        margin: { t: 20, r: 20, b: 40, l: 50 },
        xaxis: { title: 'Time' },
        yaxis: { title: 'Event Count' }
    });
}

// Socket event handlers
socket.on('connect', function() {
    document.getElementById('status').textContent = '● Connected';
    document.getElementById('status').style.color = '#27ae60';
});

socket.on('disconnect', function() {
    document.getElementById('status').textContent = '● Disconnected';
    document.getElementById('status').style.color = '#e74c3c';
});

socket.on('metrics_update', function(data) {
    updateMetrics(data.metrics);
    updateCharts(data.historical);
});

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
    initCharts();
    
    // Fetch initial data
    fetch('/api/metrics')
        .then(response => response.json())
        .then(data => updateMetrics(data));
    
    fetch('/api/historical')
        .then(response => response.json())
        .then(data => updateCharts(data));
});
