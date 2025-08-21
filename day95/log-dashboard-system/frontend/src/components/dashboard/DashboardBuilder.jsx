import React, { useState, useEffect } from 'react'
import { Responsive, WidthProvider } from 'react-grid-layout'
import Widget from '../widgets/Widget'
import WidgetSelector from './WidgetSelector'
import { useDashboard } from '../../hooks/useDashboard'
import 'react-grid-layout/css/styles.css'
import 'react-resizable/css/styles.css'

const ResponsiveGridLayout = WidthProvider(Responsive)

const DashboardBuilder = ({ dashboard, onSave }) => {
  const { saveDashboard } = useDashboard()
  const [name, setName] = useState(dashboard?.name || 'New Dashboard')
  const [widgets, setWidgets] = useState(dashboard?.widgets || [])
  const [layouts, setLayouts] = useState({})
  const [showWidgetSelector, setShowWidgetSelector] = useState(false)

  const handleLayoutChange = (layout, layouts) => {
    setLayouts(layouts)
    
    // Update widget configs with new layout
    const updatedWidgets = widgets.map(widget => {
      const layoutItem = layout.find(item => item.i === widget.id)
      if (layoutItem) {
        return {
          ...widget,
          config: {
            ...widget.config,
            x: layoutItem.x,
            y: layoutItem.y,
            w: layoutItem.w,
            h: layoutItem.h
          }
        }
      }
      return widget
    })
    setWidgets(updatedWidgets)
  }

  const addWidget = (widgetType) => {
    const newWidget = {
      id: `widget-${Date.now()}`,
      type: widgetType,
      title: `${widgetType.charAt(0).toUpperCase() + widgetType.slice(1)} Widget`,
      config: {
        x: 0,
        y: 0,
        w: 4,
        h: 4,
        minW: 2,
        minH: 2
      },
      filters: {},
      settings: {}
    }
    setWidgets([...widgets, newWidget])
    setShowWidgetSelector(false)
  }

  const removeWidget = (widgetId) => {
    setWidgets(widgets.filter(w => w.id !== widgetId))
  }

  const updateWidget = (widgetId, updates) => {
    setWidgets(widgets.map(w => 
      w.id === widgetId ? { ...w, ...updates } : w
    ))
  }

  const handleSave = async () => {
    try {
      const dashboardData = {
        id: dashboard?.id,
        name,
        widgets,
        layout_settings: layouts
      }
      await saveDashboard(dashboardData)
      onSave()
    } catch (error) {
      console.error('Error saving dashboard:', error)
    }
  }

  const gridLayout = widgets.map(widget => ({
    i: widget.id,
    x: widget.config.x,
    y: widget.config.y,
    w: widget.config.w,
    h: widget.config.h,
    minW: widget.config.minW || 2,
    minH: widget.config.minH || 2
  }))

  return (
    <div className="dashboard-builder">
      <div className="builder-header">
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Dashboard Name"
          className="dashboard-name-input"
        />
        <div className="builder-actions">
          <button 
            onClick={() => setShowWidgetSelector(true)}
            className="add-widget-btn"
          >
            Add Widget
          </button>
          <button onClick={handleSave} className="save-btn">
            Save Dashboard
          </button>
        </div>
      </div>

      <div className="grid-container">
        <ResponsiveGridLayout
          className="layout"
          layouts={layouts}
          onLayoutChange={handleLayoutChange}
          breakpoints={{ lg: 1200, md: 996, sm: 768, xs: 480, xxs: 0 }}
          cols={{ lg: 12, md: 10, sm: 6, xs: 4, xxs: 2 }}
          rowHeight={60}
          margin={[16, 16]}
        >
          {widgets.map(widget => (
            <div key={widget.id} className="widget-container">
              <Widget
                widget={widget}
                onRemove={() => removeWidget(widget.id)}
                onUpdate={(updates) => updateWidget(widget.id, updates)}
              />
            </div>
          ))}
        </ResponsiveGridLayout>
      </div>

      {showWidgetSelector && (
        <WidgetSelector
          onSelect={addWidget}
          onClose={() => setShowWidgetSelector(false)}
        />
      )}
    </div>
  )
}

export default DashboardBuilder
