import React, { useState, useEffect } from 'react';
import axios from 'axios';
import Dashboard from './components/Dashboard';
import Login from './components/Login';
import './App.css';

const API_BASE = process.env.REACT_APP_API_URL || 'http://localhost:8000';

function App() {
  const [token, setToken] = useState(localStorage.getItem('token'));
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (token) {
      // Validate token and set user
      setUser({ username: 'demo_user', role: 'developer' });
    }
    setLoading(false);
  }, [token]);

  const handleLogin = async (credentials) => {
    try {
      const response = await axios.post(`${API_BASE}/api/v1/auth/login`, credentials);
      const { access_token } = response.data;
      
      localStorage.setItem('token', access_token);
      setToken(access_token);
      setUser({ username: credentials.username, role: 'developer' });
      
      // Set default auth header
      axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
    } catch (error) {
      throw new Error('Invalid credentials');
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    setToken(null);
    setUser(null);
    delete axios.defaults.headers.common['Authorization'];
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner"></div>
        <p>Loading...</p>
      </div>
    );
  }

  return (
    <div className="App">
      {token && user ? (
        <Dashboard user={user} onLogout={handleLogout} />
      ) : (
        <Login onLogin={handleLogin} />
      )}
    </div>
  );
}

export default App;
