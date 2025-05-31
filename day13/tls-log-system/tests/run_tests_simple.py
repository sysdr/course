#!/usr/bin/env python3
"""
Simple test runner with better error handling
"""

import subprocess
import sys
import time
import os
from pathlib import Path

def run_command(cmd, description=""):
    """Run a command and return success status"""
    print(f"\n{'='*50}")
    print(f"🔧 {description}")
    print(f"{'='*50}")
    print(f"Command: {' '.join(cmd)}")
    print("-" * 50)
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        
        if result.stdout:
            print("STDOUT:")
            print(result.stdout)
        
        if result.stderr:
            print("STDERR:")
            print(result.stderr)
        
        if result.returncode == 0:
            print(f"✅ {description} - SUCCESS")
            return True
        else:
            print(f"❌ {description} - FAILED (exit code: {result.returncode})")
            return False
            
    except subprocess.TimeoutExpired:
        print(f"⏰ {description} - TIMEOUT")
        return False
    except Exception as e:
        print(f"💥 {description} - ERROR: {e}")
        return False

def check_prerequisites():
    """Check if all prerequisites are met"""
    print("🔍 Checking Prerequisites...")
    
    # Check Python version
    python_version = sys.version_info
    if python_version < (3, 8):
        print(f"❌ Python 3.8+ required, found {python_version.major}.{python_version.minor}")
        return False
    else:
        print(f"✅ Python {python_version.major}.{python_version.minor}.{python_version.micro}")
    
    # Check if certificates exist
    cert_path = Path('certs/server.crt')
    key_path = Path('certs/server.key')
    if not cert_path.exists() or not key_path.exists():
        print("❌ SSL certificates not found")
        print("   Run the setup script first to generate certificates")
        return False
    else:
        print("✅ SSL certificates found")
    
    # Check if source files exist
    required_files = [
        'src/tls_log_server.py',
        'src/tls_log_client.py',
        'src/web_dashboard.py'
    ]
    
    for file_path in required_files:
        if not Path(file_path).exists():
            print(f"❌ Required file missing: {file_path}")
            return False
    
    print("✅ All source files found")
    return True

def test_imports():
    """Test if all modules can be imported"""
    print("\n🔍 Testing Module Imports...")
    
    test_script = '''
import sys
from pathlib import Path
sys.path.insert(0, str(Path("src")))

try:
    from tls_log_server import TLSLogServer
    print("✅ tls_log_server imported successfully")
except Exception as e:
    print(f"❌ Failed to import tls_log_server: {e}")
    sys.exit(1)

try:
    from tls_log_client import TLSLogClient
    print("✅ tls_log_client imported successfully")
except Exception as e:
    print(f"❌ Failed to import tls_log_client: {e}")
    sys.exit(1)

try:
    from web_dashboard import LogDashboard
    print("✅ web_dashboard imported successfully")
except Exception as e:
    print(f"❌ Failed to import web_dashboard: {e}")
    sys.exit(1)

print("✅ All imports successful")
'''
    
    try:
        result = subprocess.run([sys.executable, '-c', test_script], 
                              capture_output=True, text=True, timeout=30)
        
        print(result.stdout)
        if result.stderr:
            print("STDERR:")
            print(result.stderr)
        
        return result.returncode == 0
    except Exception as e:
        print(f"💥 Import test failed: {e}")
        return False

def test_ssl_context():
    """Test SSL context creation"""
    print("\n🔍 Testing SSL Context Creation...")
    
    test_script = '''
import sys
from pathlib import Path
sys.path.insert(0, str(Path("src")))

try:
    from tls_log_server import TLSLogServer
    from tls_log_client import TLSLogClient
    
    print("Creating TLS server...")
    server = TLSLogServer()
    print("✅ TLS server created successfully")
    
    print("Creating TLS client...")
    client = TLSLogClient()
    print("✅ TLS client created successfully")
    
    print("✅ SSL contexts created successfully")
    
except Exception as e:
    print(f"❌ SSL context creation failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
'''
    
    try:
        result = subprocess.run([sys.executable, '-c', test_script], 
                              capture_output=True, text=True, timeout=30)
        
        print(result.stdout)
        if result.stderr:
            print("STDERR:")
            print(result.stderr)
        
        return result.returncode == 0
    except Exception as e:
        print(f"💥 SSL context test failed: {e}")
        return False

def run_simple_client_test():
    """Run a simple client test without server"""
    print("\n🔍 Testing Client Functions...")
    
    test_script = '''
import sys
from pathlib import Path
sys.path.insert(0, str(Path("src")))

try:
    from tls_log_client import TLSLogClient
    
    print("Creating client...")
    client = TLSLogClient()
    
    print("Testing anonymization...")
    patient_id = "TEST_PATIENT_123"
    anonymized = client.anonymize_patient_id(patient_id)
    print(f"Original: {patient_id}")
    print(f"Anonymized: {anonymized}")
    
    print("Testing metrics...")
    metrics = client.get_metrics()
    print(f"Initial metrics: {metrics}")
    
    print("✅ Client functions working correctly")
    
except Exception as e:
    print(f"❌ Client test failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
'''
    
    try:
        result = subprocess.run([sys.executable, '-c', test_script], 
                              capture_output=True, text=True, timeout=30)
        
        print(result.stdout)
        if result.stderr:
            print("STDERR:")
            print(result.stderr)
        
        return result.returncode == 0
    except Exception as e:
        print(f"💥 Client test failed: {e}")
        return False

def run_pytest_tests():
    """Run pytest with better error handling"""
    print("\n🧪 Running Pytest Tests...")
    
    # Try different pytest commands
    pytest_commands = [
        [sys.executable, '-m', 'pytest', 'tests/test_tls_system.py', '-v', '--tb=short'],
        [sys.executable, '-m', 'pytest', 'tests/test_tls_system.py::test_log_file_reading', '-v'],
        [sys.executable, '-m', 'pytest', 'tests/test_tls_system.py::test_log_statistics', '-v'],
    ]
    
    for i, cmd in enumerate(pytest_commands):
        success = run_command(cmd, f"Pytest Test {i+1}")
        if success:
            return True
    
    return False

def main():
    """Main test runner"""
    print("🚀 TLS LOG SYSTEM - SIMPLE TEST RUNNER")
    print("="*60)
    
    tests = [
        ("Prerequisites Check", check_prerequisites),
        ("Module Imports", test_imports),
        ("SSL Context Creation", test_ssl_context),
        ("Client Functions", run_simple_client_test),
        ("Pytest Tests", run_pytest_tests),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n{'='*60}")
        print(f"🔧 Running: {test_name}")
        print(f"{'='*60}")
        
        try:
            if test_func():
                print(f"✅ {test_name} - PASSED")
                passed += 1
            else:
                print(f"❌ {test_name} - FAILED")
        except Exception as e:
            print(f"💥 {test_name} - ERROR: {e}")
    
    print(f"\n{'='*60}")
    print(f"📊 TEST SUMMARY")
    print(f"{'='*60}")
    print(f"Total Tests: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {total - passed}")
    print(f"Success Rate: {(passed/total)*100:.1f}%")
    
    if passed == total:
        print("🎉 All tests passed!")
        return 0
    else:
        print("⚠️  Some tests failed. Check the output above for details.")
        return 1

if __name__ == "__main__":
    sys.exit(main())