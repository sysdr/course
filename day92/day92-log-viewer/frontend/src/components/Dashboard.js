import React, { useState, useEffect } from 'react';
import { logService } from '../services/api';
import { Link } from 'react-router-dom';

const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      setLoading(true);
      const data = await logService.getStats();
      setStats(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const initSampleData = async () => {
    try {
      await logService.initSampleData();
      loadStats(); // Reload stats after initialization
    } catch (err) {
      setError(err.message);
    }
  };

  if (loading) return <div className="loading">Loading dashboard...</div>;
  if (error) return <div className="error">Error: {error}</div>;

  return (
    <div className="dashboard">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h2>Log Processing Dashboard</h2>
        <button onClick={initSampleData} className="search-btn">
          Load Sample Data
        </button>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-value">{stats?.total_logs || 0}</div>
          <div className="stat-label">Total Log Entries</div>
        </div>

        {stats?.level_stats && Object.entries(stats.level_stats).map(([level, count]) => (
          <div key={level} className="stat-card">
            <div className="stat-value">{count}</div>
            <div className="stat-label">{level} Level Logs</div>
          </div>
        ))}
      </div>

      <div style={{ background: 'white', padding: '1.5rem', borderRadius: '8px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
        <h3 style={{ marginBottom: '1rem' }}>Services</h3>
        {stats?.service_stats && Object.keys(stats.service_stats).length > 0 ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem' }}>
            {Object.entries(stats.service_stats).map(([service, count]) => (
              <div key={service} style={{ padding: '1rem', background: '#f8f9fa', borderRadius: '4px' }}>
                <div style={{ fontWeight: 'bold', color: '#333' }}>{service}</div>
                <div style={{ color: '#666', fontSize: '0.9rem' }}>{count} log entries</div>
              </div>
            ))}
          </div>
        ) : (
          <p style={{ color: '#666', textAlign: 'center', padding: '2rem' }}>
            No log data available. 
            <Link to="/logs" style={{ color: '#667eea', textDecoration: 'none', marginLeft: '0.5rem' }}>
              View Logs →
            </Link>
          </p>
        )}
      </div>
    </div>
  );
};

export default Dashboard;
