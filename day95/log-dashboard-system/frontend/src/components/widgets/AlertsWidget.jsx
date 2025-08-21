import React, { useEffect, useState } from 'react'
import { useDashboard } from '../../hooks/useDashboard'

const AlertsWidget = ({ widget }) => {
  const { liveData } = useDashboard()
  const [alerts, setAlerts] = useState([])

  useEffect(() => {
    if (liveData.metrics) {
      const newAlerts = []
      
      if (liveData.metrics.error_rate > 0.05) {
        newAlerts.push({
          id: 'error-rate',
          level: 'warning',
          message: `High error rate: ${(liveData.metrics.error_rate * 100).toFixed(1)}%`,
          timestamp: new Date()
        })
      }
      
      if (liveData.metrics.cpu_usage > 0.8) {
        newAlerts.push({
          id: 'cpu-usage',
          level: 'critical',
          message: `High CPU usage: ${(liveData.metrics.cpu_usage * 100).toFixed(0)}%`,
          timestamp: new Date()
        })
      }
      
      if (liveData.metrics.avg_response_time > 150) {
        newAlerts.push({
          id: 'response-time',
          level: 'warning',
          message: `Slow response time: ${Math.round(liveData.metrics.avg_response_time)}ms`,
          timestamp: new Date()
        })
      }
      
      setAlerts(newAlerts)
    }
  }, [liveData])

  const getAlertColor = (level) => {
    switch (level) {
      case 'critical': return '#ff4444'
      case 'warning': return '#ff8800'
      case 'info': return '#0088ff'
      default: return '#888888'
    }
  }

  return (
    <div className="alerts-widget">
      {alerts.length === 0 ? (
        <div className="no-alerts">
          <span className="status-icon">✅</span>
          <span>All systems operational</span>
        </div>
      ) : (
        <div className="alert-list">
          {alerts.map(alert => (
            <div 
              key={alert.id} 
              className="alert-item"
              style={{ borderLeft: `4px solid ${getAlertColor(alert.level)}` }}
            >
              <div className="alert-content">
                <span className="alert-level" style={{ color: getAlertColor(alert.level) }}>
                  {alert.level.toUpperCase()}
                </span>
                <span className="alert-message">{alert.message}</span>
              </div>
              <div className="alert-time">
                {alert.timestamp.toLocaleTimeString()}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default AlertsWidget
