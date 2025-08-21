import React, { useState } from 'react'
import LogStreamWidget from './LogStreamWidget'
import MetricsWidget from './MetricsWidget'
import AlertsWidget from './AlertsWidget'
import StatusWidget from './StatusWidget'

const Widget = ({ widget, onRemove, onUpdate }) => {
  const [showSettings, setShowSettings] = useState(false)

  const renderWidget = () => {
    switch (widget.type) {
      case 'log_stream':
        return <LogStreamWidget widget={widget} />
      case 'metrics':
        return <MetricsWidget widget={widget} />
      case 'alerts':
        return <AlertsWidget widget={widget} />
      case 'status':
        return <StatusWidget widget={widget} />
      default:
        return <div>Unknown widget type</div>
    }
  }

  return (
    <div className="widget">
      <div className="widget-header">
        <h4 className="widget-title">{widget.title}</h4>
        <div className="widget-controls">
          <button 
            onClick={() => setShowSettings(!showSettings)}
            className="widget-btn"
          >
            ⚙️
          </button>
          <button 
            onClick={onRemove}
            className="widget-btn remove-btn"
          >
            ×
          </button>
        </div>
      </div>

      <div className="widget-content">
        {renderWidget()}
      </div>

      {showSettings && (
        <div className="widget-settings">
          <input
            type="text"
            value={widget.title}
            onChange={(e) => onUpdate({ title: e.target.value })}
            placeholder="Widget Title"
          />
          {/* Add widget-specific settings here */}
        </div>
      )}
    </div>
  )
}

export default Widget
