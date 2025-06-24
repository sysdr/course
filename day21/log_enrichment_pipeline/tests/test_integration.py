"""
Integration tests for the complete enrichment pipeline.
"""

import unittest
import sys
import os
import json

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.pipeline import LogEnrichmentPipeline


class TestLogEnrichmentPipeline(unittest.TestCase):
    """Test the complete log enrichment pipeline."""
    
    def setUp(self):
        self.pipeline = LogEnrichmentPipeline()
    
    def test_enrich_simple_log(self):
        """Test enriching a simple log message."""
        raw_log = "INFO: User login successful"
        result = self.pipeline.enrich_log(raw_log, "test-app")
        
        # Verify basic structure
        self.assertIsInstance(result, dict)
        self.assertEqual(result['message'], raw_log)
        self.assertEqual(result['level'], 'INFO')
        self.assertEqual(result['source'], 'test-app')
        self.assertIn('hostname', result)
        self.assertIn('enriched_at', result)
    
    def test_enrich_error_log_includes_performance(self):
        """Test that ERROR logs include performance data."""
        raw_log = "ERROR: Database connection failed"
        result = self.pipeline.enrich_log(raw_log, "db-service")
        
        # Error logs should include performance metrics
        self.assertEqual(result['level'], 'ERROR')
        self.assertIn('cpu_percent', result)
        self.assertIn('memory_percent', result)
    
    def test_enrich_malformed_input(self):
        """Test handling of malformed input."""
        result = self.pipeline.enrich_log("", "test")
        
        # Should still return a valid structure
        self.assertIsInstance(result, dict)
        self.assertIn('timestamp', result)
    
    def test_pipeline_statistics(self):
        """Test pipeline statistics tracking."""
        # Process some logs
        self.pipeline.enrich_log("INFO: Test 1", "app1")
        self.pipeline.enrich_log("ERROR: Test 2", "app2")
        
        stats = self.pipeline.get_statistics()
        
        self.assertGreaterEqual(stats['processed_count'], 2)
        self.assertIn('success_rate', stats)
        self.assertIn('average_throughput', stats)
    
    def test_json_serialization(self):
        """Test that enriched logs can be serialized to JSON."""
        raw_log = "WARN: High memory usage detected"
        result = self.pipeline.enrich_log(raw_log, "monitor")
        
        # Should be JSON serializable
        json_str = json.dumps(result)
        parsed = json.loads(json_str)
        
        self.assertEqual(parsed['message'], raw_log)
        self.assertEqual(parsed['level'], 'WARN')


if __name__ == '__main__':
    unittest.main()
