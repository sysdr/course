import React, { useState, useEffect } from 'react'
import DashboardBuilder from './components/dashboard/DashboardBuilder'
import DashboardList from './components/dashboard/DashboardList'
import { DashboardProvider } from './hooks/useDashboard'

function App() {
  const [currentView, setCurrentView] = useState('list')
  const [selectedDashboard, setSelectedDashboard] = useState(null)

  return (
    <DashboardProvider>
      <div className="app">
        <header className="app-header">
          <h1>Log Dashboard System</h1>
          <nav>
            <button 
              onClick={() => setCurrentView('list')}
              className={currentView === 'list' ? 'active' : ''}
            >
              Dashboards
            </button>
            <button 
              onClick={() => {
                setCurrentView('builder')
                setSelectedDashboard(null)
              }}
              className={currentView === 'builder' ? 'active' : ''}
            >
              New Dashboard
            </button>
          </nav>
        </header>

        <main className="app-main">
          {currentView === 'list' ? (
            <DashboardList 
              onEdit={(dashboard) => {
                setSelectedDashboard(dashboard)
                setCurrentView('builder')
              }}
            />
          ) : (
            <DashboardBuilder 
              dashboard={selectedDashboard}
              onSave={() => setCurrentView('list')}
            />
          )}
        </main>
      </div>
    </DashboardProvider>
  )
}

export default App
