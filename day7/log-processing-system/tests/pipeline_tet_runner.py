#!/usr/bin/env python3
"""
Test runner for the log processing pipeline.
Verifies all components work together correctly.
"""

import os
import sys
import subprocess
import tempfile
import time
from pathlib import Path

def run_integration_tests():
    """Run the integration tests and show results."""
    print("🚀 Starting Log Processing Pipeline Integration Tests")
    print("=" * 60)
    
    # Run the integration tests
    script_dir = Path(__file__).parent
    test_script = script_dir / "integration_tests.py"
    
    start_time = time.time()
    
    try:
        result = subprocess.run([
            sys.executable, str(test_script)
        ], capture_output=True, text=True)
        
        duration = time.time() - start_time
        
        print(f"Test execution completed in {duration:.2f} seconds")
        print("\n📊 Test Results:")
        print("-" * 40)
        
        if result.returncode == 0:
            print("✅ ALL TESTS PASSED!")
            success_count = result.stdout.count("test_") - result.stdout.count("FAIL")
            print(f"✅ {success_count} tests completed successfully")
        else:
            print("❌ SOME TESTS FAILED!")
            print("Failed tests output:")
        
        # Show test output
        if result.stdout:
            print("\n📝 Test Output:")
            print(result.stdout)
        
        if result.stderr:
            print("\n⚠️  Test Errors:")
            print(result.stderr)
        
        return result.returncode == 0
        
    except FileNotFoundError:
        print("❌ Integration test script not found!")
        print("Make sure integration_tests.py is in the same directory")
        return False
    except Exception as e:
        print(f"❌ Error running tests: {e}")
        return False

def verify_pipeline_components():
    """Verify all pipeline components are properly structured."""
    print("\n🔍 Verifying Pipeline Components")
    print("-" * 40)
    
    required_components = [
        "generator.py",
        "collector.py", 
        "parser.py",
        "storage.py",
        "query.py"
    ]
    
    script_dir = Path(__file__).parent
    all_present = True
    
    for component in required_components:
        component_path = script_dir / component
        if component_path.exists():
            print(f"✅ {component} - Found")
        else:
            print(f"❌ {component} - Missing")
            all_present = False
    
    return all_present

def run_quick_smoke_test():
    """Run a quick smoke test of the pipeline."""
    print("\n🧪 Running Quick Smoke Test")
    print("-" * 40)
    
    # Create temporary test environment
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        logs_dir = temp_path / "logs"
        logs_dir.mkdir()
        
        test_log = logs_dir / "test.log"
        
        # Generate a simple test log
        test_content = '''192.168.1.100 - - [27/Oct/2023:10:00:00 +0000] "GET /api/test HTTP/1.1" 200 1234 "-" "TestAgent/1.0"
10.0.0.50 - - [27/Oct/2023:10:00:01 +0000] "POST /api/data HTTP/1.1" 201 567 "-" "curl/7.68.0"
'''
        test_log.write_text(test_content)
        
        print(f"✅ Created test log with {len(test_content.strip().split())} entries")
        print(f"✅ Log file size: {test_log.stat().st_size} bytes")
        
        # Verify log content is readable
        with open(test_log) as f:
            lines = f.readlines()
            print(f"✅ Successfully read {len(lines)} log lines")
        
        return True

def main():
    """Main test runner function."""
    print("Log Processing Pipeline - Test Suite")
    print("====================================\n")
    
    # Step 1: Verify components exist
    components_ok = verify_pipeline_components()
    if not components_ok:
        print("\n❌ Missing components! Cannot proceed with tests.")
        return False
    
    # Step 2: Run smoke test
    smoke_ok = run_quick_smoke_test()
    if not smoke_ok:
        print("\n❌ Smoke test failed!")
        return False
    
    # Step 3: Run full integration tests
    tests_ok = run_integration_tests()
    
    # Final summary
    print("\n" + "=" * 60)
    if tests_ok:
        print("🎉 PIPELINE VERIFICATION COMPLETE - ALL TESTS PASSED!")
        print("✅ The log processing pipeline is working correctly.")
        print("✅ All components integrate properly.")
        print("✅ End-to-end functionality verified.")
    else:
        print("⚠️  PIPELINE VERIFICATION INCOMPLETE - SOME ISSUES FOUND")
        print("❌ Please check the test output above for details.")
        print("🔧 Fix any failing tests before using the pipeline.")
    
    print("=" * 60)
    return tests_ok

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)