import React, { useRef, useEffect, useState } from 'react';
import { FixedSizeList as List } from 'react-window';
import { formatDistanceToNow } from 'date-fns';
import './LogStreamer.css';

const LogStreamer = ({ logs, isConnected, selectedStream }) => {
  const listRef = useRef();
  const [autoScroll, setAutoScroll] = useState(true);
  const [isUserScrolling, setIsUserScrolling] = useState(false);

  // Auto-scroll to bottom when new logs arrive
  useEffect(() => {
    if (autoScroll && !isUserScrolling && listRef.current && logs.length > 0) {
      listRef.current.scrollToItem(logs.length - 1, 'end');
    }
  }, [logs.length, autoScroll, isUserScrolling]);

  // Reset auto-scroll when stream changes
  useEffect(() => {
    setAutoScroll(true);
    setIsUserScrolling(false);
  }, [selectedStream]);

  const handleScroll = ({ scrollOffset, scrollUpdateWasRequested }) => {
    if (!scrollUpdateWasRequested) {
      setIsUserScrolling(true);
      
      // Check if user scrolled to bottom
      const listElement = listRef.current;
      if (listElement) {
        const { clientHeight, scrollHeight } = listElement;
        const isAtBottom = scrollHeight - scrollOffset - clientHeight < 50;
        
        if (isAtBottom) {
          setAutoScroll(true);
          setIsUserScrolling(false);
        } else {
          setAutoScroll(false);
        }
      }
    }
  };

  const LogItem = ({ index, style }) => {
    const log = logs[index];
    if (!log) return null;

    const timestamp = new Date(log.timestamp);
    const levelClass = `log-level log-level-${log.level.toLowerCase()}`;
    const relativeTime = formatDistanceToNow(timestamp, { addSuffix: true });

    return (
      <div style={style} className={`log-entry ${levelClass}`}>
        <div className="log-header">
          <span className="log-timestamp" title={timestamp.toLocaleString()}>
            {relativeTime}
          </span>
          <span className={`log-badge ${levelClass}`}>
            {log.level}
          </span>
          <span className="log-source">
            {log.source}
          </span>
          <span className="log-id">
            #{log.id}
          </span>
        </div>
        <div className="log-message">
          {log.message}
        </div>
        {log.metadata && Object.keys(log.metadata).filter(k => log.metadata[k]).length > 0 && (
          <div className="log-metadata">
            {Object.entries(log.metadata)
              .filter(([_, value]) => value)
              .map(([key, value]) => (
                <span key={key} className="metadata-item">
                  {key}: {value}
                </span>
              ))
            }
          </div>
        )}
      </div>
    );
  };

  if (!isConnected && logs.length === 0) {
    return (
      <div className="log-streamer empty-state">
        <div className="empty-message">
          <h3>🔌 Not Connected</h3>
          <p>Click "Connect" to start streaming logs from <strong>{selectedStream}</strong></p>
        </div>
      </div>
    );
  }

  if (logs.length === 0) {
    return (
      <div className="log-streamer empty-state">
        <div className="loading-message">
          <h3>⏳ Waiting for logs...</h3>
          <p>Connected to <strong>{selectedStream}</strong> stream</p>
          <div className="loading-spinner"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="log-streamer">
      <div className="stream-info">
        <h3>📡 Live Stream: {selectedStream}</h3>
        <div className="stream-controls">
          <button
            onClick={() => setAutoScroll(!autoScroll)}
            className={`btn btn-sm ${autoScroll ? 'btn-primary' : 'btn-secondary'}`}
          >
            {autoScroll ? '⏸️ Pause' : '▶️ Resume'} Auto-scroll
          </button>
        </div>
      </div>
      
      <div className="log-container">
        <List
          ref={listRef}
          height={600}
          itemCount={logs.length}
          itemSize={120}
          onScroll={handleScroll}
        >
          {LogItem}
        </List>
      </div>
      
      <div className="stream-stats">
        <span>Total Logs: {logs.length}</span>
        <span>Auto-scroll: {autoScroll ? 'ON' : 'OFF'}</span>
        <span className={isConnected ? 'status-connected' : 'status-disconnected'}>
          {isConnected ? '🟢 Connected' : '🔴 Disconnected'}
        </span>
      </div>
    </div>
  );
};

export default LogStreamer;
