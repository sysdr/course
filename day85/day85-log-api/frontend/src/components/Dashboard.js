import React, { useState, useEffect } from 'react';
import axios from 'axios';

const API_BASE = process.env.REACT_APP_API_URL || 'http://localhost:8000';

function Dashboard({ user, onLogout }) {
  const [stats, setStats] = useState(null);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({
    level: '',
    service: '',
    timeRange: '24h'
  });
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    fetchStats();
    fetchLogs();
  }, [filters]);

  const fetchStats = async () => {
    try {
      const response = await axios.get(`${API_BASE}/api/v1/logs/stats?time_range=${filters.timeRange}`);
      setStats(response.data.data);
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  };

  const fetchLogs = async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams({
        page: '1',
        size: '50'
      });
      
      if (filters.level) params.append('level', filters.level);
      if (filters.service) params.append('service', filters.service);
      
      const response = await axios.get(`${API_BASE}/api/v1/logs?${params}`);
      setLogs(response.data.data);
    } catch (error) {
      console.error('Error fetching logs:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (e) => {
    e.preventDefault();
    if (!searchQuery.trim()) return;

    try {
      setLoading(true);
      const response = await axios.post(`${API_BASE}/api/v1/logs/search`, {
        query: searchQuery,
        page: 1,
        size: 50,
        filters: {
          level: filters.level || undefined,
          service: filters.service || undefined
        }
      });
      setLogs(response.data.data);
    } catch (error) {
      console.error('Error searching logs:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatTimestamp = (timestamp) => {
    return new Date(timestamp).toLocaleString();
  };

  const getLogLevelColor = (level) => {
    const colors = {
      ERROR: '#ff6b6b',
      WARNING: '#feca57',
      INFO: '#48cae4',
      DEBUG: '#a8dadc',
      CRITICAL: '#ff3838'
    };
    return colors[level] || '#ffffff';
  };

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <h1 className="dashboard-title">Log Platform Dashboard</h1>
        <div className="user-info">
          <span>Welcome, {user.username} ({user.role})</span>
          <button className="logout-btn" onClick={onLogout}>Logout</button>
        </div>
      </div>

      {stats && (
        <div className="dashboard-grid">
          <div className="card">
            <h3>📊 System Statistics</h3>
            <div className="stats-grid">
              <div className="stat-item">
                <div className="stat-value">{stats.total_logs.toLocaleString()}</div>
                <div className="stat-label">Total Logs</div>
              </div>
              <div className="stat-item">
                <div className="stat-value">{stats.error_rate}%</div>
                <div className="stat-label">Error Rate</div>
              </div>
              <div className="stat-item">
                <div className="stat-value">{Math.round(stats.avg_logs_per_hour)}</div>
                <div className="stat-label">Logs/Hour</div>
              </div>
            </div>
          </div>

          <div className="card">
            <h3>📈 Logs by Level</h3>
            <div className="stats-grid">
              {Object.entries(stats.logs_by_level || {}).map(([level, count]) => (
                <div key={level} className="stat-item" style={{borderTop: `3px solid ${getLogLevelColor(level)}`}}>
                  <div className="stat-value">{count}</div>
                  <div className="stat-label">{level}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="card">
            <h3>🔧 Top Services</h3>
            <div className="stats-grid">
              {Object.entries(stats.logs_by_service || {}).slice(0, 4).map(([service, count]) => (
                <div key={service} className="stat-item">
                  <div className="stat-value">{count}</div>
                  <div className="stat-label">{service}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      <div className="card">
        <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px'}}>
          <h3>🔍 Log Explorer</h3>
          <button className="refresh-btn" onClick={fetchLogs}>Refresh</button>
        </div>

        <form className="search-container" onSubmit={handleSearch}>
          <input
            type="text"
            className="search-input"
            placeholder="Search logs..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
          <button type="submit" className="search-btn">Search</button>
        </form>

        <div className="controls">
          <div className="control-group">
            <label>Level</label>
            <select 
              value={filters.level} 
              onChange={(e) => setFilters({...filters, level: e.target.value})}
            >
              <option value="">All Levels</option>
              <option value="DEBUG">DEBUG</option>
              <option value="INFO">INFO</option>
              <option value="WARNING">WARNING</option>
              <option value="ERROR">ERROR</option>
              <option value="CRITICAL">CRITICAL</option>
            </select>
          </div>

          <div className="control-group">
            <label>Service</label>
            <select 
              value={filters.service} 
              onChange={(e) => setFilters({...filters, service: e.target.value})}
            >
              <option value="">All Services</option>
              <option value="api-gateway">API Gateway</option>
              <option value="user-service">User Service</option>
              <option value="payment-service">Payment Service</option>
              <option value="notification-service">Notification Service</option>
            </select>
          </div>

          <div className="control-group">
            <label>Time Range</label>
            <select 
              value={filters.timeRange} 
              onChange={(e) => setFilters({...filters, timeRange: e.target.value})}
            >
              <option value="1h">Last Hour</option>
              <option value="24h">Last 24 Hours</option>
              <option value="7d">Last 7 Days</option>
              <option value="30d">Last 30 Days</option>
            </select>
          </div>
        </div>

        <div className="logs-container">
          {loading ? (
            <div className="loading">Loading logs...</div>
          ) : logs.length === 0 ? (
            <div className="loading">No logs found matching your criteria.</div>
          ) : (
            logs.map((log, index) => (
              <div key={index} className={`log-entry ${log.level}`}>
                <div className="log-meta">
                  <span>{formatTimestamp(log.timestamp)}</span>
                  <span>{log.service}</span>
                  <span className="log-level" style={{color: getLogLevelColor(log.level)}}>
                    {log.level}
                  </span>
                </div>
                <div className="log-message">{log.message}</div>
                {log.trace_id && (
                  <div style={{fontSize: '0.8rem', opacity: '0.6', marginTop: '5px'}}>
                    Trace ID: {log.trace_id}
                  </div>
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

export default Dashboard;
