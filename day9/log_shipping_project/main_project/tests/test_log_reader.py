import os
import tempfile
import threading
import time
import pytest
from src.log_reader import LogReader

class TestLogReader:
    
    def test_read_batch_existing_file(self):
        # Create a temporary file with test logs
        with tempfile.NamedTemporaryFile(mode='w+', delete=False) as temp:
            temp.write("Log line 1\nLog line 2\nLog line 3\n")
            temp_path = temp.name
        
        try:
            # Test reading the file in batch mode
            reader = LogReader(temp_path)
            logs = reader.read_batch()
            
            assert len(logs) == 3
            assert logs[0] == "Log line 1\n"
            assert logs[1] == "Log line 2\n"
            assert logs[2] == "Log line 3\n"
        finally:
            # Clean up
            os.unlink(temp_path)
    
    def test_read_batch_nonexistent_file(self):
        # Test with a file that doesn't exist
        reader = LogReader("/path/that/does/not/exist")
        logs = reader.read_batch()
        
        assert logs == []
    
    def test_read_incremental(self):
        # Create a temporary file
        with tempfile.NamedTemporaryFile(mode='w+', delete=False) as temp:
            temp.write("Log line 1\n")
            temp_path = temp.name
        
        try:
            reader = LogReader(temp_path)
            
            # Start reading in a separate thread
            logs = []
            stop_event = threading.Event()
            
            def read_thread():
                for log in reader.read_incremental():
                    logs.append(log)
                    if stop_event.is_set():
                        break
            
            thread = threading.Thread(target=read_thread)
            thread.daemon = True
            thread.start()
            
            # Wait a moment for the thread to start
            time.sleep(0.2)
            
            # Append more logs to the file
            with open(temp_path, 'a') as f:
                f.write("Log line 2\n")
                f.write("Log line 3\n")
            
            # Wait for logs to be read
            time.sleep(0.2)
            stop_event.set()
            thread.join(timeout=1)
            
            assert len(logs) >= 3
            assert logs[0] == "Log line 1\n"
            assert logs[1] == "Log line 2\n"
            assert logs[2] == "Log line 3\n"
        finally:
            # Clean up
            os.unlink(temp_path)
