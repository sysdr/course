import unittest
import sys
import os
import json

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

from log_processor import ProtobufLogProcessor

class TestProtobufSystem(unittest.TestCase):
    """Comprehensive test suite for Protocol Buffers system"""
    
    def setUp(self):
        """Initialize test environment"""
        self.processor = ProtobufLogProcessor()
        self.sample_log = {
            'timestamp': '2025-05-27T10:30:00.123Z',
            'level': 'INFO',
            'service': 'user-authentication-service',
            'message': 'User authentication successful with JWT validation',
            'request_id': 'req_12345678_9abc',
            'response_time_ms': 145,
            'status_code': 200,
            'user_context': {
                'user_id': 'user_550e8400-e29b-41d4',
                'session_id': 'session_75842',
                'ip_address': '192.168.1.100',
                'user_agent': 'Mozilla/5.0 (compatible; ServiceClient/2.1.0)'
            },
            'tags': ['auth', 'jwt', 'success', 'production']
        }
    
    def test_complete_serialization_cycle(self):
        """Test full serialize/deserialize cycle maintains data integrity"""
        logs = [self.sample_log]
        
        binary_data = self.processor.serialize_to_protobuf(logs)
        self.assertIsInstance(binary_data, bytes)
        self.assertGreater(len(binary_data), 0)
        
        restored_logs = self.processor.deserialize_from_protobuf(binary_data)
        
        self.assertEqual(len(restored_logs), 1)
        restored = restored_logs[0]
        
        self.assertEqual(restored['timestamp'], self.sample_log['timestamp'])
        self.assertEqual(restored['level'], self.sample_log['level'])
        self.assertEqual(restored['service'], self.sample_log['service'])
        self.assertEqual(restored['message'], self.sample_log['message'])
        self.assertEqual(restored['user_context']['user_id'], 
                        self.sample_log['user_context']['user_id'])
        self.assertEqual(set(restored['tags']), set(self.sample_log['tags']))
    
    def test_batch_processing(self):
        """Test processing multiple log entries in a batch"""
        logs = [self.sample_log.copy() for _ in range(100)]
        
        for i, log in enumerate(logs):
            log['request_id'] = f'req_{i:03d}'
            log['response_time_ms'] = 100 + i
        
        binary_data = self.processor.serialize_to_protobuf(logs)
        deserialized_logs = self.processor.deserialize_from_protobuf(binary_data)
        
        self.assertEqual(len(deserialized_logs), 100)
        self.assertEqual(deserialized_logs[50]['request_id'], 'req_050')
        self.assertEqual(deserialized_logs[50]['response_time_ms'], 150)
    
    def test_compression_effectiveness(self):
        """Test that protobuf provides significant compression vs JSON"""
        logs = [self.sample_log.copy() for _ in range(1000)]
        
        json_data = json.dumps(logs)
        json_size = len(json_data.encode('utf-8'))
        
        protobuf_data = self.processor.serialize_to_protobuf(logs)
        protobuf_size = len(protobuf_data)
        
        self.assertLess(protobuf_size, json_size)
        compression_ratio = json_size / protobuf_size
        self.assertGreater(compression_ratio, 2.0)
        
        print(f"\n📊 Compression Test Results:")
        print(f"   JSON size: {json_size:,} bytes")
        print(f"   Protobuf size: {protobuf_size:,} bytes")
        print(f"   Compression ratio: {compression_ratio:.2f}x smaller")

if __name__ == '__main__':
    unittest.main(verbosity=2)
