import axios from 'axios';

const API_BASE = process.env.NODE_ENV === 'production' ? '/api' : 'http://localhost:5000/api';

const api = axios.create({
  baseURL: API_BASE,
  timeout: 10000,
});

export const logService = {
  // Get logs with pagination and filtering
  getLogs: async (params = {}) => {
    const response = await api.get('/logs', { params });
    return response.data;
  },

  // Get single log entry
  getLogDetail: async (id) => {
    const response = await api.get(`/logs/${id}`);
    return response.data;
  },

  // Get log statistics
  getStats: async () => {
    const response = await api.get('/logs/stats');
    return response.data;
  },

  // Initialize sample data
  initSampleData: async () => {
    const response = await api.post('/logs/init');
    return response.data;
  },

  // Health check
  healthCheck: async () => {
    const response = await api.get('/health');
    return response.data;
  }
};

export default api;
