import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, BarChart, Bar } from 'recharts';
import './App.css';

function App() {
  const [metrics, setMetrics] = useState(null);
  const [quotaInfo, setQuotaInfo] = useState(null);
  const [rateLimitInfo, setRateLimitInfo] = useState(null);
  const [testUserId, setTestUserId] = useState('test-user-1');
  const [loading, setLoading] = useState(false);
  const [testResults, setTestResults] = useState([]);

  // Fetch metrics
  const fetchMetrics = async () => {
    try {
      const response = await fetch('http://localhost:8000/metrics');
      const data = await response.json();
      
      // Metrics endpoint returns data directly, not wrapped in data field
      setMetrics(data);
    } catch (error) {
      console.error('Error fetching metrics:', error);
    }
  };

  // Test GraphQL query function
  const testQuery = async () => {
    setLoading(true);
    try {
      const query = `
        query SearchLogs($query: String!, $limit: Int!) {
          search_logs(query: $query, limit: $limit) {
            timestamp
            level
            service
            message
          }
          get_quota_info(user_id: "${testUserId}") {
            current_usage
            limit
            reset_time
            burst_available
          }
          get_rate_limit_info(user_id: "${testUserId}") {
            requests_remaining
            reset_time
            retry_after
          }
        }
      `;

      const response = await fetch('http://localhost:8000/graphql', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-User-ID': testUserId,
        },
        body: JSON.stringify({
          query,
          variables: {
            query: 'test query',
            limit: 10
          }
        })
      });

      const result = await response.json();
      
      if (result.data) {
        setQuotaInfo(result.data.get_quota_info);
        setRateLimitInfo(result.data.get_rate_limit_info);
        setTestResults(prev => [...prev, {
          timestamp: new Date().toLocaleTimeString(),
          success: true,
          data: result.data
        }]);
      } else if (result.errors) {
        setTestResults(prev => [...prev, {
          timestamp: new Date().toLocaleTimeString(),
          success: false,
          error: result.errors[0].message
        }]);
      }
    } catch (error) {
      console.error('Error testing query:', error);
      setTestResults(prev => [...prev, {
        timestamp: new Date().toLocaleTimeString(),
        success: false,
        error: error.message
      }]);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchMetrics();
    const interval = setInterval(fetchMetrics, 5000);
    return () => clearInterval(interval);
  }, []);

  const formatTime = (timestamp) => {
    return new Date(timestamp * 1000).toLocaleTimeString();
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>🚦 Rate Limiting & Quota Management Dashboard</h1>
        <p>Day 87: Monitor traffic control and resource allocation</p>
      </header>

      <div className="dashboard">
        {/* System Overview */}
        <div className="card">
          <h2>System Overview</h2>
          {metrics ? (
            <div className="metrics-grid">
              <div className="metric">
                <h3>{metrics.system.total_requests.toLocaleString()}</h3>
                <p>Total Requests</p>
              </div>
              <div className="metric">
                <h3>{metrics.system.requests_per_second.toFixed(2)}</h3>
                <p>Requests/Second</p>
              </div>
              <div className="metric">
                <h3>{(metrics.system.error_rate * 100).toFixed(2)}%</h3>
                <p>Error Rate</p>
              </div>
              <div className="metric">
                <h3>{metrics.system.avg_response_time_ms.toFixed(0)}ms</h3>
                <p>Avg Response Time</p>
              </div>
            </div>
          ) : (
            <p>Loading metrics...</p>
          )}
        </div>

        {/* Rate Limiting Status */}
        <div className="card">
          <h2>Rate Limiting Status</h2>
          {metrics && (
            <div>
              <p><strong>Total Violations:</strong> {metrics.rate_limiting.total_violations}</p>
              <div className="violations-chart">
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart data={Object.entries(metrics.rate_limiting.violations_by_user).map(([user, count]) => ({
                    user: user.substring(0, 10) + '...',
                    violations: count
                  }))}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="user" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="violations" fill="#ff6b6b" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </div>

        {/* Quota Management */}
        <div className="card">
          <h2>Quota Management</h2>
          {metrics && (
            <div>
              <p><strong>Total Quota Violations:</strong> {metrics.quotas.total_violations}</p>
              <p><strong>Active Users:</strong> {metrics.users.active_users}</p>
              
              <div className="user-requests-chart">
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart data={Object.entries(metrics.users.requests_by_user).slice(0, 10).map(([user, count]) => ({
                    user: user.substring(0, 10) + '...',
                    requests: count
                  }))}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="user" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="requests" fill="#4ecdc4" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </div>

        {/* Test Interface */}
        <div className="card">
          <h2>Rate Limit Test Interface</h2>
          <div className="test-controls">
            <input
              type="text"
              placeholder="User ID"
              value={testUserId}
              onChange={(e) => setTestUserId(e.target.value)}
            />
            <button onClick={testQuery} disabled={loading}>
              {loading ? 'Testing...' : 'Test GraphQL Query'}
            </button>
          </div>

          {rateLimitInfo && (
            <div className="limit-info">
              <h3>Rate Limit Status</h3>
              <p><strong>Requests Remaining:</strong> {rateLimitInfo.requests_remaining}</p>
              <p><strong>Reset Time:</strong> {formatTime(rateLimitInfo.reset_time)}</p>
              {rateLimitInfo.retry_after > 0 && (
                <p className="warning"><strong>Retry After:</strong> {rateLimitInfo.retry_after} seconds</p>
              )}
            </div>
          )}

          {quotaInfo && (
            <div className="quota-info">
              <h3>Quota Status</h3>
              <p><strong>Current Usage:</strong> {quotaInfo.current_usage}</p>
              <p><strong>Limit:</strong> {quotaInfo.limit === -1 ? 'Unlimited' : quotaInfo.limit}</p>
              <p><strong>Reset Time:</strong> {formatTime(quotaInfo.reset_time)}</p>
              <p><strong>Burst Available:</strong> {quotaInfo.burst_available}</p>
              
              <div className="quota-bar">
                <div 
                  className="quota-usage" 
                  style={{
                    width: quotaInfo.limit === -1 ? '0%' : `${(quotaInfo.current_usage / quotaInfo.limit) * 100}%`
                  }}
                ></div>
              </div>
            </div>
          )}

          {/* Test Results */}
          {testResults.length > 0 && (
            <div className="test-results">
              <h3>Test Results</h3>
              <div className="results-list">
                {testResults.slice(-5).reverse().map((result, index) => (
                  <div key={index} className={`result-item ${result.success ? 'success' : 'error'}`}>
                    <span className="timestamp">{result.timestamp}</span>
                    <span className="status">{result.success ? '✅ Success' : '❌ Error'}</span>
                    {result.error && <span className="error-message">{result.error}</span>}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default App;
