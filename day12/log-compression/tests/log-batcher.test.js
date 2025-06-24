const LogBatcher = require('../src/log-batcher');

describe('LogBatcher', () => {
  let batcher;

  beforeEach(() => {
    batcher = new LogBatcher({
      batchSize: 3,
      batchInterval: 1000,
      compression: { enabled: true, minSize: 10 }
    });
  });

  afterEach(() => {
    batcher.stop();
  });

  test('processes batch when size limit reached', async () => {
    const logs = [
      { message: 'log 1' },
      { message: 'log 2' },
      { message: 'log 3' }
    ];

    logs.forEach(log => batcher.addLog(log));
    
    // Wait for batch processing
    await new Promise(resolve => setTimeout(resolve, 100));
    
    const metrics = batcher.getMetrics();
    expect(metrics.batchesProcessed).toBe(1);
    expect(metrics.logsProcessed).toBe(3);
  });

  test('processes batch on timer', async () => {
    batcher.addLog({ message: 'single log' });
    
    // Wait for timer to trigger
    await new Promise(resolve => setTimeout(resolve, 1100));
    
    const metrics = batcher.getMetrics();
    expect(metrics.batchesProcessed).toBe(1);
    expect(metrics.logsProcessed).toBe(1);
  });

  test('tracks compression metrics', async () => {
    const largeLogs = Array.from({ length: 5 }, (_, i) => ({
      message: `Large log message with lots of repeated content `.repeat(100),
      level: 'info',
      timestamp: Date.now() + i
    }));

    largeLogs.forEach(log => batcher.addLog(log));
    
    await new Promise(resolve => setTimeout(resolve, 200));
    
    const metrics = batcher.getMetrics();
    expect(metrics.bytesSaved).toBeGreaterThan(0);
    expect(metrics.compression.compressionRatio).toBeGreaterThan(0);
  });
});
