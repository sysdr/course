const zlib = require('zlib');
const { promisify } = require('util');

const gzip = promisify(zlib.gzip);
const gunzip = promisify(zlib.gunzip);

class CompressionService {
  constructor(config = {}) {
    this.algorithm = config.algorithm || 'gzip';
    this.level = config.level || 6;
    this.minSize = config.minSize || 1024;
    this.enabled = config.enabled !== false;
    this.metrics = {
      compressionRatio: 0,
      totalCompressed: 0,
      totalOriginal: 0,
      compressionTime: 0
    };
  }

  async compress(data) {
    if (!this.enabled || !data || data.length < this.minSize) {
      return { compressed: false, data, ratio: 0 };
    }

    const startTime = Date.now();
    const originalSize = Buffer.byteLength(data);
    
    try {
      const compressed = await gzip(data, { level: this.level });
      const compressedSize = compressed.length;
      const ratio = ((originalSize - compressedSize) / originalSize * 100).toFixed(2);
      
      this.updateMetrics(originalSize, compressedSize, Date.now() - startTime);
      
      return {
        compressed: true,
        data: compressed,
        originalSize,
        compressedSize,
        ratio: parseFloat(ratio)
      };
    } catch (error) {
      console.error('Compression failed:', error);
      return { compressed: false, data, ratio: 0, error: error.message };
    }
  }

  async decompress(compressedData) {
    try {
      return await gunzip(compressedData);
    } catch (error) {
      throw new Error(`Decompression failed: ${error.message}`);
    }
  }

  updateMetrics(originalSize, compressedSize, duration) {
    this.metrics.totalOriginal += originalSize;
    this.metrics.totalCompressed += compressedSize;
    this.metrics.compressionTime += duration;
    this.metrics.compressionRatio = ((this.metrics.totalOriginal - this.metrics.totalCompressed) / this.metrics.totalOriginal * 100).toFixed(2);
  }

  getMetrics() {
    return { ...this.metrics };
  }

  reset() {
    this.metrics = {
      compressionRatio: 0,
      totalCompressed: 0,
      totalOriginal: 0,
      compressionTime: 0
    };
  }
}

module.exports = CompressionService;
