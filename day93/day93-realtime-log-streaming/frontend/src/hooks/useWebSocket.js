import { useState, useCallback, useRef, useEffect } from 'react';

export const useWebSocket = () => {
  const [logs, setLogs] = useState([]);
  const [connectionStatus, setConnectionStatus] = useState('disconnected');
  const wsRef = useRef(null);
  const reconnectTimeoutRef = useRef(null);
  const currentStreamRef = useRef(null);
  const reconnectAttempts = useRef(0);
  const maxReconnectAttempts = 5;

  const isConnected = connectionStatus === 'connected';

  const clearLogs = useCallback(() => {
    setLogs([]);
  }, []);

  const connect = useCallback((streamId) => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      disconnect();
    }

    setConnectionStatus('connecting');
    currentStreamRef.current = streamId;

    const wsUrl = `ws://localhost:8000/ws/logs/${streamId}`;
    const ws = new WebSocket(wsUrl);

    ws.onopen = () => {
      console.log('WebSocket connected to stream:', streamId);
      setConnectionStatus('connected');
      reconnectAttempts.current = 0;
    };

    ws.onmessage = (event) => {
      try {
        const logEntry = JSON.parse(event.data);
        setLogs(prevLogs => {
          const newLogs = [...prevLogs, logEntry];
          // Keep only last 1000 logs to prevent memory issues
          return newLogs.length > 1000 ? newLogs.slice(-1000) : newLogs;
        });
      } catch (error) {
        console.error('Failed to parse log entry:', error);
      }
    };

    ws.onclose = (event) => {
      console.log('WebSocket connection closed:', event.code, event.reason);
      
      if (connectionStatus !== 'disconnecting') {
        setConnectionStatus('error');
        
        // Attempt reconnection with exponential backoff
        if (reconnectAttempts.current < maxReconnectAttempts) {
          const delay = Math.pow(2, reconnectAttempts.current) * 1000;
          console.log(`Attempting reconnection in ${delay}ms...`);
          
          reconnectTimeoutRef.current = setTimeout(() => {
            reconnectAttempts.current += 1;
            connect(currentStreamRef.current);
          }, delay);
        } else {
          console.log('Max reconnection attempts reached');
          setConnectionStatus('disconnected');
        }
      } else {
        setConnectionStatus('disconnected');
      }
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
      setConnectionStatus('error');
    };

    wsRef.current = ws;
  }, [connectionStatus]);

  const disconnect = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
      reconnectTimeoutRef.current = null;
    }

    if (wsRef.current) {
      setConnectionStatus('disconnecting');
      wsRef.current.close(1000, 'User disconnected');
      wsRef.current = null;
    }

    reconnectAttempts.current = 0;
    currentStreamRef.current = null;
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      disconnect();
    };
  }, [disconnect]);

  return {
    logs,
    connectionStatus,
    connect,
    disconnect,
    clearLogs,
    isConnected
  };
};
