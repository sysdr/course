const Benchmark = require('benchmark');
const CompressionService = require('../src/compression-service');

const service = new CompressionService();
const testData = 'Test log data with repetitive content for compression benchmarking. '.repeat(1000);

const suite = new Benchmark.Suite;

suite
  .add('Compression#gzip', {
    defer: true,
    fn: async function(deferred) {
      await service.compress(testData);
      deferred.resolve();
    }
  })
  .on('cycle', function(event) {
    console.log(String(event.target));
  })
  .on('complete', function() {
    console.log('Compression benchmark completed');
    const metrics = service.getMetrics();
    console.log(`Average compression ratio: ${metrics.compressionRatio}%`);
  })
  .run({ 'async': true });
