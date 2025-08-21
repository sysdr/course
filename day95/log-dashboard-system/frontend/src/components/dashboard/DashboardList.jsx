import React, { useState } from 'react'
import { useDashboard } from '../../hooks/useDashboard'
import { format } from 'date-fns'

const DashboardList = ({ onEdit }) => {
  const { dashboards, templates, deleteDashboard, createFromTemplate } = useDashboard()
  const [showTemplates, setShowTemplates] = useState(false)

  const handleCreateFromTemplate = async (template) => {
    const name = prompt(`Name for new dashboard based on ${template.name}:`)
    if (name) {
      await createFromTemplate(template.id, name)
    }
  }

  return (
    <div className="dashboard-list">
      <div className="list-header">
        <h2>My Dashboards</h2>
        <button 
          onClick={() => setShowTemplates(!showTemplates)}
          className="templates-btn"
        >
          {showTemplates ? 'Hide Templates' : 'Show Templates'}
        </button>
      </div>

      {showTemplates && (
        <div className="templates-section">
          <h3>Dashboard Templates</h3>
          <div className="templates-grid">
            {templates.map(template => (
              <div key={template.id} className="template-card">
                <h4>{template.name}</h4>
                <p>{template.description}</p>
                <div className="template-category">{template.category}</div>
                <button 
                  onClick={() => handleCreateFromTemplate(template)}
                  className="use-template-btn"
                >
                  Use Template
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="dashboards-grid">
        {dashboards.map(dashboard => (
          <div key={dashboard.id} className="dashboard-card">
            <div className="card-content">
              <h3>{dashboard.name}</h3>
              <p>{dashboard.description || 'No description'}</p>
              <div className="card-meta">
                <span>{dashboard.widgets?.length || 0} widgets</span>
                <span>Modified {format(new Date(dashboard.updated_at), 'MMM dd, yyyy')}</span>
              </div>
            </div>
            <div className="card-actions">
              <button 
                onClick={() => onEdit(dashboard)}
                className="edit-btn"
              >
                Edit
              </button>
              <button 
                onClick={() => {
                  if (confirm('Delete this dashboard?')) {
                    deleteDashboard(dashboard.id)
                  }
                }}
                className="delete-btn"
              >
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>

      {dashboards.length === 0 && (
        <div className="empty-state">
          <p>No dashboards yet. Create your first dashboard or use a template!</p>
        </div>
      )}
    </div>
  )
}

export default DashboardList
