import React from 'react';
import { Layout, Menu, Button, Typography, Avatar } from 'antd';
import { 
  DashboardOutlined, 
  SearchOutlined, 
  SettingOutlined,
  LogoutOutlined,
  UserOutlined 
} from '@ant-design/icons';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../services/authContext';

const { Header } = Layout;
const { Text } = Typography;

function NavBar() {
  const navigate = useNavigate();
  const location = useLocation();
  const { user, logout } = useAuth();

  const menuItems = [
    {
      key: '/dashboard',
      icon: <DashboardOutlined />,
      label: 'Dashboard',
    },
    {
      key: '/logs',
      icon: <SearchOutlined />,
      label: 'Log Search',
    },
  ];

  // Add admin menu for administrators
  if (user?.roles?.includes('administrator')) {
    menuItems.push({
      key: '/admin',
      icon: <SettingOutlined />,
      label: 'Administration',
    });
  }

  const handleMenuClick = ({ key }) => {
    navigate(key);
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <Header className="navbar">
      <div className="navbar-brand">
        <Text strong style={{ color: 'white', fontSize: '18px' }}>
          RBAC Log System
        </Text>
      </div>
      
      <Menu
        theme="dark"
        mode="horizontal"
        selectedKeys={[location.pathname]}
        items={menuItems}
        onClick={handleMenuClick}
        style={{ flex: 1, minWidth: 0 }}
      />
      
      <div className="navbar-user">
        <Avatar icon={<UserOutlined />} />
        <Text style={{ color: 'white', marginLeft: 8, marginRight: 16 }}>
          {user?.username}
        </Text>
        <Button 
          type="text" 
          icon={<LogoutOutlined />} 
          onClick={handleLogout}
          style={{ color: 'white' }}
        >
          Logout
        </Button>
      </div>
    </Header>
  );
}

export default NavBar;
