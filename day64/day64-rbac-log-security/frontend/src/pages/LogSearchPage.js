import React, { useState } from 'react';
import { Card, Form, Input, Button, Table, Tag, Typography, message } from 'antd';
import { SearchOutlined } from '@ant-design/icons';
import apiService from '../services/apiService';

const { Title } = Typography;

function LogSearchPage() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);

  const onSearch = async (values) => {
    setLoading(true);
    try {
      const res = await apiService.searchLogs({
        service: values.service || undefined,
        level: values.level || undefined,
      });
      setData(res);
      message.success('Search completed');
    } catch (e) {
      message.error(e.response?.data?.detail || 'Search failed');
    } finally {
      setLoading(false);
    }
  };

  const columns = [
    { title: 'Time', dataIndex: 'timestamp', key: 'timestamp', width: 180 },
    { title: 'Level', dataIndex: 'level', key: 'level', render: (l) => <Tag>{l}</Tag> },
    { title: 'Service', dataIndex: 'service', key: 'service' },
    { title: 'Message', dataIndex: 'message', key: 'message', ellipsis: true },
  ];

  return (
    <div className="log-search">
      <Title level={2}>Log Search</Title>
      <Card className="search-form">
        <Form layout="inline" onFinish={onSearch}>
          <Form.Item name="service" label="Service">
            <Input placeholder="e.g. application" allowClear style={{ width: 200 }} />
          </Form.Item>
          <Form.Item name="level" label="Level">
            <Input placeholder="INFO, WARN..." allowClear style={{ width: 120 }} />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" icon={<SearchOutlined />} loading={loading}>
              Search
            </Button>
          </Form.Item>
        </Form>
      </Card>
      <Card className="log-results" title={`Results (${data?.count ?? 0})`}>
        <Table
          rowKey="id"
          loading={loading}
          dataSource={data?.logs || []}
          columns={columns}
          pagination={{ pageSize: 10 }}
        />
      </Card>
    </div>
  );
}

export default LogSearchPage;
