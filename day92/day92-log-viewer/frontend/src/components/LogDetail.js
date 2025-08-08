import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { logService } from '../services/api';

const LogDetail = () => {
  const { id } = useParams();
  const [log, setLog] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadLogDetail();
  }, [id]);

  const loadLogDetail = async () => {
    try {
      setLoading(true);
      const data = await logService.getLogDetail(id);
      setLog(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div className="loading">Loading log detail...</div>;
  if (error) return <div className="error">Error: {error}</div>;
  if (!log) return <div className="error">Log entry not found</div>;

  return (
    <div className="log-viewer">
      <div style={{ marginBottom: '1rem' }}>
        <Link to="/logs" style={{ color: '#667eea', textDecoration: 'none' }}>
          ← Back to Log Viewer
        </Link>
      </div>

      <div className="log-list">
        <div className="log-entry" style={{ cursor: 'default' }}>
          <h2 style={{ marginBottom: '1rem', color: '#333' }}>Log Entry Detail</h2>
          
          <div style={{ marginBottom: '1rem' }}>
            <strong>ID:</strong> {log.id}
          </div>
          
          <div style={{ marginBottom: '1rem' }}>
            <strong>Timestamp:</strong> {new Date(log.timestamp).toLocaleString()}
          </div>
          
          <div style={{ marginBottom: '1rem' }}>
            <strong>Level:</strong> 
            <span className={`log-level ${log.level.toLowerCase()}`} style={{ marginLeft: '0.5rem' }}>
              {log.level}
            </span>
          </div>
          
          <div style={{ marginBottom: '1rem' }}>
            <strong>Service:</strong> {log.service}
          </div>
          
          <div style={{ marginBottom: '1rem' }}>
            <strong>Message:</strong>
            <div style={{ 
              background: '#f8f9fa', 
              padding: '1rem', 
              borderRadius: '4px', 
              fontFamily: 'Monaco, Menlo, monospace',
              marginTop: '0.5rem'
            }}>
              {log.message}
            </div>
          </div>
          
          {log.metadata && Object.keys(log.metadata).length > 0 && (
            <div style={{ marginBottom: '1rem' }}>
              <strong>Metadata:</strong>
              <pre style={{ 
                background: '#f8f9fa', 
                padding: '1rem', 
                borderRadius: '4px', 
                overflow: 'auto',
                marginTop: '0.5rem'
              }}>
                {JSON.stringify(log.metadata, null, 2)}
              </pre>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default LogDetail;
