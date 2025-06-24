"""
Tests for metadata collectors.
"""

import unittest
from unittest.mock import patch, MagicMock
import sys
import os

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.collectors.system_collector import SystemCollector
from src.collectors.performance_collector import PerformanceCollector
from src.collectors.env_collector import EnvironmentCollector


class TestSystemCollector(unittest.TestCase):
    """Test system metadata collector."""
    
    def setUp(self):
        self.collector = SystemCollector(cache_ttl=1)
    
    def test_collect_returns_dict(self):
        """Test that collect returns a dictionary."""
        result = self.collector.collect()
        self.assertIsInstance(result, dict)
    
    def test_required_fields_present(self):
        """Test that required fields are present in collected data."""
        result = self.collector.collect()
        required_fields = ['hostname', 'platform', 'service_name']
        for field in required_fields:
            self.assertIn(field, result)
    
    @patch('socket.gethostname')
    def test_hostname_fallback(self, mock_hostname):
        """Test hostname fallback when socket.gethostname fails."""
        mock_hostname.side_effect = Exception("Network error")
        with patch.dict(os.environ, {'HOSTNAME': 'test-host'}):
            result = self.collector.collect()
            self.assertEqual(result['hostname'], 'test-host')


class TestPerformanceCollector(unittest.TestCase):
    """Test performance metrics collector."""
    
    def setUp(self):
        self.collector = PerformanceCollector(cache_duration=0.1)
    
    def test_collect_returns_dict(self):
        """Test that collect returns a dictionary."""
        result = self.collector.collect()
        self.assertIsInstance(result, dict)
    
    def test_performance_fields_present(self):
        """Test that performance fields are present."""
        result = self.collector.collect()
        expected_fields = ['cpu_percent', 'memory_percent', 'disk_percent']
        for field in expected_fields:
            self.assertIn(field, result)
    
    @patch('psutil.cpu_percent')
    def test_handles_psutil_errors(self, mock_cpu):
        """Test graceful handling of psutil errors."""
        mock_cpu.side_effect = Exception("Permission denied")
        result = self.collector.collect()
        self.assertIn('error', result)


class TestEnvironmentCollector(unittest.TestCase):
    """Test environment metadata collector."""
    
    def setUp(self):
        self.collector = EnvironmentCollector()
    
    def test_collect_returns_dict(self):
        """Test that collect returns a dictionary."""
        result = self.collector.collect()
        self.assertIsInstance(result, dict)
    
    def test_filters_sensitive_variables(self):
        """Test that sensitive environment variables are filtered out."""
        with patch.dict(os.environ, {
            'APP_NAME': 'test-app',
            'SECRET_KEY': 'secret-value',
            'PASSWORD': 'password-value'
        }):
            result = self.collector.collect()
            env_vars = result.get('environment_variables', {})
            self.assertIn('APP_NAME', env_vars)
            self.assertNotIn('SECRET_KEY', env_vars)
            self.assertNotIn('PASSWORD', env_vars)


if __name__ == '__main__':
    unittest.main()
