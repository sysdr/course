import axios from 'axios';

const API_BASE_URL = '/api';

class ApiService {
  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  setAuthToken(token) {
    if (token) {
      this.client.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    } else {
      delete this.client.defaults.headers.common['Authorization'];
    }
  }

  async login(username, password) {
    const response = await this.client.post('/auth/login', {
      username,
      password,
    });
    return response.data;
  }

  async getProfile() {
    const response = await this.client.get('/auth/profile');
    return response.data;
  }

  async searchLogs(params = {}) {
    const response = await this.client.get('/logs/search', { params });
    return response.data;
  }

  async exportLogs(params = {}) {
    const response = await this.client.get('/logs/export', { params });
    return response.data;
  }

  async getAccessibleResources() {
    const response = await this.client.get('/logs/accessible-resources');
    return response.data;
  }

  async getAuditSummary(hours = 24) {
    const response = await this.client.get('/admin/audit-summary', {
      params: { hours },
    });
    return response.data;
  }

  async getSecurityEvents(limit = 50) {
    const response = await this.client.get('/admin/security-events', {
      params: { limit },
    });
    return response.data;
  }

  async getSystemStatus() {
    const response = await this.client.get('/admin/system-status');
    return response.data;
  }
}

export default new ApiService();
