import React, { useState, useEffect } from 'react';
import { logService } from '../services/api';

const LogViewer = () => {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [pagination, setPagination] = useState({});
  const [filters, setFilters] = useState({
    level: '',
    service: '',
    search: '',
    page: 1
  });

  useEffect(() => {
    loadLogs();
  }, [filters.page, filters.level, filters.service]);

  const loadLogs = async () => {
    try {
      setLoading(true);
      const data = await logService.getLogs({
        ...filters,
        per_page: 20
      });
      setLogs(data.logs);
      setPagination(data.pagination);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    setFilters(prev => ({ ...prev, page: 1 }));
    loadLogs();
  };

  const handleFilterChange = (field, value) => {
    setFilters(prev => ({ ...prev, [field]: value }));
  };

  const formatTimestamp = (timestamp) => {
    return new Date(timestamp).toLocaleString();
  };

  const changePage = (newPage) => {
    setFilters(prev => ({ ...prev, page: newPage }));
  };

  return (
    <div className="log-viewer">
      <h2>Log Entries</h2>
      
      <div className="search-filters">
        <div className="filter-row">
          <div className="filter-group">
            <label>Level</label>
            <select 
              value={filters.level} 
              onChange={(e) => handleFilterChange('level', e.target.value)}
            >
              <option value="">All Levels</option>
              <option value="INFO">INFO</option>
              <option value="WARN">WARN</option>
              <option value="ERROR">ERROR</option>
              <option value="DEBUG">DEBUG</option>
            </select>
          </div>
          
          <div className="filter-group">
            <label>Service</label>
            <input
              type="text"
              placeholder="Service name"
              value={filters.service}
              onChange={(e) => handleFilterChange('service', e.target.value)}
            />
          </div>
          
          <div className="filter-group">
            <label>Search</label>
            <input
              type="text"
              placeholder="Search messages..."
              value={filters.search}
              onChange={(e) => handleFilterChange('search', e.target.value)}
              onKeyPress={(e) => {
                if (e.key === 'Enter') {
                  handleSearch();
                }
              }}
            />
          </div>
          
          <button className="search-btn" onClick={handleSearch}>
            Search
          </button>
        </div>
      </div>

      {error && <div className="error">Error: {error}</div>}

      <div className="log-list">
        {loading ? (
          <div className="loading">Loading logs...</div>
        ) : logs.length === 0 ? (
          <div className="empty-state">
            No logs found matching your criteria.
          </div>
        ) : (
          logs.map(log => (
            <div key={log.id} className="log-entry">
              <div className="log-header">
                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                  <span className={`log-level ${log.level.toLowerCase()}`}>
                    {log.level}
                  </span>
                  <span className="log-service">{log.service}</span>
                  <span className="log-timestamp">
                    {formatTimestamp(log.timestamp)}
                  </span>
                </div>
              </div>
              <div className="log-message">{log.message}</div>
              {log.metadata && Object.keys(log.metadata).length > 0 && (
                <div style={{ marginTop: '0.5rem', fontSize: '0.8rem', color: '#666' }}>
                  Metadata: {JSON.stringify(log.metadata, null, 2)}
                </div>
              )}
            </div>
          ))
        )}

        {pagination.pages > 1 && (
          <div className="pagination">
            <button 
              onClick={() => changePage(1)} 
              disabled={pagination.page === 1}
            >
              First
            </button>
            <button 
              onClick={() => changePage(pagination.page - 1)} 
              disabled={pagination.page === 1}
            >
              Previous
            </button>
            <span>
              Page {pagination.page} of {pagination.pages}
            </span>
            <button 
              onClick={() => changePage(pagination.page + 1)} 
              disabled={pagination.page === pagination.pages}
            >
              Next
            </button>
            <button 
              onClick={() => changePage(pagination.pages)} 
              disabled={pagination.page === pagination.pages}
            >
              Last
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default LogViewer;
