#!/usr/bin/env python3
"""
Comprehensive Test Suite for Compatibility Layer
Tests all components individually and as an integrated system
"""

import unittest
import sys
import os
import json
from datetime import datetime

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from detectors.format_detector import FormatDetector
from adapters.syslog_adapter import SyslogAdapter
from adapters.journald_adapter import JournaldAdapter
from validators.schema_validator import SchemaValidator
from formatters.unified_formatter import UnifiedFormatter
from compatibility_processor import CompatibilityProcessor

class TestFormatDetector(unittest.TestCase):
    """Test format detection functionality"""
    
    def setUp(self):
        self.detector = FormatDetector()
    
    def test_syslog_detection(self):
        """Test syslog format detection"""
        syslog_line = "<34>Oct 11 22:14:15 mymachine su: 'su root' failed"
        result = self.detector.detect_format(syslog_line)
        
        self.assertEqual(result['format'], 'syslog')
        self.assertGreater(result['confidence'], 0.5)
    
    def test_journald_detection(self):
        """Test journald format detection"""
        journald_line = "__REALTIME_TIMESTAMP=1697058855123456\nMESSAGE=Test message\nPRIORITY=6"
        result = self.detector.detect_format(journald_line)
        
        self.assertEqual(result['format'], 'journald')
        self.assertGreater(result['confidence'], 0.5)
    
    def test_json_detection(self):
        """Test JSON format detection"""
        json_line = '{"timestamp": "2023-10-11T22:14:15Z", "level": "INFO", "message": "Test"}'
        result = self.detector.detect_format(json_line)
        
        self.assertEqual(result['format'], 'json')
        self.assertGreater(result['confidence'], 0.5)
    
    def test_batch_detection(self):
        """Test batch format detection"""
        lines = [
            "<34>Oct 11 22:14:15 test syslog message",
            "__REALTIME_TIMESTAMP=123456\nMESSAGE=journald message",
            '{"timestamp": "2023-10-11T22:14:15Z", "message": "json message"}'
        ]
        
        result = self.detector.batch_detect(lines)
        
        self.assertEqual(result['total_lines'], 3)
        self.assertIn('syslog', result['format_distribution'])
        self.assertIn('journald', result['format_distribution'])
        self.assertIn('json', result['format_distribution'])

class TestSyslogAdapter(unittest.TestCase):
    """Test syslog adapter functionality"""
    
    def setUp(self):
        self.adapter = SyslogAdapter()
    
    def test_rfc3164_parsing(self):
        """Test RFC 3164 syslog parsing"""
        log_line = "<34>Oct 11 22:14:15 mymachine su: 'su root' failed for lonvick on /dev/pts/8"
        result = self.adapter.parse(log_line)
        
        self.assertIsNotNone(result)
        self.assertEqual(result['level'], 'CRITICAL')
        self.assertEqual(result['facility'], 'auth')
        self.assertEqual(result['hostname'], 'mymachine')
        self.assertIn("'su root' failed", result['message'])
        self.assertEqual(result['source_format'], 'syslog_rfc3164')
    
    def test_priority_decoding(self):
        """Test syslog priority decoding"""
        facility, severity = self.adapter._decode_priority(34)
        self.assertEqual(facility, 4)  # auth
        self.assertEqual(severity, 2)  # critical
    
    def test_batch_parsing(self):
        """Test batch syslog parsing"""
        lines = [
            "<34>Oct 11 22:14:15 server1 auth: login failed",
            "<85>Oct 11 22:14:16 server1 cron: job completed",
            "<166>Oct 11 22:14:17 server1 mail: delivery failed"
        ]
        
        results = self.adapter.batch_parse(lines)
        
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0]['facility'], 'auth')
        self.assertEqual(results[1]['facility'], 'cron')
        self.assertEqual(results[2]['facility'], 'lpr')

class TestJournaldAdapter(unittest.TestCase):
    """Test journald adapter functionality"""
    
    def setUp(self):
        self.adapter = JournaldAdapter()
    
    def test_keyvalue_parsing(self):
        """Test journald key=value parsing"""
        log_line = "__REALTIME_TIMESTAMP=1697058855123456\nMESSAGE=Test message\nPRIORITY=6\n_PID=1234"
        result = self.adapter.parse(log_line)
        
        self.assertIsNotNone(result)
        self.assertEqual(result['level'], 'INFO')
        self.assertEqual(result['message'], 'Test message')
        self.assertEqual(result['process_id'], '1234')
        self.assertEqual(result['source_format'], 'journald_keyvalue')
    
    def test_json_parsing(self):
        """Test journald JSON parsing"""
        log_data = {
            "__REALTIME_TIMESTAMP": "1697058855123456",
            "MESSAGE": "JSON test message",
            "PRIORITY": "4",
            "_PID": "5678"
        }
        json_line = json.dumps(log_data)
        result = self.adapter.parse(json_line)
        
        self.assertIsNotNone(result)
        self.assertEqual(result['level'], 'WARNING')
        self.assertEqual(result['message'], 'JSON test message')
        self.assertEqual(result['process_id'], '5678')
    
    def test_timestamp_extraction(self):
        """Test journald timestamp extraction"""
        data = {"__REALTIME_TIMESTAMP": "1697058855123456"}
        timestamp = self.adapter._extract_timestamp(data)
        
        # Should be valid ISO format
        datetime.fromisoformat(timestamp.replace('Z', '+00:00'))

class TestSchemaValidator(unittest.TestCase):
    """Test schema validation functionality"""
    
    def setUp(self):
        self.validator = SchemaValidator()
    
    def test_valid_entry(self):
        """Test validation of valid log entry"""
        entry = {
            'timestamp': '2023-10-11T22:14:15+00:00',
            'level': 'ERROR',
            'message': 'Test error message',
            'source_format': 'syslog',
            'facility': 'auth'
        }
        
        result = self.validator.validate(entry)
        
        self.assertTrue(result['valid'])
        self.assertEqual(len(result['errors']), 0)
        self.assertIsNotNone(result['entry'])
    
    def test_missing_required_field(self):
        """Test validation with missing required field"""
        entry = {
            'level': 'ERROR',
            'message': 'Test message',
            'source_format': 'syslog'
            # Missing timestamp
        }
        
        result = self.validator.validate(entry)
        
        self.assertFalse(result['valid'])
        self.assertIn('timestamp', str(result['errors']))
    
    def test_level_normalization(self):
        """Test log level normalization"""
        entry = {
            'timestamp': '2023-10-11T22:14:15+00:00',
            'level': 'EMERGENCY',  # Should be normalized to CRITICAL
            'message': 'Emergency message',
            'source_format': 'syslog'
        }
        
        result = self.validator.validate(entry)
        
        self.assertTrue(result['valid'])
        self.assertEqual(result['entry']['level'], 'CRITICAL')
    
    def test_batch_validation(self):
        """Test batch validation"""
        entries = [
            {
                'timestamp': '2023-10-11T22:14:15+00:00',
                'level': 'INFO',
                'message': 'Valid message 1',
                'source_format': 'syslog'
            },
            {
                'timestamp': '2023-10-11T22:14:16+00:00',
                'level': 'ERROR',
                'message': 'Valid message 2',
                'source_format': 'journald'
            },
            {
                # Invalid entry - missing timestamp
                'level': 'WARNING',
                'message': 'Invalid message',
                'source_format': 'syslog'
            }
        ]
        
        result = self.validator.batch_validate(entries)
        
        self.assertEqual(result['total_entries'], 3)
        self.assertEqual(result['valid_entries'], 2)
        self.assertEqual(result['invalid_entries'], 1)

class TestUnifiedFormatter(unittest.TestCase):
    """Test unified output formatter"""
    
    def setUp(self):
        self.formatter = UnifiedFormatter()
    
    def test_json_formatting(self):
        """Test JSON output formatting"""
        entry = {
            'timestamp': '2023-10-11T22:14:15+00:00',
            'level': 'ERROR',
            'message': 'Test message',
            'source_format': 'syslog',
            'facility': 'auth'
        }
        
        result = self.formatter.format_entry(entry, 'json')
        
        # Should be valid JSON
        parsed = json.loads(result)
        self.assertEqual(parsed['level'], 'ERROR')
        self.assertEqual(parsed['message'], 'Test message')
    
    def test_structured_formatting(self):
        """Test structured text formatting"""
        entry = {
            'timestamp': '2023-10-11T22:14:15+00:00',
            'level': 'INFO',
            'message': 'Test message',
            'source_format': 'syslog',
            'hostname': 'testhost'
        }
        
        result = self.formatter.format_entry(entry, 'structured')
        
        self.assertIn('[2023-10-11T22:14:15+00:00]', result)
        self.assertIn('INFO:', result)
        self.assertIn('Test message', result)
        self.assertIn('host=testhost', result)
    
    def test_simple_formatting(self):
        """Test simple text formatting"""
        entry = {
            'timestamp': '2023-10-11T22:14:15+00:00',
            'level': 'WARNING',
            'message': 'Simple test message',
            'source_format': 'journald'
        }
        
        result = self.formatter.format_entry(entry, 'simple')
        
        self.assertIn('[WARNING]', result)
        self.assertIn('Simple test message', result)

class TestCompatibilityProcessor(unittest.TestCase):
    """Test the main compatibility processor"""
    
    def setUp(self):
        self.processor = CompatibilityProcessor()
    
    def test_end_to_end_processing(self):
        """Test complete end-to-end processing"""
        log_lines = [
            "<34>Oct 11 22:14:15 testhost su: authentication failed",
            "__REALTIME_TIMESTAMP=1697058855123456\nMESSAGE=Service started\nPRIORITY=6",
            '{"timestamp": "2023-10-11T22:14:17Z", "level": "INFO", "message": "JSON log"}'
        ]
        
        results = self.processor.process_log_stream(log_lines)
        
        # Check that processing completed
        self.assertIn('processing_summary', results)
        self.assertGreater(results['processing_summary']['successfully_parsed'], 0)
        self.assertGreater(len(results['formatted_output']), 0)
    
    def test_mixed_format_processing(self):
        """Test processing of mixed log formats"""
        log_lines = [
            "<85>Oct 11 22:14:15 server cron: job completed",
            "__REALTIME_TIMESTAMP=1697058856123456\nMESSAGE=User logged in\nPRIORITY=6"
        ]
        
        results = self.processor.process_log_stream(log_lines, 'json')
        
        # Should handle both formats
        summary = results['processing_summary']
        self.assertEqual(summary['total_input_lines'], 2)
        self.assertGreater(summary['successfully_parsed'], 0)

def run_all_tests():
    """Run all tests and provide summary"""
    print("🧪 Running Compatibility Layer Test Suite")
    print("=" * 50)
    
    # Create test suite
    test_classes = [
        TestFormatDetector,
        TestSyslogAdapter, 
        TestJournaldAdapter,
        TestSchemaValidator,
        TestUnifiedFormatter,
        TestCompatibilityProcessor
    ]
    
    suite = unittest.TestSuite()
    for test_class in test_classes:
        tests = unittest.TestLoader().loadTestsFromTestCase(test_class)
        suite.addTests(tests)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 50)
    print(f"📊 Test Summary:")
    print(f"   Tests run: {result.testsRun}")
    print(f"   Failures: {len(result.failures)}")
    print(f"   Errors: {len(result.errors)}")
    print(f"   Success rate: {((result.testsRun - len(result.failures) - len(result.errors)) / result.testsRun * 100):.1f}%")
    
    if result.failures:
        print(f"\n❌ Failures:")
        for test, traceback in result.failures:
            print(f"   - {test}: {traceback.split('AssertionError:')[-1].strip()}")
    
    if result.errors:
        print(f"\n💥 Errors:")
        for test, traceback in result.errors:
            print(f"   - {test}: {traceback.split('Error:')[-1].strip()}")
    
    success = len(result.failures) == 0 and len(result.errors) == 0
    return success

if __name__ == '__main__':
    success = run_all_tests()
    exit(0 if success else 1)
