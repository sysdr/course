const axios = require('axios').default;

const SERVICE_URL = process.env.SERVICE_URL || 'http://localhost:8080';

function generateLogEntry(index) {
  const levels = ['info', 'warn', 'error', 'debug'];
  const sources = ['auth-service', 'payment-service', 'notification-service', 'user-service'];
  const messages = [
    'User authentication successful',
    'Payment processing completed',
    'Database connection established',
    'Cache miss for key',
    'Rate limit exceeded for user',
    'Email notification sent successfully'
  ];

  return {
    timestamp: Date.now(),
    level: levels[Math.floor(Math.random() * levels.length)],
    source: sources[Math.floor(Math.random() * sources.length)],
    message: `${messages[Math.floor(Math.random() * messages.length)]} - ID: ${index}`,
    metadata: {
      requestId: `req-${Math.random().toString(36).substr(2, 9)}`,
      userId: Math.floor(Math.random() * 10000),
      duration: Math.floor(Math.random() * 1000)
    }
  };
}

async function sendLogs(count = 100) {
  const logs = Array.from({ length: count }, (_, i) => generateLogEntry(i));
  
  try {
    const response = await axios.post(`${SERVICE_URL}/logs`, { logs });
    console.log(`Sent ${count} logs:`, response.data);
    return response.data;
  } catch (error) {
    console.error('Failed to send logs:', error.response?.data || error.message);
    throw error;
  }
}

async function getStats() {
  try {
    const response = await axios.get(`${SERVICE_URL}/stats`);
    console.log('Current stats:', response.data);
    return response.data;
  } catch (error) {
    console.error('Failed to get stats:', error.response?.data || error.message);
    throw error;
  }
}

module.exports = { sendLogs, getStats };

// CLI usage
if (require.main === module) {
  const count = parseInt(process.argv[2]) || 100;
  
  (async () => {
    try {
      await sendLogs(count);
      
      // Wait for processing
      setTimeout(async () => {
        await getStats();
      }, 2000);
    } catch (error) {
      process.exit(1);
    }
  })();
}
