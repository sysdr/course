import React, { useState } from 'react';
import { Form, Input, Button, Card, Alert, Typography } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { useAuth } from '../services/authContext';
import { useNavigate } from 'react-router-dom';

const { Title } = Typography;

function LoginPage() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const { login } = useAuth();
  const navigate = useNavigate();

  const onFinish = async (values) => {
    setLoading(true);
    setError(null);
    
    try {
      await login(values.username, values.password);
      navigate('/dashboard');
    } catch (err) {
      setError('Invalid credentials. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      <Card className="login-card">
        <Title level={2} style={{ textAlign: 'center', color: '#1890ff' }}>
          Log Processing RBAC System
        </Title>
        
        {error && (
          <Alert 
            message={error} 
            type="error" 
            showIcon 
            style={{ marginBottom: 16 }} 
          />
        )}
        
        <Form
          name="login"
          onFinish={onFinish}
          size="large"
          autoComplete="off"
        >
          <Form.Item
            name="username"
            rules={[{ required: true, message: 'Please input your username!' }]}
          >
            <Input 
              prefix={<UserOutlined />} 
              placeholder="Username" 
            />
          </Form.Item>

          <Form.Item
            name="password"
            rules={[{ required: true, message: 'Please input your password!' }]}
          >
            <Input.Password
              prefix={<LockOutlined />}
              placeholder="Password"
            />
          </Form.Item>

          <Form.Item>
            <Button 
              type="primary" 
              htmlType="submit" 
              loading={loading}
              style={{ width: '100%' }}
            >
              Log In
            </Button>
          </Form.Item>
        </Form>
        
        <div className="demo-credentials">
          <Title level={5}>Demo Credentials:</Title>
          <p><strong>Admin:</strong> admin / admin123</p>
          <p><strong>Developer:</strong> developer / dev123</p>
          <p><strong>Analyst:</strong> analyst / analyst123</p>
        </div>
      </Card>
    </div>
  );
}

export default LoginPage;
