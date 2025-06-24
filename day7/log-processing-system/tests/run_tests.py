#!/usr/bin/env python3
# run_tests.py - Script to run all tests for the log processing pipeline

import unittest
import sys
import os
import subprocess
import argparse
import time
import docker
import json

def run_unit_tests():
    """Run all unit tests for individual components"""
    test_modules = [
        'test_generator.py',
        'test_collector.py',
        'test_parser.py',
        'test_storage.py',
        'test_query.py'
    ]
    
    results = {}
    all_passed = True
    
    for test_module in test_modules:
        print(f"\n{'-' * 70}")
        print(f"Running tests in {test_module}")
        print(f"{'-' * 70}")
        
        result = subprocess.run(
            [sys.executable, test_module],
            capture_output=True,
            text=True
        )
        
        print(result.stdout)
        if result.stderr:
            print(f"ERRORS:\n{result.stderr}", file=sys.stderr)
        
        results[test_module] = result.returncode == 0
        all_passed = all_passed and results[test_module]
    
    print("\n" + "=" * 70)
    print("Unit Test Summary:")
    print("=" * 70)
    
    for module, passed in results.items():
        status = "PASSED" if passed else "FAILED"
        print(f"{module}: {status}")
    
    return all_passed

def run_integration_tests():
    """Run integration tests"""
    print(f"\n{'-' * 70}")
    print("Running integration tests")
    print(f"{'-' * 70}")
    
    result = subprocess.run(
        [sys.executable, 'test_integration.py'],
        capture_output=True,
        text=True
    )
    
    print(result.stdout)
    if result.stderr:
        print(f"ERRORS:\n{result.stderr}", file=sys.stderr)
    
    integration_passed = result.returncode == 0
    
    print("\n" + "=" * 70)
    print("Integration Test Summary:")
    print("=" * 70)
    print(f"Integration Tests: {'PASSED' if integration_passed else 'FAILED'}")
    
    return integration_passed

def run_docker_tests():
    """Test the Docker containers and Docker Compose setup"""
    print(f"\n{'-' * 70}")
    print("Running Docker tests")
    print(f"{'-' * 70}")
    
    # Check Docker is available
    try:
        docker_client = docker.from_env()
        docker_client.ping()
    except Exception as e:
        print(f"Docker is not available: {e}")
        return False
    
    # Build the Docker images
    print("Building Docker images...")
    build_result = subprocess.run(
        ['docker-compose', 'build'],
        capture_output=True,
        text=True
    )
    
    if build_result.returncode != 0:
        print("Failed to build Docker images:")
        print(build_result.stderr)
        return False
    
    print("Docker images built successfully.")
    
    # Start the containers
    print("Starting Docker containers...")
    start_result = subprocess.run(
        ['docker-compose', 'up', '-d'],
        capture_output=True,
        text=True
    )
    
    if start_result.returncode != 0:
        print("Failed to start Docker containers:")
        print(start_result.stderr)
        return False
    
    print("Docker containers started successfully.")
    
    try:
        # Wait for the system to process some logs
        print("Waiting for log processing...")
        time.sleep(30)
        
        # Check container logs for errors
        print("Checking container logs...")
        logs_result = subprocess.run(
            ['docker-compose', 'logs'],
            capture_output=True,
            text=True
        )
        
        # Check for error indicators in logs
        error_indicators = ['error', 'exception', 'traceback', 'failed']
        errors_found = False
        
        for indicator in error_indicators:
            if indicator.lower() in logs_result.stdout.lower():
                errors_found = True
                print(f"Warning: '{indicator}' found in container logs.")
        
        # Run a test query to verify the pipeline is working
        print("Running test query...")
        query_result = subprocess.run(
            ['docker-compose', 'run', '--rm', 'query', 'python', 'query.py', '--storage-dir', '/data/storage', '--pattern', 'GET'],
            capture_output=True,
            text=True
        )
        
        query_success = query_result.returncode == 0 and 'GET' in query_result.stdout
        
        if not query_success:
            print("Query test failed:")
            print(query_result.stdout)
            print(query_result.stderr)
        else:
            print("Query test succeeded.")
        
        # Check container health
        print("Checking container health...")
        ps_result = subprocess.run(
            ['docker-compose', 'ps'],
            capture_output=True,
            text=True
        )
        
        containers_healthy = 'Exit' not in ps_result.stdout
        
        if not containers_healthy:
            print("Some containers have exited:")
            print(ps_result.stdout)
        else:
            print("All containers running.")
        
        # Final result determination
        docker_passed = not errors_found and query_success and containers_healthy
        
        print("\n" + "=" * 70)
        print("Docker Test Summary:")
        print("=" * 70)
        print(f"Docker Tests: {'PASSED' if docker_passed else 'FAILED'}")
        print(f"  - Container logs check: {'PASSED' if not errors_found else 'WARNINGS'}")
        print(f"  - Query test: {'PASSED' if query_success else 'FAILED'}")
        print(f"  - Container health: {'PASSED' if containers_healthy else 'FAILED'}")
        
        return docker_passed
    
    finally:
        # Always stop and clean up the containers
        print("Stopping and cleaning up Docker containers...")
        subprocess.run(['docker-compose', 'down'], check=False)

def run_performance_tests():
    """Run performance tests on the pipeline"""
    print(f"\n{'-' * 70}")
    print("Running performance tests")
    print(f"{'-' * 70}")
    
    # Create a script to measure throughput
    with open('perf_test.py', 'w') as f:
        f.write('''
import time
import os
import sys
import subprocess
import json
import tempfile
import shutil

# Import component modules
sys.path.append('..')
from generator.generator import write_logs
from collector.collector import collect_logs
from parser.parser import process_logs as process_parser_logs
from storage.storage import process_logs as process_storage_logs

def run_perf_test(log_rate, duration):
    """Run a performance test with specified log rate and duration"""
    # Create temporary test directory
    test_dir = tempfile.mkdtemp()
    
    try:
        # Set up directory structure
        logs_dir = os.path.join(test_dir, 'logs')
        collected_dir = os.path.join(test_dir, 'collected')
        parsed_dir = os.path.join(test_dir, 'parsed')
        storage_dir = os.path.join(test_dir, 'storage')
        
        # Create required directories
        os.makedirs(logs_dir, exist_ok=True)
        os.makedirs(collected_dir, exist_ok=True)
        os.makedirs(parsed_dir, exist_ok=True)
        os.makedirs(os.path.join(storage_dir, 'active'), exist_ok=True)
        os.makedirs(os.path.join(storage_dir, 'archive'), exist_ok=True)
        os.makedirs(os.path.join(storage_dir, 'index'), exist_ok=True)
        
        # Run generator in subprocess
        log_file = os.path.join(logs_dir, 'perf_test.log')
        expected_logs = log_rate * duration
        
        generator_cmd = [
            sys.executable, '-c',
            f'import sys; sys.path.append(".."); from generator.generator import write_logs; '
            f'write_logs("{log_file}", {log_rate}, "apache", count={expected_logs})'
        ]
        
        # Start generator
        print(f"Starting generator with rate {log_rate} logs/sec for {duration} seconds...")
        start_time = time.time()
        generator_process = subprocess.Popen(generator_cmd)
        
        # Start collector
        collector_cmd = [
            sys.executable, '-c',
            f'import sys, threading; sys.path.append(".."); '
            f'from collector.collector import collect_logs; '
            f'collect_logs("{log_file}", "{collected_dir}", 0.5, max_iterations={duration*4})'
        ]
        collector_process = subprocess.Popen(collector_cmd)
        
        # Start parser
        parser_cmd = [
            sys.executable, '-c',
            f'import sys, threading; sys.path.append(".."); '
            f'from parser.parser import process_logs; '
            f'process_logs("{collected_dir}", "{parsed_dir}", "apache", interval=0.5, max_iterations={duration*4})'
        ]
        parser_process = subprocess.Popen(parser_cmd)
        
        # Start storage
        storage_cmd = [
            sys.executable, '-c',
            f'import sys, threading; sys.path.append(".."); '
            f'from storage.storage import process_logs; '
            f'process_logs("{parsed_dir}", "{storage_dir}", index_fields=["level", "status", "method"], '
            f'interval=0.5, max_iterations={duration*4})'
        ]
        storage_process = subprocess.Popen(storage_cmd)
        
        # Wait for completion or timeout
        timeout = duration * 2  # Double the expected duration as timeout
        generator_process.wait(timeout=timeout)
        
        # Give extra time for pipeline processing
        extra_time = min(duration, 10)  # 10 seconds max extra time
        print(f"Generator completed. Waiting {extra_time} more seconds for pipeline processing...")
        time.sleep(extra_time)
        
        # Stop all processes
        for p in [collector_process, parser_process, storage_process]:
            if p.poll() is None:  # If still running
                p.terminate()
                try:
                    p.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    p.kill()
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # Count logs at each stage
        with open(log_file, 'r') as f:
            generated_count = sum(1 for _ in f)
        
        collected_count = sum(1 for f in os.listdir(collected_dir) 
                             for _ in open(os.path.join(collected_dir, f)))
        
        parsed_count = sum(1 for f in os.listdir(parsed_dir) 
                          for _ in open(os.path.join(parsed_dir, f)))
        
        stored_count = len(os.listdir(os.path.join(storage_dir, 'active')))
        
        # Calculate throughput
        throughput = generated_count / total_time
        
        # Calculate pipeline efficiency
        if generated_count > 0:
            collection_efficiency = collected_count / generated_count * 100
            parsing_efficiency = parsed_count / collected_count * 100 if collected_count > 0 else 0
            storage_efficiency = stored_count / parsed_count * 100 if parsed_count > 0 else 0
            overall_efficiency = stored_count / generated_count * 100
        else:
            collection_efficiency = parsing_efficiency = storage_efficiency = overall_efficiency = 0
        
        # Return performance metrics
        return {
            'log_rate': log_rate,
            'duration': duration,
            'total_time': total_time,
            'generated_count': generated_count,
            'collected_count': collected_count,
            'parsed_count': parsed_count,
            'stored_count': stored_count,
            'throughput': throughput,
            'collection_efficiency': collection_efficiency,
            'parsing_efficiency': parsing_efficiency,
            'storage_efficiency': storage_efficiency,
            'overall_efficiency': overall_efficiency
        }
    
    finally:
        # Clean up
        shutil.rmtree(test_dir)

if __name__ == '__main__':
    # Run tests with increasing load
    results = []
    
    for rate in [10, 50, 100, 200]:
        print(f"\\nTesting with rate: {rate} logs/second")
        result = run_perf_test(rate, 10)  # 10 seconds duration
        results.append(result)
        print(f"  Generated: {result['generated_count']} logs")
        print(f"  Throughput: {result['throughput']:.2f} logs/second")
        print(f"  Overall efficiency: {result['overall_efficiency']:.2f}%")
    
    # Output results as JSON
    with open('perf_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print("\\nPerformance test results saved to perf_results.json")
''')
    
    # Run the performance test script
    result = subprocess.run(
        [sys.executable, 'perf_test.py'],
        capture_output=True,
        text=True
    )
    
    print(result.stdout)
    if result.stderr:
        print(f"ERRORS:\n{result.stderr}", file=sys.stderr)
    
    perf_passed = result.returncode == 0
    
    # Load and display detailed results if available
    try:
        with open('perf_results.json', 'r') as f:
            perf_results = json.load(f)
        
        print("\nDetailed Performance Results:")
        print("-" * 70)
        
        for result in perf_results:
            print(f"\nLog Rate: {result['log_rate']} logs/second")
            print(f"  Duration: {result['duration']} seconds")
            print(f"  Actual Time: {result['total_time']:.2f} seconds")
            print(f"  Generated: {result['generated_count']} logs")
            print(f"  Processed: {result['stored_count']} logs")
            print(f"  Throughput: {result['throughput']:.2f} logs/second")
            print(f"  Efficiency: {result['overall_efficiency']:.2f}%")
        
        # Determine if performance is acceptable
        # Threshold: At least 75% efficiency at moderate load
        moderate_load_results = [r for r in perf_results if r['log_rate'] == 50]
        if moderate_load_results and moderate_load_results[0]['overall_efficiency'] >= 75:
            perf_acceptable = True
        else:
            perf_acceptable = False
            print("\nWARNING: Performance below acceptable threshold at moderate load.")
    
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"\nCould not load detailed performance results: {e}")
        perf_acceptable = False
    
    print("\n" + "=" * 70)
    print("Performance Test Summary:")
    print("=" * 70)
    print(f"Performance Tests: {'PASSED' if perf_passed else 'FAILED'}")
    print(f"Performance Acceptable: {'YES' if perf_acceptable else 'NO'}")
    
    # Clean up
    try:
        os.remove('perf_test.py')
        os.remove('perf_results.json')
    except FileNotFoundError:
        pass
    
    return perf_passed and perf_acceptable

def main():
    parser = argparse.ArgumentParser(description='Run tests for the log processing pipeline')
    parser.add_argument('--unit', action='store_true', help='Run unit tests')
    parser.add_argument('--integration', action='store_true', help='Run integration tests')
    parser.add_argument('--docker', action='store_true', help='Run Docker tests')
    parser.add_argument('--performance', action='store_true', help='Run performance tests')
    parser.add_argument('--all', action='store_true', help='Run all tests')
    
    args = parser.parse_args()
    
    # If no arguments provided, run all tests
    if not (args.unit or args.integration or args.docker or args.performance or args.all):
        args.all = True
    
    # Record test results
    results = {}
    
    # Run unit tests
    if args.unit or args.all:
        results['unit'] = run_unit_tests()
    
    # Run integration tests
    if args.integration or args.all:
        results['integration'] = run_integration_tests()
    
    # Run Docker tests
    if args.docker or args.all:
        results['docker'] = run_docker_tests()
    
    # Run performance tests
    if args.performance or args.all:
        results['performance'] = run_performance_tests()
    
    # Print overall summary
    print("\n" + "=" * 70)
    print("OVERALL TEST SUMMARY")
    print("=" * 70)
    
    for test_type, passed in results.items():
        status = "PASSED" if passed else "FAILED"
        print(f"{test_type.capitalize()} Tests: {status}")
    
    # Determine overall pass/fail
    all_passed = all(results.values())
    print("\nOVERALL RESULT: ", end="")
    if all_passed:
        print("PASSED - All tests completed successfully!")
        return 0
    else:
        print("FAILED - Some tests did not pass.")
        return 1

if __name__ == '__main__':
    sys.exit(main())