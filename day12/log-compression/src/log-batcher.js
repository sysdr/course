const CompressionService = require('./compression-service');

class LogBatcher {
  constructor(config = {}) {
    this.batchSize = config.batchSize || 100;
    this.batchInterval = config.batchInterval || 5000;
    this.compressionService = new CompressionService(config.compression);
    this.buffer = [];
    this.timer = null;
    this.metrics = {
      batchesProcessed: 0,
      logsProcessed: 0,
      bytesTransmitted: 0,
      bytesSaved: 0
    };
  }

  addLog(log) {
    this.buffer.push({
      timestamp: Date.now(),
      level: log.level || 'info',
      message: log.message,
      source: log.source || 'unknown'
    });

    if (this.buffer.length >= this.batchSize) {
      this.processBatch();
    } else if (!this.timer) {
      this.timer = setTimeout(() => this.processBatch(), this.batchInterval);
    }
  }

  async processBatch() {
    if (this.buffer.length === 0) return;

    const logs = this.buffer.splice(0);
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    const batchData = JSON.stringify(logs);
    const result = await this.compressionService.compress(batchData);
    
    await this.transmit(result);
    
    this.metrics.batchesProcessed++;
    this.metrics.logsProcessed += logs.length;
    
    return result;
  }

  async transmit(compressedData) {
    // Simulate network transmission
    const transmissionSize = compressedData.compressed ? 
      compressedData.compressedSize : 
      Buffer.byteLength(compressedData.data);
    
    this.metrics.bytesTransmitted += transmissionSize;
    
    if (compressedData.compressed) {
      const saved = compressedData.originalSize - compressedData.compressedSize;
      this.metrics.bytesSaved += saved;
    }

    // Simulate network delay
    await new Promise(resolve => setTimeout(resolve, 10));
    
    console.log(`Transmitted batch: ${transmissionSize} bytes (${compressedData.compressed ? 'compressed' : 'uncompressed'})`);
    return { success: true, size: transmissionSize };
  }

  getMetrics() {
    return {
      ...this.metrics,
      compression: this.compressionService.getMetrics()
    };
  }

  stop() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    if (this.buffer.length > 0) {
      this.processBatch();
    }
  }
}

module.exports = LogBatcher;
