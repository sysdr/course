#!/usr/bin/env python3
# end_to_end_test.py

import subprocess
import time
import json
import os
import re
import sys

def run_command(command):
    """Run a shell command and return output"""
    print(f"Running: {command}")
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Command failed: {result.stderr}")
        return None
    return result.stdout.strip()

def count_files(directory):
    """Count files in directory"""
    return len([f for f in os.listdir(directory) if os.path.isfile(os.path.join(directory, f))])

def test_system():
    """Test the entire log processing pipeline"""
    # Start clean
    run_command("make clean")
    run_command("make build")
    
    # Start the system
    print("Starting the log processing system...")
    run_command("make run")
    
    # Wait for system to initialize
    print("Waiting for system to initialize...")
    time.sleep(30)
    
    # Verify logs are being generated
    log_output = run_command("docker-compose exec generator ls -la /logs")
    if "app.log" not in log_output:
        print("FAILURE: Log file not found in generator")
        return False
    
    # Verify collector is collecting logs
    collector_output = run_command("docker-compose exec collector ls -la /data/collected")
    if not collector_output or len(collector_output.strip().split('\n')) < 3:  # Header lines + at least one file
        print("FAILURE: Collector not collecting logs")
        return False
    
    # Verify parser is parsing logs
    parser_output = run_command("docker-compose exec parser ls -la /data/parsed")
    if not parser_output or len(parser_output.strip().split('\n')) < 3:
        print("FAILURE: Parser not parsing logs")
        return False
    
    # Verify storage is storing logs
    storage_output = run_command("docker-compose exec storage ls -la /data/storage/active")
    if not storage_output or len(storage_output.strip().split('\n')) < 3:
        print("FAILURE: Storage not storing logs")
        return False
    
    # Verify indexes are being created
    index_output = run_command("docker-compose exec storage ls -la /data/storage/index")
    if not index_output or "level" not in index_output:
        print("FAILURE: Indexes not being created")
        return False
    
    # Wait for more logs to accumulate
    print("Waiting for more logs to accumulate...")
    time.sleep(60)
    
    # Test query functionality - search for common HTTP method
    query_output = run_command('docker-compose run --rm query python query.py --storage-dir /data/storage --pattern "GET"')
    if not query_output or "GET" not in query_output:
        print("FAILURE: Query not returning expected results")
        return False
    
    # Test index query
    index_query = run_command('docker-compose run --rm query python query.py --storage-dir /data/storage --index-type level --index-value INFO')
    if not index_query or "INFO" not in index_query:
        print("FAILURE: Index query not working")
        return False
    
    # Test data flow and counts
    gen_count = int(run_command("docker-compose exec generator grep -c 'GET' /logs/app.log") or "0")
    stored_count = int(run_command("docker-compose exec storage grep -r -c 'GET' /data/storage/active") or "0")
    
    # There will be some lag, but stored should be at least 50% of generated after sufficient time
    if stored_count < (gen_count * 0.5) and gen_count > 10:
        print(f"FAILURE: Data flow issue - Generated: {gen_count}, Stored: {stored_count}")
        return False
    
    print(f"SUCCESS: Pipeline working - Generated: {gen_count}, Stored: {stored_count}")
    
    # Cleanup
    run_command("make stop")
    
    return True

if __name__ == "__main__":
    if test_system():
        print("All tests passed! System is working correctly.")
        sys.exit(0)
    else:
        print("Tests failed! System needs troubleshooting.")
        sys.exit(1)
