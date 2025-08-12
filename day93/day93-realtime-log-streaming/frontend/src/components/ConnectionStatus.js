import React from 'react';
import './ConnectionStatus.css';

const ConnectionStatus = ({ status, isConnected, onToggle }) => {
  const getStatusIcon = () => {
    switch (status) {
      case 'connecting': return '🔄';
      case 'connected': return '🟢';
      case 'disconnecting': return '⏸️';
      case 'disconnected': return '🔴';
      case 'error': return '❌';
      default: return '⚫';
    }
  };

  const getStatusText = () => {
    return status.charAt(0).toUpperCase() + status.slice(1);
  };

  return (
    <div className="connection-status">
      <div className={`status-indicator status-${status}`}>
        <span className="status-icon">{getStatusIcon()}</span>
        <span className="status-text">{getStatusText()}</span>
      </div>
      <button
        onClick={onToggle}
        disabled={status === 'connecting' || status === 'disconnecting'}
        className={`btn ${isConnected ? 'btn-danger' : 'btn-success'}`}
      >
        {isConnected ? 'Disconnect' : 'Connect'}
      </button>
    </div>
  );
};

export default ConnectionStatus;
