#!/usr/bin/env python3
# test_parser.py - Unit tests for the log parser component

import unittest
import os
import json
import tempfile
import shutil
import sys
import re

# Assuming parser.py is in the parent directory
sys.path.append('..')
from parser.parser import parse_log, process_logs

class TestParser(unittest.TestCase):
    """Test cases for the log parser component"""
    
    def setUp(self):
        """Set up test environment"""
        # Create temporary directories for testing
        self.test_dir = tempfile.mkdtemp()
        self.input_dir = os.path.join(self.test_dir, 'input')
        self.output_dir = os.path.join(self.test_dir, 'parsed')
        
        # Create directories
        os.makedirs(self.input_dir, exist_ok=True)
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Sample logs for testing
        self.apache_log = '192.168.1.1 - - [25/Sep/2023:14:23:11 +0000] "GET /index.html HTTP/1.1" 200 1234 "-" "Mozilla/5.0"'
        self.json_log = '{"timestamp": "2023-09-25T14:23:11", "level": "INFO", "message": "Test message"}'
        self.syslog = 'Sep 25 14:23:11 server app[123]: INFO Test message'
    
    def tearDown(self):
        """Clean up after tests"""
        # Remove the temporary directory
        shutil.rmtree(self.test_dir)
    
    def test_parse_apache_log(self):
        """Test parsing Apache format logs"""
        # Parse the Apache log
        parsed = parse_log(self.apache_log, 'apache')
        
        # Check that it's a dictionary
        self.assertIsInstance(parsed, dict, "Parsed log should be a dictionary")
        
        # Check required fields
        self.assertIn('ip', parsed, "Missing 'ip' field")
        self.assertIn('timestamp', parsed, "Missing 'timestamp' field")
        self.assertIn('method', parsed, "Missing 'method' field")
        self.assertIn('path', parsed, "Missing 'path' field")
        self.assertIn('status', parsed, "Missing 'status' field")
        self.assertIn('size', parsed, "Missing 'size' field")
        self.assertIn('user_agent', parsed, "Missing 'user_agent' field")
        
        # Check field values
        self.assertEqual(parsed['ip'], '192.168.1.1', "Incorrect IP value")
        self.assertEqual(parsed['method'], 'GET', "Incorrect method value")
        self.assertEqual(parsed['path'], '/index.html', "Incorrect path value")
        self.assertEqual(parsed['status'], 200, "Incorrect status value")
        self.assertEqual(parsed['size'], 1234, "Incorrect size value")
        self.assertEqual(parsed['user_agent'], 'Mozilla/5.0', "Incorrect user agent value")
    
    def test_parse_json_log(self):
        """Test parsing JSON format logs"""
        # Parse the JSON log
        parsed = parse_log(self.json_log, 'json')
        
        # Check that it's a dictionary
        self.assertIsInstance(parsed, dict, "Parsed log should be a dictionary")
        
        # For JSON logs, the parser should just return the parsed JSON
        expected = json.loads(self.json_log)
        self.assertEqual(parsed, expected, "JSON parsing incorrect")
    
    def test_parse_syslog(self):
        """Test parsing syslog format logs"""
        # Parse the syslog
        parsed = parse_log(self.syslog, 'syslog')
        
        # Check that it's a dictionary
        self.assertIsInstance(parsed, dict, "Parsed log should be a dictionary")
        
        # Check required fields
        self.assertIn('timestamp', parsed, "Missing 'timestamp' field")
        self.assertIn('host', parsed, "Missing 'host' field")
        self.assertIn('program', parsed, "Missing 'program' field")
        self.assertIn('pid', parsed, "Missing 'pid' field")
        self.assertIn('level', parsed, "Missing 'level' field")
        self.assertIn('message', parsed, "Missing 'message' field")
        
        # Check field values
        self.assertEqual(parsed['host'], 'server', "Incorrect host value")
        self.assertEqual(parsed['program'], 'app', "Incorrect program value")
        self.assertEqual(parsed['pid'], '123', "Incorrect pid value")
        self.assertEqual(parsed['level'], 'INFO', "Incorrect level value")
        self.assertEqual(parsed['message'], 'Test message', "Incorrect message value")
    
    def test_parse_invalid_format(self):
        """Test parsing with invalid format type"""
        # This should raise a ValueError
        with self.assertRaises(ValueError):
            parse_log(self.apache_log, 'invalid_format')
    
    def test_parse_malformed_log(self):
        """Test parsing malformed logs"""
        # Malformed Apache log
        malformed_apache = 'This is not an Apache log'
        
        # This should either return None or raise a specific error
        try:
            result = parse_log(malformed_apache, 'apache')
            self.assertIsNone(result, "Malformed log should return None")
        except Exception as e:
            # If it raises an exception, it should be a specific parsing error
            self.assertIsInstance(e, (ValueError, re.error), 
                                 f"Unexpected exception type: {type(e).__name__}")
        
        # Malformed JSON log
        malformed_json = 'This is not JSON'
        
        # This should raise a JSONDecodeError
        with self.assertRaises(json.JSONDecodeError):
            parse_log(malformed_json, 'json')
    
    def test_process_logs_basic(self):
        """Test basic functionality of process_logs"""
        # Create test input file
        input_file = os.path.join(self.input_dir, 'test_apache.log')
        with open(input_file, 'w') as f:
            f.write(f"{self.apache_log}\n{self.apache_log}\n")
        
        # Process the logs
        process_logs(self.input_dir, self.output_dir, 'apache', max_iterations=1)
        
        # Check that output files were created
        output_files = os.listdir(self.output_dir)
        self.assertTrue(len(output_files) > 0, "No output files created")
        
        # Check the content of the output file
        with open(os.path.join(self.output_dir, output_files[0]), 'r') as f:
            parsed_logs = [json.loads(line) for line in f]
        
        # Check that we have the expected number of logs
        self.assertEqual(len(parsed_logs), 2, f"Expected 2 parsed logs, got {len(parsed_logs)}")
        
        # Check the content of the parsed logs
        for log in parsed_logs:
            self.assertEqual(log['method'], 'GET', "Incorrect method in parsed log")
            self.assertEqual(log['path'], '/index.html', "Incorrect path in parsed log")
    
    def test_process_logs_multiple_formats(self):
        """Test processing logs with multiple formats"""
        # Create test input files
        apache_file = os.path.join(self.input_dir, 'test_apache.log')
        with open(apache_file, 'w') as f:
            f.write(f"{self.apache_log}\n")
        
        json_file = os.path.join(self.input_dir, 'test_json.log')
        with open(json_file, 'w') as f:
            f.write(f"{self.json_log}\n")
        
        # Process Apache logs
        process_logs(self.input_dir, self.output_dir, 'apache', file_pattern='*apache.log', max_iterations=1)
        
        # Process JSON logs
        json_output_dir = os.path.join(self.test_dir, 'parsed_json')
        os.makedirs(json_output_dir, exist_ok=True)
        process_logs(self.input_dir, json_output_dir, 'json', file_pattern='*json.log', max_iterations=1)
        
        # Check Apache output
        apache_output_files = os.listdir(self.output_dir)
        self.assertTrue(len(apache_output_files) > 0, "No Apache output files created")
        
        # Check JSON output
        json_output_files = os.listdir(json_output_dir)
        self.assertTrue(len(json_output_files) > 0, "No JSON output files created")
        
        # Verify Apache parsed content
        with open(os.path.join(self.output_dir, apache_output_files[0]), 'r') as f:
            apache_parsed = json.loads(f.read().strip())
        
        self.assertEqual(apache_parsed['method'], 'GET', "Incorrect method in parsed Apache log")
        
        # Verify JSON parsed content
        with open(os.path.join(json_output_dir, json_output_files[0]), 'r') as f:
            json_parsed = json.loads(f.read().strip())
        
        self.assertEqual(json_parsed['level'], 'INFO', "Incorrect level in parsed JSON log")
    
    def test_process_logs_handles_errors(self):
        """Test that process_logs handles errors gracefully"""
        # Create test input file with mixture of valid and invalid logs
        mixed_file = os.path.join(self.input_dir, 'mixed_logs.log')
        with open(mixed_file, 'w') as f:
            f.write(f"{self.apache_log}\nThis is not a valid log\n{self.apache_log}\n")
        
        # Process the logs
        process_logs(self.input_dir, self.output_dir, 'apache', max_iterations=1)
        
        # Check that output files were created
        output_files = os.listdir(self.output_dir)
        self.assertTrue(len(output_files) > 0, "No output files created")
        
        # Check the content of the output file
        with open(os.path.join(self.output_dir, output_files[0]), 'r') as f:
            content = f.read()
            parsed_logs = [json.loads(line) for line in content.strip().split('\n') if line.strip()]
        
        # We should have 2 valid logs (the invalid one should be skipped)
        self.assertEqual(len(parsed_logs), 2, 
                        f"Expected 2 parsed logs (skipping invalid), got {len(parsed_logs)}")


if __name__ == '__main__':
    unittest.main()