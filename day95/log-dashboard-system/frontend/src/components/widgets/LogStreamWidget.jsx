import React, { useEffect, useState } from 'react'
import { useDashboard } from '../../hooks/useDashboard'
import { format } from 'date-fns'

const LogStreamWidget = ({ widget }) => {
  const { liveData } = useDashboard()
  const [logs, setLogs] = useState([])

  useEffect(() => {
    if (liveData.logs) {
      // Apply widget filters
      let filteredLogs = liveData.logs
      
      if (widget.filters.level) {
        filteredLogs = filteredLogs.filter(log => log.level === widget.filters.level)
      }
      if (widget.filters.service) {
        filteredLogs = filteredLogs.filter(log => log.service === widget.filters.service)
      }
      
      setLogs(prevLogs => {
        const newLogs = [...filteredLogs, ...prevLogs].slice(0, 50)
        return newLogs
      })
    }
  }, [liveData, widget.filters])

  const getLevelColor = (level) => {
    switch (level) {
      case 'ERROR': return '#ff4444'
      case 'WARNING': return '#ff8800'
      case 'INFO': return '#0088ff'
      case 'DEBUG': return '#888888'
      default: return '#000000'
    }
  }

  return (
    <div className="log-stream-widget">
      <div className="log-entries">
        {logs.map((log, index) => (
          <div key={`${log.id}-${index}`} className="log-entry">
            <span 
              className="log-level"
              style={{ color: getLevelColor(log.level) }}
            >
              {log.level}
            </span>
            <span className="log-timestamp">
              {format(new Date(log.timestamp), 'HH:mm:ss')}
            </span>
            <span className="log-service">{log.service}</span>
            <span className="log-message">{log.message}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

export default LogStreamWidget
