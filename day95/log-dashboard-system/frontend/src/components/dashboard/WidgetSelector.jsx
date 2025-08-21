import React from 'react'

const WIDGET_TYPES = [
  {
    type: 'log_stream',
    name: 'Log Stream',
    description: 'Real-time log entries with filtering',
    icon: '📄'
  },
  {
    type: 'metrics',
    name: 'Metrics Chart',
    description: 'System metrics and performance data',
    icon: '📊'
  },
  {
    type: 'alerts',
    name: 'Alerts',
    description: 'Critical alerts and notifications',
    icon: '🚨'
  },
  {
    type: 'status',
    name: 'Status Board',
    description: 'Service health status overview',
    icon: '🔍'
  }
]

const WidgetSelector = ({ onSelect, onClose }) => {
  return (
    <div className="widget-selector-overlay">
      <div className="widget-selector">
        <div className="selector-header">
          <h3>Add Widget</h3>
          <button onClick={onClose} className="close-btn">×</button>
        </div>
        
        <div className="widget-types">
          {WIDGET_TYPES.map(widgetType => (
            <div
              key={widgetType.type}
              className="widget-type-card"
              onClick={() => onSelect(widgetType.type)}
            >
              <div className="widget-icon">{widgetType.icon}</div>
              <h4>{widgetType.name}</h4>
              <p>{widgetType.description}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

export default WidgetSelector
