import React from 'react';
import { Card, Row, Col, Statistic, Typography, List, Tag } from 'antd';
import { 
  UserOutlined, 
  SafetyCertificateOutlined, 
  EyeOutlined,
  AlertOutlined 
} from '@ant-design/icons';
import { useAuth } from '../services/authContext';
import { useQuery } from 'react-query';
import apiService from '../services/apiService';

const { Title } = Typography;

function DashboardPage() {
  const { user } = useAuth();
  
  const { data: accessibleResources } = useQuery(
    'accessible-resources',
    () => apiService.getAccessibleResources(),
    { enabled: !!user }
  );
  
  const { data: auditSummary } = useQuery(
    'audit-summary',
    () => apiService.getAuditSummary(),
    { 
      enabled: !!user && user.roles.includes('administrator'),
      refetchInterval: 30000 // Refresh every 30 seconds
    }
  );

  const getRoleColor = (role) => {
    const colors = {
      'administrator': 'red',
      'developer': 'blue', 
      'analyst': 'green',
      'support': 'orange'
    };
    return colors[role] || 'default';
  };

  return (
    <div className="dashboard">
      <Title level={2}>Security Dashboard</Title>
      
      <Row gutter={[24, 24]}>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="User ID"
              value={user?.user_id || 'N/A'}
              prefix={<UserOutlined />}
            />
          </Card>
        </Col>
        
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Active Roles"
              value={user?.roles?.length || 0}
              prefix={<SafetyCertificateOutlined />}
            />
          </Card>
        </Col>
        
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Accessible Resources"
              value={accessibleResources?.accessible_resources?.length || 0}
              prefix={<EyeOutlined />}
            />
          </Card>
        </Col>
        
        {user?.roles?.includes('administrator') && (
          <Col xs={24} sm={12} lg={6}>
            <Card>
              <Statistic
                title="Success Rate"
                value={auditSummary?.audit_summary?.success_rate || 0}
                suffix="%"
                prefix={<AlertOutlined />}
              />
            </Card>
          </Col>
        )}
      </Row>
      
      <Row gutter={[24, 24]} style={{ marginTop: 24 }}>
        <Col xs={24} lg={12}>
          <Card title="Your Roles" bordered={false}>
            <div>
              {user?.roles?.map(role => (
                <Tag key={role} color={getRoleColor(role)} style={{ marginBottom: 8 }}>
                  {role.toUpperCase()}
                </Tag>
              ))}
            </div>
          </Card>
        </Col>
        
        <Col xs={24} lg={12}>
          <Card title="Accessible Resources" bordered={false}>
            <List
              size="small"
              dataSource={accessibleResources?.accessible_resources?.slice(0, 10) || []}
              renderItem={item => (
                <List.Item>
                  <Typography.Text code>{item}</Typography.Text>
                </List.Item>
              )}
            />
          </Card>
        </Col>
      </Row>
      
      {user?.roles?.includes('administrator') && auditSummary && (
        <Row gutter={[24, 24]} style={{ marginTop: 24 }}>
          <Col xs={24}>
            <Card title="System Overview (Last 24 Hours)" bordered={false}>
              <Row gutter={[16, 16]}>
                <Col xs={12} sm={6}>
                  <Statistic 
                    title="Total Accesses" 
                    value={auditSummary.audit_summary.total_accesses} 
                  />
                </Col>
                <Col xs={12} sm={6}>
                  <Statistic 
                    title="Successful" 
                    value={auditSummary.audit_summary.successful_accesses}
                    valueStyle={{ color: '#3f8600' }}
                  />
                </Col>
                <Col xs={12} sm={6}>
                  <Statistic 
                    title="Failed" 
                    value={auditSummary.audit_summary.failed_accesses}
                    valueStyle={{ color: '#cf1322' }}
                  />
                </Col>
                <Col xs={12} sm={6}>
                  <Statistic 
                    title="Unique Users" 
                    value={auditSummary.audit_summary.unique_users} 
                  />
                </Col>
              </Row>
            </Card>
          </Col>
        </Row>
      )}
    </div>
  );
}

export default DashboardPage;
