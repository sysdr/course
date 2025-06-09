import pytest
import json
import time
import threading
from datetime import datetime
import tempfile
import os
from unittest.mock import Mock, patch

# Import our components for testing
import sys
sys.path.append('src')

from schema_validator import SchemaValidator
from json_processor import JSONLogProcessor
from json_server import JSONLogServer
from json_client import JSONLogClient

class TestSchemaValidator:
    """
    Test the schema validation component.
    
    These tests ensure our quality control inspector (schema validator)
    correctly identifies valid and invalid log entries. Think of these
    tests as checking that our inspector can spot both perfect products
    and various types of defects.
    """
    
    def setup_method(self):
        """Set up test environment before each test method."""
        # Create a temporary directory for test schemas
        self.temp_dir = tempfile.mkdtemp()
        
        # Create a simple test schema
        test_schema = {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "required": ["timestamp", "level", "message"],
            "properties": {
                "timestamp": {"type": "string"},
                "level": {"type": "string", "enum": ["INFO", "WARN", "ERROR"]},
                "message": {"type": "string", "minLength": 1}
            }
        }
        
        # Write the test schema to a file
        schema_path = os.path.join(self.temp_dir, "test_schema.json")
        with open(schema_path, 'w') as f:
            json.dump(test_schema, f)
        
        # Initialize validator with our test schema directory
        self.validator = SchemaValidator(self.temp_dir)
    
    def test_valid_log_passes_validation(self):
        """Test that a properly formatted log passes validation."""
        valid_log = {
            "timestamp": "2024-01-15T10:30:00Z",
            "level": "INFO",
            "message": "User login successful"
        }
        
        is_valid, error_message = self.validator.validate_log(valid_log, "test_schema")
        
        assert is_valid == True
        assert error_message is None
        
        # Check that statistics were updated
        stats = self.validator.get_validation_stats()
        assert stats['valid_count'] >= 1
    
    def test_missing_required_field_fails_validation(self):
        """Test that logs missing required fields are rejected."""
        invalid_log = {
            "timestamp": "2024-01-15T10:30:00Z",
            "level": "INFO"
            # Missing required 'message' field
        }
        
        is_valid, error_message = self.validator.validate_log(invalid_log, "test_schema")
        
        assert is_valid == False
        assert error_message is not None
        assert "required" in error_message.lower()
    
    def test_invalid_enum_value_fails_validation(self):
        """Test that invalid enum values are rejected."""
        invalid_log = {
            "timestamp": "2024-01-15T10:30:00Z",
            "level": "INVALID_LEVEL",  # Not in the allowed enum values
            "message": "This should fail"
        }
        
        is_valid, error_message = self.validator.validate_log(invalid_log, "test_schema")
        
        assert is_valid == False
        assert error_message is not None
    
    def test_log_enrichment_adds_metadata(self):
        """Test that log enrichment adds system metadata."""
        original_log = {
            "timestamp": "2024-01-15T10:30:00Z",
            "level": "INFO",
            "message": "Test message"
        }
        
        enriched_log = self.validator.enrich_log(original_log)
        
        # Check that original fields are preserved
        assert enriched_log["timestamp"] == original_log["timestamp"]
        assert enriched_log["level"] == original_log["level"]
        assert enriched_log["message"] == original_log["message"]
        
        # Check that enrichment fields were added
        assert "processed_at" in enriched_log
        assert "validation_status" in enriched_log
        assert "metadata" in enriched_log
        assert enriched_log["validation_status"] == "passed"
    
    def test_validation_statistics_tracking(self):
        """Test that validation statistics are properly tracked."""
        # Start with fresh statistics
        initial_stats = self.validator.get_validation_stats()
        
        # Validate some logs
        valid_log = {"timestamp": "2024-01-15T10:30:00Z", "level": "INFO", "message": "Valid"}
        invalid_log = {"level": "INFO"}  # Missing required fields
        
        self.validator.validate_log(valid_log, "test_schema")
        self.validator.validate_log(invalid_log, "test_schema")
        
        # Check updated statistics
        final_stats = self.validator.get_validation_stats()
        
        assert final_stats['total_validated'] >= initial_stats['total_validated'] + 2
        assert final_stats['valid_count'] >= initial_stats['valid_count'] + 1
        assert final_stats['invalid_count'] >= initial_stats['invalid_count'] + 1


class TestJSONLogProcessor:
    """
    Test the JSON log processor component.
    
    These tests verify that our processing pipeline correctly handles
    log validation, enrichment, and routing. Think of testing a complete
    assembly line to ensure each step works correctly.
    """
    
    def setup_method(self):
        """Set up test environment before each test method."""
        self.processor = JSONLogProcessor(max_workers=2)
        
        # Create mock handlers to capture processed logs
        self.processed_logs = []
        self.error_logs = []
        
        def mock_output_handler(log_data):
            self.processed_logs.append(log_data)
        
        def mock_error_handler(log_data, error_message):
            self.error_logs.append((log_data, error_message))
        
        self.processor.add_output_handler(mock_output_handler)
        self.processor.add_error_handler(mock_error_handler)
        
        # Start the processor
        self.processor.start()
    
    def teardown_method(self):
        """Clean up after each test method."""
        self.processor.stop()
    
    def test_valid_json_log_processing(self):
        """Test that valid JSON logs are processed correctly."""
        valid_log_json = json.dumps({
            "timestamp": "2024-01-15T10:30:00Z",
            "level": "INFO",
            "service": "test-service",
            "message": "Test message"
        })
        
        # Submit the log for processing
        success = self.processor.submit_log(valid_log_json)
        assert success == True
        
        # Wait a moment for processing to complete
        time.sleep(0.1)
        
        # Check that the log was processed successfully
        assert len(self.processed_logs) >= 1
        processed_log = self.processed_logs[0]
        
        # Verify the log contains expected fields
        assert processed_log["level"] == "INFO"
        assert processed_log["message"] == "Test message"
        assert "processed_at" in processed_log  # Should be enriched
    
    def test_invalid_json_rejected(self):
        """Test that invalid JSON is properly rejected."""
        invalid_json = "{ this is not valid json }"
        
        # Submit the invalid JSON
        success = self.processor.submit_log(invalid_json)
        assert success == False
        
        # Wait a moment for error handling
        time.sleep(0.1)
        
        # Check that an error was recorded
        assert len(self.error_logs) >= 1
        error_data, error_message = self.error_logs[0]
        assert "json" in error_message.lower()
    
    def test_processor_statistics(self):
        """Test that processor statistics are correctly maintained."""
        initial_stats = self.processor.get_stats()
        
        # Process some logs
        valid_log = json.dumps({"timestamp": "2024-01-15T10:30:00Z", "level": "INFO", "service": "test", "message": "Valid"})
        invalid_json = "invalid json"
        
        self.processor.submit_log(valid_log)
        self.processor.submit_log(invalid_json)
        
        # Wait for processing
        time.sleep(0.2)
        
        # Check updated statistics
        final_stats = self.processor.get_stats()
        
        assert final_stats['processor_stats']['logs_received'] >= initial_stats['processor_stats']['logs_received'] + 2


class TestIntegration:
    """
    Integration tests that verify the complete system works together.
    
    These tests simulate real-world scenarios where clients send logs
    to servers, ensuring the entire pipeline functions correctly.
    Think of this as testing the entire factory from raw materials
    to finished products.
    """
    
    def setup_method(self):
        """Set up a complete test environment with server and client."""
        # Use a non-standard port to avoid conflicts
        self.test_port = 9999
        
        # Create and start the server in a separate thread
        self.server = JSONLogServer(host="localhost", port=self.test_port)
        self.server_thread = threading.Thread(target=self.server.start, daemon=True)
        self.server_thread.start()
        
        # Give the server time to start
        time.sleep(0.5)
        
        # Create a client
        self.client = JSONLogClient(server_host="localhost", server_port=self.test_port)
    
    def teardown_method(self):
        """Clean up test environment."""
        if hasattr(self, 'client'):
            self.client.disconnect()
        
        if hasattr(self, 'server'):
            self.server.stop()
    
    def test_client_server_communication(self):
        """Test that client can successfully send logs to server."""
        # Connect the client
        connection_success = self.client.connect()
        assert connection_success == True
        
        # Generate and send a test log
        test_log = self.client.generate_sample_log()
        send_success = self.client.send_log(test_log)
        assert send_success == True
        
        # Wait for processing
        time.sleep(0.5)
        
        # Check client statistics
        client_stats = self.client.get_stats()
        assert client_stats['logs_sent'] >= 1
        
        # Check server statistics
        server_stats = self.server.get_stats()
        assert server_stats['processor_stats']['logs_received'] >= 1
    
    def test_batch_log_sending(self):
        """Test sending multiple logs in a batch."""
        # Connect the client
        assert self.client.connect() == True
        
        # Send a batch of logs
        batch_size = 5
        sent_count = self.client.send_batch_logs(batch_size, delay_ms=50)
        
        assert sent_count == batch_size
        
        # Wait for all logs to be processed
        time.sleep(1.0)
        
        # Verify statistics
        client_stats = self.client.get_stats()
        server_stats = self.server.get_stats()
        
        assert client_stats['logs_sent'] >= batch_size
        assert server_stats['processor_stats']['logs_received'] >= batch_size
    
    def test_invalid_log_handling(self):
        """Test that invalid logs are properly handled end-to-end."""
        # Connect the client
        assert self.client.connect() == True
        
        # Create an invalid log (missing required fields)
        invalid_log = {
            "level": "INFO"
            # Missing required timestamp, service, and message fields
        }
        
        # Send the invalid log
        send_success = self.client.send_log(invalid_log)
        assert send_success == True  # Sending should succeed
        
        # Wait for processing
        time.sleep(0.5)
        
        # Check that the server processed it (even though it was invalid)
        server_stats = self.server.get_stats()
        assert server_stats['processor_stats']['logs_received'] >= 1
        
        # The validation statistics should show rejected logs
        validation_stats = server_stats['validation_stats']
        assert validation_stats['invalid_count'] >= 1


# Test runner function that executes all tests
def run_all_tests():
    """
    Run the complete test suite.
    
    This function demonstrates how to execute all tests and interpret
    the results. In a real development environment, you would typically
    use pytest directly from the command line.
    """
    print("Running JSON Log Processing System Tests...")
    print("=" * 50)
    
    # Run pytest programmatically
    import subprocess
    import sys
    
    try:
        # Run pytest with verbose output
        result = subprocess.run([
            sys.executable, "-m", "pytest", 
            __file__, 
            "-v", 
            "--tb=short"
        ], capture_output=True, text=True)
        
        print("STDOUT:")
        print(result.stdout)
        
        if result.stderr:
            print("STDERR:")
            print(result.stderr)
        
        print(f"\nTest execution completed with return code: {result.returncode}")
        
        if result.returncode == 0:
            print("✅ All tests passed!")
        else:
            print("❌ Some tests failed. Check the output above for details.")
            
        return result.returncode == 0
        
    except Exception as e:
        print(f"Error running tests: {e}")
        return False


if __name__ == "__main__":
    run_all_tests()