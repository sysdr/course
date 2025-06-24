#!/usr/bin/env python3
# test_integration.py - Integration tests for the log processing pipeline

import unittest
import os
import subprocess
import time
import shutil
import json
import tempfile
import sys
import threading
import queue

# Assuming component modules are in the parent directory
sys.path.append('..')
from generator.generator import generate_log, write_logs
from collector.collector import watch_file, collect_logs
from parser.parser import parse_log, process_logs as process_parser_logs
from storage.storage import store_log, create_index, process_logs as process_storage_logs
from query.query import search_by_pattern, search_by_index
from integration.pipeline import start_pipeline, stop_pipeline

class TestIntegration(unittest.TestCase):
    """Integration tests for the log processing pipeline"""
    
    def setUp(self):
        """Set up test environment"""
        # Create temporary directories for testing
        self.test_dir = tempfile.mkdtemp()
        
        # Set up directory structure
        self.logs_dir = os.path.join(self.test_dir, 'logs')
        self.collected_dir = os.path.join(self.test_dir, 'collected')
        self.parsed_dir = os.path.join(self.test_dir, 'parsed')
        self.storage_dir = os.path.join(self.test_dir, 'storage')
        
        # Create required directories
        os.makedirs(self.logs_dir, exist_ok=True)
        os.makedirs(self.collected_dir, exist_ok=True)
        os.makedirs(self.parsed_dir, exist_ok=True)
        os.makedirs(os.path.join(self.storage_dir, 'active'), exist_ok=True)
        os.makedirs(os.path.join(self.storage_dir, 'archive'), exist_ok=True)
        os.makedirs(os.path.join(self.storage_dir, 'index'), exist_ok=True)
        
        # Create config for the pipeline
        self.config = {
            'generator': {
                'format': 'apache',
                'rate': 5,
                'output': os.path.join(self.logs_dir, 'app.log')
            },
            'collector': {
                'source': os.path.join(self.logs_dir, 'app.log'),
                'output_dir': self.collected_dir,
                'interval': 1
            },
            'parser': {
                'input_dir': self.collected_dir,
                'output_dir': self.parsed_dir,
                'format': 'apache',
                'interval': 1
            },
            'storage': {
                'input_dir': self.parsed_dir,
                'storage_dir': self.storage_dir,
                'rotation_size': 10,  # Large enough to not trigger during tests
                'rotation_hours': 24,  # Long enough to not trigger during tests
                'interval': 1,
                'index_fields': ['level', 'status', 'method']
            }
        }
        
        # Save config to file
        self.config_file = os.path.join(self.test_dir, 'test_config.json')
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f)
    
    def tearDown(self):
        """Clean up after tests"""
        # Remove the temporary directory
        shutil.rmtree(self.test_dir)
    
    def test_component_connections(self):
        """Test that components work together properly"""
        # Generate a log file directly
        log_file = os.path.join(self.logs_dir, 'app.log')
        with open(log_file, 'w') as f:
            for _ in range(10):
                f.write(generate_log('apache') + '\n')
        
        # Run collector manually
        collector_stop = threading.Event()
        collector_thread = threading.Thread(
            target=collect_logs,
            args=(log_file, self.collected_dir, 1),
            kwargs={'stop_event': collector_stop}
        )
        collector_thread.daemon = True
        collector_thread.start()
        
        # Wait for collector to process
        time.sleep(2)
        
        # Check that logs were collected
        collected_files = os.listdir(self.collected_dir)
        self.assertTrue(len(collected_files) > 0, "No logs were collected")
        
        # Run parser manually
        parser_stop = threading.Event()
        parser_thread = threading.Thread(
            target=process_parser_logs,
            args=(self.collected_dir, self.parsed_dir, 'apache'),
            kwargs={'stop_event': parser_stop}
        )
        parser_thread.daemon = True
        parser_thread.start()
        
        # Wait for parser to process
        time.sleep(2)
        
        # Check that logs were parsed
        parsed_files = os.listdir(self.parsed_dir)
        self.assertTrue(len(parsed_files) > 0, "No logs were parsed")
        
        # Run storage manually
        storage_stop = threading.Event()
        storage_thread = threading.Thread(
            target=process_storage_logs,
            args=(self.parsed_dir, self.storage_dir),
            kwargs={
                'index_fields': ['level', 'status', 'method'],
                'stop_event': storage_stop
            }
        )
        storage_thread.daemon = True
        storage_thread.start()
        
        # Wait for storage to process
        time.sleep(2)
        
        # Check that logs were stored
        stored_files = os.listdir(os.path.join(self.storage_dir, 'active'))
        self.assertTrue(len(stored_files) > 0, "No logs were stored")
        
        # Check that indexes were created
        index_dir = os.path.join(self.storage_dir, 'index')
        self.assertTrue('method' in os.listdir(index_dir), "No method index created")
        self.assertTrue('status' in os.listdir(index_dir), "No status index created")
        
        # Run a query to test the entire pipeline
        results = search_by_pattern(self.storage_dir, 'GET')
        
        # Should find logs with GET method
        self.assertTrue(len(results) > 0, "Query found no results")
        
        # Clean up threads
        collector_stop.set()
        parser_stop.set()
        storage_stop.set()
        collector_thread.join(timeout=2)
        parser_thread.join(timeout=2)
        storage_thread.join(timeout=2)
    
    def test_full_pipeline_integration(self):
        """Test the full pipeline integration using the pipeline module"""
        # Start the pipeline with a custom config
        stop_event = threading.Event()
        
        # Message queue for communication
        message_queue = queue.Queue()
        
        # Start pipeline in a thread
        pipeline_thread = threading.Thread(
            target=start_pipeline,
            args=(self.config_file, stop_event, message_queue)
        )
        pipeline_thread.daemon = True
        pipeline_thread.start()
        
        # Wait for pipeline to start and process logs
        time.sleep(15)  # Allow enough time for logs to flow through the system
        
        # Check for successful component startup messages
        components = ['generator', 'collector', 'parser', 'storage']
        started_components = []
        
        # Check messages (non-blocking)
        while not message_queue.empty():
            message = message_queue.get_nowait()
            for component in components:
                if f"{component} started" in message.lower():
                    started_components.append(component)
        
        # Check that all components started
        for component in components:
            self.assertIn(component, started_components, f"{component} did not start")
        
        # Check that logs were generated
        self.assertTrue(os.path.exists(os.path.join(self.logs_dir, 'app.log')), 
                       "Log file not created")
        
        # Check that logs were collected
        collected_files = os.listdir(self.collected_dir)
        self.assertTrue(len(collected_files) > 0, "No logs were collected")
        
        # Check that logs were parsed
        parsed_files = os.listdir(self.parsed_dir)
        self.assertTrue(len(parsed_files) > 0, "No logs were parsed")
        
        # Check that logs were stored
        stored_files = os.listdir(os.path.join(self.storage_dir, 'active'))
        self.assertTrue(len(stored_files) > 0, "No logs were stored")
        
        # Check that indexes were created
        index_dir = os.path.join(self.storage_dir, 'index')
        for field in self.config['storage']['index_fields']:
            self.assertTrue(field in os.listdir(index_dir), f"No {field} index created")
        
        # Test queries on the processed logs
        pattern_results = search_by_pattern(self.storage_dir, 'GET')
        self.assertTrue(len(pattern_results) > 0, "Pattern search found no results")
        
        # If status index has been created properly, test index search
        if 'status' in os.listdir(index_dir):
            # Look for status values in the index
            status_values = os.listdir(os.path.join(index_dir, 'status'))
            if status_values:  # If any status values are indexed
                index_results = search_by_index(self.storage_dir, 'status', status_values[0])
                self.assertTrue(len(index_results) > 0, "Index search found no results")
        
        # Stop the pipeline
        stop_event.set()
        pipeline_thread.join(timeout=5)
    
    def test_pipeline_recovery(self):
        """Test pipeline recovery after component failures"""
        # Create a log file with some initial logs
        log_file = os.path.join(self.logs_dir, 'app.log')
        with open(log_file, 'w') as f:
            for _ in range(5):
                f.write(generate_log('apache') + '\n')
        
        # Start components individually for better control
        
        # Start collector
        collector_stop = threading.Event()
        collector_thread = threading.Thread(
            target=collect_logs,
            args=(log_file, self.collected_dir, 1),
            kwargs={'stop_event': collector_stop}
        )
        collector_thread.daemon = True
        collector_thread.start()
        
        # Wait for collector to process initial logs
        time.sleep(2)
        
        # Check that initial logs were collected
        initial_collected_files = os.listdir(self.collected_dir)
        initial_collected_count = len(initial_collected_files)
        self.assertTrue(initial_collected_count > 0, "Initial logs not collected")
        
        # Stop collector to simulate failure
        collector_stop.set()
        collector_thread.join(timeout=2)
        
        # Add more logs while collector is down
        with open(log_file, 'a') as f:
            for _ in range(5):
                f.write(generate_log('apache') + '\n')
        
        # Restart collector
        collector_stop = threading.Event()
        collector_thread = threading.Thread(
            target=collect_logs,
            args=(log_file, self.collected_dir, 1),
            kwargs={'stop_event': collector_stop}
        )
        collector_thread.daemon = True
        collector_thread.start()
        
        # Wait for collector to catch up
        time.sleep(3)
        
        # Check that collector recovered and processed new logs
        new_collected_files = os.listdir(self.collected_dir)
        new_collected_count = len(new_collected_files)
        self.assertTrue(new_collected_count > initial_collected_count, 
                       "Collector did not recover and process new logs")
        
        # Start parser
        parser_stop = threading.Event()
        parser_thread = threading.Thread(
            target=process_parser_logs,
            args=(self.collected_dir, self.parsed_dir, 'apache'),
            kwargs={'stop_event': parser_stop}
        )
        parser_thread.daemon = True
        parser_thread.start()
        
        # Wait for parser to process
        time.sleep(3)
        
        # Check that parser processed logs
        parsed_files = os.listdir(self.parsed_dir)
        self.assertTrue(len(parsed_files) > 0, "Parser did not process logs")
        
        # Stop parser to simulate failure
        parser_stop.set()
        parser_thread.join(timeout=2)
        
        # Collector continues to collect logs
        with open(log_file, 'a') as f:
            for _ in range(5):
                f.write(generate_log('apache') + '\n')
        
        # Wait for collector to process new logs
        time.sleep(2)
        
        # Restart parser
        parser_stop = threading.Event()
        parser_thread = threading.Thread(
            target=process_parser_logs,
            args=(self.collected_dir, self.parsed_dir, 'apache'),
            kwargs={'stop_event': parser_stop}
        )
        parser_thread.daemon = True
        parser_thread.start()
        
        # Wait for parser to catch up
        time.sleep(3)
        
        # Check that parser recovered and processed new logs
        new_parsed_files = os.listdir(self.parsed_dir)
        self.assertTrue(len(new_parsed_files) > len(parsed_files), 
                       "Parser did not recover and process new logs")
        
        # Clean up threads
        collector_stop.set()
        parser_stop.set()
        collector_thread.join(timeout=2)
        parser_thread.join(timeout=2)
    
    def test_pipeline_load_testing(self):
        """Test pipeline under high load"""
        # Generate a large number of logs at a high rate
        log_file = os.path.join(self.logs_dir, 'high_load.log')
        
        # Generate logs in a separate thread
        generator_stop = threading.Event()
        
        def generate_logs_thread():
            # Generate 200 logs at a rate of 50 logs/second
            write_logs(log_file, 50, 'apache', count=200, stop_event=generator_stop)
        
        generator_thread = threading.Thread(target=generate_logs_thread)
        generator_thread.daemon = True
        generator_thread.start()
        
        # Start the pipeline components
        collector_stop = threading.Event()
        parser_stop = threading.Event()
        storage_stop = threading.Event()
        
        collector_thread = threading.Thread(
            target=collect_logs,
            args=(log_file, self.collected_dir, 0.5),  # Faster collection interval
            kwargs={'stop_event': collector_stop}
        )
        
        parser_thread = threading.Thread(
            target=process_parser_logs,
            args=(self.collected_dir, self.parsed_dir, 'apache'),
            kwargs={'interval': 0.5, 'stop_event': parser_stop}  # Faster parsing interval
        )
        
        storage_thread = threading.Thread(
            target=process_storage_logs,
            args=(self.parsed_dir, self.storage_dir),
            kwargs={
                'index_fields': ['level', 'status', 'method'],
                'interval': 0.5,  # Faster storage interval
                'stop_event': storage_stop
            }
        )
        
        # Start all components
        collector_thread.daemon = True
        parser_thread.daemon = True
        storage_thread.daemon = True
        
        collector_thread.start()
        parser_thread.start()
        storage_thread.start()
        
        # Let the system process for a while
        time.sleep(10)
        
        # Stop generator
        generator_stop.set()
        generator_thread.join(timeout=2)
        
        # Let pipeline complete processing any remaining logs
        time.sleep(5)
        
        # Check log counts at each stage
        with open(log_file, 'r') as f:
            generated_count = sum(1 for _ in f)
        
        collected_count = sum(1 for f in os.listdir(self.collected_dir) 
                             for _ in open(os.path.join(self.collected_dir, f)))
        
        parsed_count = sum(1 for f in os.listdir(self.parsed_dir) 
                          for _ in open(os.path.join(self.parsed_dir, f)))
        
        stored_count = len(os.listdir(os.path.join(self.storage_dir, 'active')))
        
        # Check that most logs were processed successfully
        # We allow for some logs to be in-process between stages
        self.assertTrue(collected_count >= 0.9 * generated_count, 
                       f"Collection missed too many logs: {collected_count} vs {generated_count}")
        
        self.assertTrue(parsed_count >= 0.9 * collected_count, 
                       f"Parser missed too many logs: {parsed_count} vs {collected_count}")
        
        self.assertTrue(stored_count >= 0.9 * parsed_count, 
                       f"Storage missed too many logs: {stored_count} vs {parsed_count}")
        
        # Clean up threads
        collector_stop.set()
        parser_stop.set()
        storage_stop.set()
        collector_thread.join(timeout=2)
        parser_thread.join(timeout=2)
        storage_thread.join(timeout=2)


if __name__ == '__main__':
    unittest.main()