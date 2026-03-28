import React from 'react';
import { Card, Typography, Row, Col, Statistic, Table, Tag } from 'antd';
import { useQuery } from 'react-query';
import apiService from '../services/apiService';

const { Title } = Typography;

function AdminPage() {
  const { data: status } = useQuery('system-status', () => apiService.getSystemStatus(), {
    refetchInterval: 15000,
  });
  const { data: events } = useQuery('security-events', () => apiService.getSecurityEvents(20), {
    refetchInterval: 20000,
  });

  return (
    <div className="admin-page">
      <Title level={2}>Administration</Title>
      <Row gutter={[16, 16]}>
        <Col xs={24} sm={12} md={8}>
          <Card>
            <Statistic title="Registered users" value={status?.active_users ?? 0} />
          </Card>
        </Col>
        <Col xs={24} sm={12} md={8}>
          <Card>
            <Statistic title="Audit log entries" value={status?.audit_logs_count ?? 0} />
          </Card>
        </Col>
        <Col xs={24} sm={12} md={8}>
          <Card>
            <Statistic title="Security events" value={status?.security_events_count ?? 0} />
          </Card>
        </Col>
      </Row>
      <Card title="Recent security events" style={{ marginTop: 24 }}>
        <Table
          rowKey={(r, i) => r.timestamp + String(i)}
          size="small"
          dataSource={events?.security_events || []}
          pagination={false}
          columns={[
            { title: 'Time', dataIndex: 'timestamp', width: 180 },
            { title: 'Type', dataIndex: 'event_type', render: (t) => <Tag>{t}</Tag> },
            { title: 'User', dataIndex: 'user_id' },
            { title: 'Severity', dataIndex: 'severity' },
            { title: 'Description', dataIndex: 'description', ellipsis: true },
          ]}
        />
      </Card>
    </div>
  );
}

export default AdminPage;
