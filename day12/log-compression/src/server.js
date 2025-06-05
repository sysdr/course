const express = require('express');
const compression = require('compression');
const LogBatcher = require('./log-batcher');
const client = require('prom-client');

const app = express();
const port = process.env.PORT || 8080;

// Prometheus metrics
const register = new client.Registry();
const compressionRatioGauge = new client.Gauge({
  name: 'log_compression_ratio_percent',
  help: 'Current compression ratio percentage'
});
const bytesTransmittedCounter = new client.Counter({
  name: 'log_bytes_transmitted_total',
  help: 'Total bytes transmitted'
});
const bytesSavedCounter = new client.Counter({
  name: 'log_bytes_saved_total',
  help: 'Total bytes saved through compression'
});

register.registerMetric(compressionRatioGauge);
register.registerMetric(bytesTransmittedCounter);
register.registerMetric(bytesSavedCounter);

// Middleware
app.use(express.json());
app.use(compression());

// Initialize log batcher
const logBatcher = new LogBatcher({
  batchSize: parseInt(process.env.BATCH_SIZE) || 50,
  batchInterval: parseInt(process.env.BATCH_INTERVAL) || 3000,
  compression: {
    enabled: process.env.COMPRESSION_ENABLED !== 'false',
    algorithm: process.env.COMPRESSION_ALGORITHM || 'gzip',
    level: parseInt(process.env.COMPRESSION_LEVEL) || 6,
    minSize: parseInt(process.env.MIN_COMPRESS_SIZE) || 1024
  }
});

// Routes
app.post('/logs', (req, res) => {
  const { logs } = req.body;
  
  if (!Array.isArray(logs)) {
    return res.status(400).json({ error: 'Logs must be an array' });
  }

  logs.forEach(log => logBatcher.addLog(log));
  
  res.json({ 
    received: logs.length, 
    status: 'queued for processing' 
  });
});

app.get('/health', (req, res) => {
  const metrics = logBatcher.getMetrics();
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    metrics
  });
});

app.get('/health/compression', (req, res) => {
  const metrics = logBatcher.getMetrics();
  res.json({
    enabled: process.env.COMPRESSION_ENABLED !== 'false',
    algorithm: process.env.COMPRESSION_ALGORITHM || 'gzip',
    compressionRatio: metrics.compression.compressionRatio,
    bytesSaved: metrics.bytesSaved,
    status: 'operational'
  });
});

app.get('/metrics', async (req, res) => {
  const metrics = logBatcher.getMetrics();
  
  compressionRatioGauge.set(parseFloat(metrics.compression.compressionRatio) || 0);
  bytesTransmittedCounter.inc(metrics.bytesTransmitted);
  bytesSavedCounter.inc(metrics.bytesSaved);
  
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/stats', (req, res) => {
  const metrics = logBatcher.getMetrics();
  const bandwidthReduction = metrics.bytesTransmitted > 0 ? 
    ((metrics.bytesSaved / (metrics.bytesTransmitted + metrics.bytesSaved)) * 100).toFixed(2) : 0;
  
  res.json({
    ...metrics,
    bandwidthReduction: `${bandwidthReduction}%`
  });
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('Shutting down gracefully...');
  logBatcher.stop();
  process.exit(0);
});

app.listen(port, () => {
  console.log(`Log compression service running on port ${port}`);
  console.log(`Compression: ${process.env.COMPRESSION_ENABLED !== 'false' ? 'enabled' : 'disabled'}`);
});

module.exports = app;
