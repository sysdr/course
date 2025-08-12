import React, { useState, useEffect } from 'react';
import LogStreamer from './components/LogStreamer';
import StreamSelector from './components/StreamSelector';
import ConnectionStatus from './components/ConnectionStatus';
import { useWebSocket } from './hooks/useWebSocket';
import './App.css';

function App() {
  const [selectedStream, setSelectedStream] = useState('application');
  const [availableStreams, setAvailableStreams] = useState([]);
  const { 
    logs, 
    connectionStatus, 
    connect, 
    disconnect, 
    clearLogs,
    isConnected 
  } = useWebSocket();

  // Fetch available streams on component mount
  useEffect(() => {
    fetchStreams();
  }, []);

  // Auto-connect to selected stream
  useEffect(() => {
    if (selectedStream) {
      connect(selectedStream);
    }
  }, [selectedStream, connect]);

  const fetchStreams = async () => {
    try {
      const response = await fetch('/api/streams');
      const data = await response.json();
      setAvailableStreams(data.streams || []);
    } catch (error) {
      console.error('Failed to fetch streams:', error);
    }
  };

  const handleStreamChange = (streamId) => {
    disconnect();
    setSelectedStream(streamId);
    clearLogs();
  };

  const handleToggleConnection = () => {
    if (isConnected) {
      disconnect();
    } else {
      connect(selectedStream);
    }
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>🔴 Real-time Log Streaming Dashboard</h1>
        <div className="header-controls">
          <StreamSelector
            streams={availableStreams}
            selectedStream={selectedStream}
            onStreamChange={handleStreamChange}
            disabled={isConnected}
          />
          <ConnectionStatus
            status={connectionStatus}
            isConnected={isConnected}
            onToggle={handleToggleConnection}
          />
        </div>
      </header>

      <main className="app-main">
        <div className="log-controls">
          <button 
            onClick={clearLogs}
            className="btn btn-secondary"
            disabled={!logs.length}
          >
            Clear Logs ({logs.length})
          </button>
        </div>
        
        <LogStreamer
          logs={logs}
          isConnected={isConnected}
          selectedStream={selectedStream}
        />
      </main>

      <footer className="app-footer">
        <p>
          Day 93: Real-time Log Streaming | 
          Stream: <strong>{selectedStream}</strong> | 
          Logs: <strong>{logs.length}</strong>
        </p>
      </footer>
    </div>
  );
}

export default App;
