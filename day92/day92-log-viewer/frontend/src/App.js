import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Header from './components/Header';
import LogViewer from './components/LogViewer';
import LogDetail from './components/LogDetail';
import Dashboard from './components/Dashboard';
import './App.css';

function App() {
  return (
    <Router>
      <div className="App">
        <Header />
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/logs" element={<LogViewer />} />
          <Route path="/logs/:id" element={<LogDetail />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
