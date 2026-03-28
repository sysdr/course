import React, { createContext, useState, useContext, useEffect } from 'react';
import apiService from './apiService';

const AuthContext = createContext();

export function useAuth() {
  return useContext(AuthContext);
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      apiService.setAuthToken(token);
      // Verify token is still valid
      apiService.getProfile()
        .then(response => {
          setUser(response);
        })
        .catch(() => {
          localStorage.removeItem('token');
          apiService.setAuthToken(null);
        })
        .finally(() => {
          setLoading(false);
        });
    } else {
      setLoading(false);
    }
  }, []);

  const login = async (username, password) => {
    const response = await apiService.login(username, password);
    const { access_token, user_info } = response;
    
    localStorage.setItem('token', access_token);
    apiService.setAuthToken(access_token);
    setUser(user_info);
    
    return response;
  };

  const logout = () => {
    localStorage.removeItem('token');
    apiService.setAuthToken(null);
    setUser(null);
  };

  const value = {
    user,
    login,
    logout,
    isAuthenticated: !!user
  };

  return (
    <AuthContext.Provider value={value}>
      {!loading && children}
    </AuthContext.Provider>
  );
}
