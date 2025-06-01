import json
import pytest
from datetime import datetime
from src.normalizer import LogNormalizer
from src.models.log_entry import LogEntry

class TestLogNormalizer:
    def setup_method(self):
        self.normalizer = LogNormalizer()
    
    def test_json_format_detection(self):
        json_log = b'{"timestamp": "2024-01-15T10:30:00", "level": "ERROR", "message": "Database connection failed"}'
        assert self.normalizer.detect_format(json_log) == 'json'
    
    def test_text_format_detection(self):
        text_log = b'2024-01-15 10:30:00 ERROR Database connection failed'
        assert self.normalizer.detect_format(text_log) == 'text'
    
    def test_json_normalization(self):
        json_log = b'{"timestamp": "2024-01-15T10:30:00", "level": "ERROR", "message": "Test error", "service": "api-gateway"}'
        result = self.normalizer.normalize(json_log)
        
        assert isinstance(result, LogEntry)
        assert result.level == 'ERROR'
        assert result.message == 'Test error'
        assert result.source == 'api-gateway'
    
    def test_text_normalization(self):
        text_log = b'2024-01-15 10:30:00 WARN Connection timeout detected'
        result = self.normalizer.normalize(text_log)
        
        assert isinstance(result, LogEntry)
        assert result.level == 'WARN'
        assert 'Connection timeout detected' in result.message
    
    def test_invalid_json_handling(self):
        invalid_json = b'{"incomplete": json data'
        # Should fall back to text handler
        result = self.normalizer.normalize(invalid_json)
        assert isinstance(result, LogEntry)
    
    def test_format_hint_override(self):
        data = b'Plain text that could be anything'
        result = self.normalizer.normalize(data, format_hint='text')
        assert isinstance(result, LogEntry)
        assert result.message == 'Plain text that could be anything'

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
