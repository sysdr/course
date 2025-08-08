import React from 'react';
import { Link, useLocation } from 'react-router-dom';

const Header = () => {
  const location = useLocation();

  return (
    <header className="header">
      <h1>Distributed Log Viewer</h1>
      <nav>
        <Link 
          to="/" 
          style={{ 
            textDecoration: location.pathname === '/' ? 'underline' : 'none' 
          }}
        >
          Dashboard
        </Link>
        <Link 
          to="/logs" 
          style={{ 
            textDecoration: location.pathname === '/logs' ? 'underline' : 'none' 
          }}
        >
          Log Viewer
        </Link>
      </nav>
    </header>
  );
};

export default Header;
