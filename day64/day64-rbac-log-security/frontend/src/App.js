import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from 'react-query';
import { Layout } from 'antd';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import LogSearchPage from './pages/LogSearchPage';
import AdminPage from './pages/AdminPage';
import NavBar from './components/NavBar';
import { AuthProvider, useAuth } from './services/authContext';
import './styles/App.css';

const { Content } = Layout;
const queryClient = new QueryClient();

function ProtectedRoute({ children }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/login" />;
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <Router>
          <div className="App">
            <AppContent />
          </div>
        </Router>
      </AuthProvider>
    </QueryClientProvider>
  );
}

function AppContent() {
  const { isAuthenticated } = useAuth();

  return (
    <Layout className="layout">
      {isAuthenticated && <NavBar />}
      <Content className="content">
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route 
            path="/dashboard" 
            element={
              <ProtectedRoute>
                <DashboardPage />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/logs" 
            element={
              <ProtectedRoute>
                <LogSearchPage />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/admin" 
            element={
              <ProtectedRoute>
                <AdminPage />
              </ProtectedRoute>
            } 
          />
          <Route path="/" element={<Navigate to="/dashboard" />} />
        </Routes>
      </Content>
    </Layout>
  );
}

export default App;
