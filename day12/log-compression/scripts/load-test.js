const axios = require('axios');
const { performance } = require('perf_hooks');

const SERVICE_URL = process.env.SERVICE_URL || 'http://localhost:8080';
const CONCURRENT_REQUESTS = parseInt(process.env.CONCURRENT_REQUESTS) || 10;
const TOTAL_REQUESTS = parseInt(process.env.TOTAL_REQUESTS) || 100;
const LOGS_PER_REQUEST = parseInt(process.env.LOGS_PER_REQUEST) || 50;

function generateLogBatch(size) {
  return Array.from({ length: size }, (_, i) => ({
    timestamp: Date.now(),
    level: ['info', 'warn', 'error'][Math.floor(Math.random() * 3)],
    message: `Load test log message ${i} with some repetitive content for compression testing. `.repeat(10),
    source: `load-test-${Math.floor(Math.random() * 5)}`
  }));
}

async function sendRequest() {
  const logs = generateLogBatch(LOGS_PER_REQUEST);
  const start = performance.now();
  
  try {
    await axios.post(`${SERVICE_URL}/logs`, { logs });
    const duration = performance.now() - start;
    return { success: true, duration, logCount: logs.length };
  } catch (error) {
    const duration = performance.now() - start;
    return { success: false, duration, error: error.message };
  }
}

async function runLoadTest() {
  console.log(`🚀 Starting load test:`);
  console.log(`   Concurrent requests: ${CONCURRENT_REQUESTS}`);
  console.log(`   Total requests: ${TOTAL_REQUESTS}`);
  console.log(`   Logs per request: ${LOGS_PER_REQUEST}`);
  console.log();

  const startTime = performance.now();
  const results = [];
  
  for (let i = 0; i < TOTAL_REQUESTS; i += CONCURRENT_REQUESTS) {
    const batch = Math.min(CONCURRENT_REQUESTS, TOTAL_REQUESTS - i);
    const promises = Array.from({ length: batch }, () => sendRequest());
    
    const batchResults = await Promise.all(promises);
    results.push(...batchResults);
    
    process.stdout.write(`\rProgress: ${Math.min(i + batch, TOTAL_REQUESTS)}/${TOTAL_REQUESTS}`);
  }
  
  const totalTime = performance.now() - startTime;
  
  console.log('\n\n📊 Load Test Results:');
  
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  
  console.log(`   Success rate: ${(successful.length / results.length * 100).toFixed(2)}%`);
  console.log(`   Failed requests: ${failed.length}`);
  console.log(`   Total time: ${(totalTime / 1000).toFixed(2)}s`);
  console.log(`   Requests/sec: ${(results.length / (totalTime / 1000)).toFixed(2)}`);
  
  if (successful.length > 0) {
    const durations = successful.map(r => r.duration);
    durations.sort((a, b) => a - b);
    
    console.log(`   Average response time: ${(durations.reduce((a, b) => a + b, 0) / durations.length).toFixed(2)}ms`);
    console.log(`   95th percentile: ${durations[Math.floor(durations.length * 0.95)].toFixed(2)}ms`);
    console.log(`   99th percentile: ${durations[Math.floor(durations.length * 0.99)].toFixed(2)}ms`);
  }
  
  // Get final stats
  console.log('\n📈 Final Service Stats:');
  try {
    const statsResponse = await axios.get(`${SERVICE_URL}/stats`);
    const stats = statsResponse.data;
    
    console.log(`   Batches processed: ${stats.batchesProcessed}`);
    console.log(`   Logs processed: ${stats.logsProcessed}`);
    console.log(`   Compression ratio: ${stats.compression.compressionRatio}%`);
    console.log(`   Bandwidth reduction: ${stats.bandwidthReduction}`);
    console.log(`   Bytes saved: ${(stats.bytesSaved / 1024).toFixed(2)} KB`);
  } catch (error) {
    console.log('   Could not retrieve final stats');
  }
}

if (require.main === module) {
  runLoadTest().catch(console.error);
}

module.exports = { runLoadTest };
