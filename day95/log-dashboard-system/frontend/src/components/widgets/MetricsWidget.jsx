import React, { useEffect, useState } from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { useDashboard } from '../../hooks/useDashboard'

const MetricsWidget = ({ widget }) => {
  const { liveData } = useDashboard()
  const [metricsHistory, setMetricsHistory] = useState([])

  useEffect(() => {
    if (liveData.metrics) {
      const timestamp = new Date().toLocaleTimeString()
      const dataPoint = {
        time: timestamp,
        ...liveData.metrics
      }
      
      setMetricsHistory(prev => {
        const newHistory = [...prev, dataPoint].slice(-20)
        return newHistory
      })
    }
  }, [liveData])

  return (
    <div className="metrics-widget">
      <div className="current-metrics">
        {liveData.metrics && (
          <div className="metrics-grid">
            <div className="metric-item">
              <span className="metric-label">RPS</span>
              <span className="metric-value">
                {Math.round(liveData.metrics.requests_per_second)}
              </span>
            </div>
            <div className="metric-item">
              <span className="metric-label">Error Rate</span>
              <span className="metric-value">
                {(liveData.metrics.error_rate * 100).toFixed(1)}%
              </span>
            </div>
            <div className="metric-item">
              <span className="metric-label">Avg Response</span>
              <span className="metric-value">
                {Math.round(liveData.metrics.avg_response_time)}ms
              </span>
            </div>
            <div className="metric-item">
              <span className="metric-label">CPU</span>
              <span className="metric-value">
                {(liveData.metrics.cpu_usage * 100).toFixed(0)}%
              </span>
            </div>
          </div>
        )}
      </div>
      
      <div className="metrics-chart">
        <ResponsiveContainer width="100%" height={200}>
          <LineChart data={metricsHistory}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="time" />
            <YAxis />
            <Tooltip />
            <Line 
              type="monotone" 
              dataKey="requests_per_second" 
              stroke="#8884d8" 
              strokeWidth={2}
              dot={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}

export default MetricsWidget
