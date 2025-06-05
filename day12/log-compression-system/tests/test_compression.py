import unittest
import json
import sys
import os

# Add the src directory to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    from src.compression import CompressionHandler
except ImportError:
    from compression import CompressionHandler

class TestCompression(unittest.TestCase):
    def test_gzip_compression(self):
        # Create test data
        test_data = json.dumps([{"message": "test log"} for _ in range(100)]).encode('utf-8')
        
        # Test compression
        compressor = CompressionHandler(algorithm='gzip', level=6)
        compressed_data, stats = compressor.compress(test_data)
        
        # Verify compression worked
        self.assertLess(len(compressed_data), len(test_data))
        self.assertGreater(stats['ratio'], 1.0)
        
        # Test decompression
        decompressed_data = compressor.decompress(compressed_data)
        self.assertEqual(decompressed_data, test_data)
        
    def test_zlib_compression(self):
        # Create test data
        test_data = json.dumps([{"message": "test log"} for _ in range(100)]).encode('utf-8')
        
        # Test compression
        compressor = CompressionHandler(algorithm='zlib', level=6)
        compressed_data, stats = compressor.compress(test_data)
        
        # Verify compression worked
        self.assertLess(len(compressed_data), len(test_data))
        self.assertGreater(stats['ratio'], 1.0)
        
        # Test decompression
        decompressed_data = compressor.decompress(compressed_data)
        self.assertEqual(decompressed_data, test_data)
        
    def test_empty_data(self):
        # Test compression of empty data
        compressor = CompressionHandler()
        compressed_data, stats = compressor.compress(b'')
        
        # Verify empty data handling
        self.assertEqual(compressed_data, b'')
        self.assertEqual(stats['original_size'], 0)
        self.assertEqual(stats['compressed_size'], 0)
        
    def test_invalid_algorithm(self):
        # Test invalid compression algorithm
        with self.assertRaises(ValueError):
            CompressionHandler(algorithm='invalid')
            
    def test_invalid_level(self):
        # Test invalid compression level
        with self.assertRaises(ValueError):
            CompressionHandler(level=0)
        with self.assertRaises(ValueError):
            CompressionHandler(level=10)

if __name__ == '__main__':
    unittest.main()
