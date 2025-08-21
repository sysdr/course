import React, { createContext, useContext, useState, useEffect } from 'react'
import axios from 'axios'

const DashboardContext = createContext()

export const useDashboard = () => {
  const context = useContext(DashboardContext)
  if (!context) {
    throw new Error('useDashboard must be used within DashboardProvider')
  }
  return context
}

export const DashboardProvider = ({ children }) => {
  const [dashboards, setDashboards] = useState([])
  const [templates, setTemplates] = useState([])
  const [liveData, setLiveData] = useState({})
  const [websocket, setWebsocket] = useState(null)

  useEffect(() => {
    loadDashboards()
    loadTemplates()
    
    // Generate unique client ID for WebSocket connection
    const clientId = `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    const ws = new WebSocket(`ws://localhost:8000/ws/${clientId}`)
    
    ws.onopen = () => {
      console.log('WebSocket connected')
      setWebsocket(ws)
    }
    
    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        if (data.type === 'live_data') {
          setLiveData(data)
        }
      } catch (error) {
        console.error('Error parsing WebSocket message:', error)
      }
    }
    
    ws.onerror = (error) => {
      console.error('WebSocket error:', error)
    }
    
    ws.onclose = () => {
      console.log('WebSocket disconnected')
      setWebsocket(null)
    }

    return () => {
      if (ws) {
        ws.close()
      }
    }
  }, [])

  const loadDashboards = async () => {
    try {
      const response = await axios.get('/api/dashboards')
      setDashboards(response.data)
    } catch (error) {
      console.error('Error loading dashboards:', error)
    }
  }

  const loadTemplates = async () => {
    try {
      const response = await axios.get('/api/templates')
      setTemplates(response.data)
    } catch (error) {
      console.error('Error loading templates:', error)
    }
  }

  const saveDashboard = async (dashboard) => {
    try {
      if (dashboard.id) {
        await axios.put(`/api/dashboards/${dashboard.id}`, dashboard)
      } else {
        await axios.post('/api/dashboards', dashboard)
      }
      loadDashboards()
    } catch (error) {
      console.error('Error saving dashboard:', error)
      throw error
    }
  }

  const deleteDashboard = async (id) => {
    try {
      await axios.delete(`/api/dashboards/${id}`)
      loadDashboards()
    } catch (error) {
      console.error('Error deleting dashboard:', error)
      throw error
    }
  }

  const createFromTemplate = async (templateId, name) => {
    try {
      await axios.post(`/api/dashboards/from-template/${templateId}`, { name })
      loadDashboards()
    } catch (error) {
      console.error('Error creating from template:', error)
      throw error
    }
  }

  return (
    <DashboardContext.Provider value={{
      dashboards,
      templates,
      liveData,
      saveDashboard,
      deleteDashboard,
      createFromTemplate,
      loadDashboards
    }}>
      {children}
    </DashboardContext.Provider>
  )
}
