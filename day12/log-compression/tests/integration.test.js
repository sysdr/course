const request = require('supertest');
const app = require('../src/server');

describe('Integration Tests', () => {
  test('POST /logs accepts log data', async () => {
    const logs = [
      { message: 'Test log 1', level: 'info' },
      { message: 'Test log 2', level: 'error' }
    ];

    const response = await request(app)
      .post('/logs')
      .send({ logs })
      .expect(200);

    expect(response.body.received).toBe(2);
    expect(response.body.status).toBe('queued for processing');
  });

  test('GET /health returns service status', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body.status).toBe('healthy');
    expect(response.body.uptime).toBeGreaterThan(0);
  });

  test('GET /health/compression returns compression status', async () => {
    const response = await request(app)
      .get('/health/compression')
      .expect(200);

    expect(response.body.enabled).toBeDefined();
    expect(response.body.algorithm).toBe('gzip');
    expect(response.body.status).toBe('operational');
  });

  test('GET /metrics returns prometheus metrics', async () => {
    const response = await request(app)
      .get('/metrics')
      .expect(200);

    expect(response.text).toContain('log_compression_ratio_percent');
    expect(response.text).toContain('log_bytes_transmitted_total');
  });

  test('end-to-end compression workflow', async () => {
    const largeLogs = Array.from({ length: 10 }, (_, i) => ({
      message: `Large repetitive log message for compression testing `.repeat(50),
      level: 'info',
      source: `service-${i}`
    }));

    await request(app)
      .post('/logs')
      .send({ logs: largeLogs })
      .expect(200);

    // Wait for batch processing
    await new Promise(resolve => setTimeout(resolve, 1000));

    const statsResponse = await request(app)
      .get('/stats')
      .expect(200);

    expect(statsResponse.body.batchesProcessed).toBeGreaterThan(0);
    expect(statsResponse.body.logsProcessed).toBeGreaterThan(0);
    expect(parseFloat(statsResponse.body.compression.compressionRatio)).toBeGreaterThan(50);
  });
});
