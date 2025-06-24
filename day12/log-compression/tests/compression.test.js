const CompressionService = require('../src/compression-service');

describe('CompressionService', () => {
  let service;

  beforeEach(() => {
    service = new CompressionService({ minSize: 100 });
  });

  test('compresses large payloads', async () => {
    const largeData = 'test data '.repeat(1000);
    const result = await service.compress(largeData);
    
    expect(result.compressed).toBe(true);
    expect(result.compressedSize).toBeLessThan(result.originalSize);
    expect(result.ratio).toBeGreaterThan(0);
  });

  test('skips compression for small payloads', async () => {
    const smallData = 'test';
    const result = await service.compress(smallData);
    
    expect(result.compressed).toBe(false);
    expect(result.data).toBe(smallData);
  });

  test('handles compression errors gracefully', async () => {
    const result = await service.compress(null);
    expect(result.compressed).toBe(false);
  });

  test('can decompress compressed data', async () => {
    const originalData = 'test data '.repeat(1000);
    const compressed = await service.compress(originalData);
    const decompressed = await service.decompress(compressed.data);
    
    expect(decompressed.toString()).toBe(originalData);
  });

  test('tracks metrics correctly', async () => {
    const data1 = 'test data '.repeat(500);
    const data2 = 'more test data '.repeat(300);
    
    await service.compress(data1);
    await service.compress(data2);
    
    const metrics = service.getMetrics();
    expect(metrics.compressionRatio).toBeGreaterThan(0);
    expect(metrics.totalOriginal).toBeGreaterThan(0);
    expect(metrics.totalCompressed).toBeGreaterThan(0);
  });
});
