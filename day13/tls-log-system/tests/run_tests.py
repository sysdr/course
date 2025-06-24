#!/usr/bin/env python3
"""
Test runner script with comprehensive testing
"""

import subprocess
import sys
import time
from pathlib import Path

def run_unit_tests():
    """Run unit tests"""
    print("🧪 Running unit tests...")
    
    cmd = [sys.executable, "-m", "pytest", "tests/", "-v", "-m", "not slow"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    print(result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr)
    
    return result.returncode == 0

def run_integration_tests():
    """Run integration tests"""
    print("🔧 Running integration tests...")
    
    cmd = [sys.executable, "-m", "pytest", "tests/", "-v", "-m", "integration"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    print(result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr)
    
    return result.returncode == 0

def run_coverage_test():
    """Run tests with coverage"""
    print("📊 Running coverage analysis...")
    
    cmd = [sys.executable, "-m", "pytest", "--cov=src", "--cov-report=html", "--cov-report=term"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    print(result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr)
    
    return result.returncode == 0

def main():
    """Main test runner"""
    print("="*60)
    print("🚀 TLS LOG SYSTEM - COMPREHENSIVE TEST SUITE")
    print("="*60)
    
    success_count = 0
    total_tests = 3
    
    # Run unit tests
    if run_unit_tests():
        print("✅ Unit tests passed")
        success_count += 1
    else:
        print("❌ Unit tests failed")
    
    print("\n" + "-"*40)
    
    # Run integration tests  
    if run_integration_tests():
        print("✅ Integration tests passed")
        success_count += 1
    else:
        print("❌ Integration tests failed")
    
    print("\n" + "-"*40)
    
    # Run coverage analysis
    if run_coverage_test():
        print("✅ Coverage analysis completed")
        success_count += 1
    else:
        print("❌ Coverage analysis failed")
    
    print("\n" + "="*60)
    print(f"📊 TEST RESULTS: {success_count}/{total_tests} test suites passed")
    
    if success_count == total_tests:
        print("🎉 All tests passed successfully!")
        return 0
    else:
        print("⚠️  Some tests failed. Check output above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
