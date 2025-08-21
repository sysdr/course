import React from 'react'
import { useDashboard } from '../../hooks/useDashboard'

const StatusWidget = ({ widget }) => {
  const { liveData } = useDashboard()

  const services = [
    { name: 'Web API', status: 'healthy' },
    { name: 'Auth Service', status: 'healthy' },
    { name: 'Database', status: 'warning' },
    { name: 'Cache', status: 'healthy' }
  ]

  const getStatusColor = (status) => {
    switch (status) {
      case 'healthy': return '#00aa00'
      case 'warning': return '#ff8800'
      case 'error': return '#ff4444'
      default: return '#888888'
    }
  }

  return (
    <div className="status-widget">
      <div className="service-statuses">
        {services.map(service => (
          <div key={service.name} className="service-status">
            <div 
              className="status-indicator"
              style={{ backgroundColor: getStatusColor(service.status) }}
            ></div>
            <span className="service-name">{service.name}</span>
            <span className="status-text">{service.status}</span>
          </div>
        ))}
      </div>
      
      {liveData.metrics && (
        <div className="system-overview">
          <div className="overview-item">
            <span>System Load</span>
            <span>{(liveData.metrics.cpu_usage * 100).toFixed(0)}%</span>
          </div>
          <div className="overview-item">
            <span>Memory Usage</span>
            <span>{(liveData.metrics.memory_usage * 100).toFixed(0)}%</span>
          </div>
        </div>
      )}
    </div>
  )
}

export default StatusWidget
