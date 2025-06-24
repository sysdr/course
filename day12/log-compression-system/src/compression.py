import gzip
import zlib
import time
import logging

logger = logging.getLogger(__name__)

class CompressionHandler:
    def __init__(self, algorithm='gzip', level=6):
        """
        Initialize compression handler with specified algorithm and compression level.
        
        Args:
            algorithm (str): Compression algorithm ('gzip' or 'zlib')
            level (int): Compression level (1-9, where 9 is highest compression)
        """
        self.algorithm = algorithm
        self.level = level
        
        # Validate inputs
        if algorithm not in ['gzip', 'zlib']:
            raise ValueError(f"Unsupported compression algorithm: {algorithm}")
        
        if not (1 <= level <= 9):
            raise ValueError(f"Compression level must be between 1-9, got: {level}")
    
    def compress(self, data):
        """
        Compress the input data.
        
        Args:
            data (bytes): Data to compress
            
        Returns:
            tuple: (compressed_data, compression_stats)
        """
        if not data:
            return b'', {'original_size': 0, 'compressed_size': 0, 'ratio': 1.0, 'time_ms': 0}
        
        start_time = time.time()
        original_size = len(data)
        
        try:
            if self.algorithm == 'gzip':
                compressed_data = gzip.compress(data, compresslevel=self.level)
            else:  # zlib
                compressed_data = zlib.compress(data, level=self.level)
                
            elapsed_ms = (time.time() - start_time) * 1000
            compressed_size = len(compressed_data)
            
            # Calculate compression ratio
            ratio = original_size / compressed_size if compressed_size > 0 else 1.0
            
            stats = {
                'original_size': original_size,
                'compressed_size': compressed_size,
                'ratio': ratio,
                'time_ms': elapsed_ms
            }
            
            return compressed_data, stats
            
        except Exception as e:
            logger.error(f"Compression failed: {str(e)}")
            return data, {'error': str(e), 'original_size': original_size, 'compressed_size': original_size, 'ratio': 1.0}
    
    def decompress(self, data, is_compressed=True):
        """
        Decompress the input data if it's compressed.
        
        Args:
            data (bytes): Data to decompress
            is_compressed (bool): Whether the data is compressed
            
        Returns:
            bytes: Decompressed data
        """
        if not is_compressed or not data:
            return data
            
        try:
            if self.algorithm == 'gzip':
                return gzip.decompress(data)
            else:  # zlib
                return zlib.decompress(data)
                
        except Exception as e:
            logger.error(f"Decompression failed: {str(e)}")
            return data
