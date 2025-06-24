#!/usr/bin/env python3
"""
SSL Compatibility Test Script
Tests SSL/TLS configuration compatibility across different systems
"""

import ssl
import sys
from pathlib import Path

def test_ssl_versions():
    """Test available SSL/TLS versions"""
    print("🔍 Testing SSL/TLS Version Support:")
    print("-" * 50)
    
    # Check available TLS versions
    versions = []
    
    if hasattr(ssl, 'TLSVersion'):
        if hasattr(ssl.TLSVersion, 'TLSv1_2'):
            versions.append("TLS 1.2")
        if hasattr(ssl.TLSVersion, 'TLSv1_3'):
            versions.append("TLS 1.3")
    else:
        versions.append("Legacy SSL support")
    
    print(f"Available versions: {', '.join(versions)}")
    
    # Test SSL context creation
    try:
        ctx = ssl.create_default_context()
        print("✅ Default SSL context creation: SUCCESS")
    except Exception as e:
        print(f"❌ Default SSL context creation: FAILED - {e}")
        return False
    
    return True

def test_cipher_suites():
    """Test cipher suite compatibility"""
    print("\n🔐 Testing Cipher Suite Compatibility:")
    print("-" * 50)
    
    ctx = ssl.create_default_context()
    
    # Test different cipher suites in order of preference
    cipher_suites = [
        ("TLS 1.3 Ciphers", "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"),
        ("Modern Secure", "ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS"),
        ("Broad Compatibility", "ECDHE+AES:DHE+AES:RSA+AES:!aNULL:!MD5:!DSS:!RC4"),
        ("High Security", "HIGH:!aNULL:!MD5:!RC4:!DSS"),
        ("Maximum Compatibility", "ALL:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!SRP:!CAMELLIA")
    ]
    
    working_cipher = None
    
    for name, cipher_suite in cipher_suites:
        try:
            test_ctx = ssl.create_default_context()
            test_ctx.set_ciphers(cipher_suite)
            print(f"✅ {name}: SUCCESS")
            if working_cipher is None:
                working_cipher = (name, cipher_suite)
        except ssl.SSLError as e:
            print(f"❌ {name}: FAILED - {e}")
    
    if working_cipher:
        print(f"\n🎯 Recommended cipher suite: {working_cipher[0]}")
        return working_cipher
    else:
        print("❌ No compatible cipher suites found!")
        return None

def test_certificate_loading():
    """Test certificate loading"""
    print("\n📜 Testing Certificate Loading:")
    print("-" * 50)
    
    cert_path = Path('certs/server.crt')
    key_path = Path('certs/server.key')
    
    if not cert_path.exists():
        print(f"❌ Certificate not found: {cert_path}")
        return False
    
    if not key_path.exists():
        print(f"❌ Private key not found: {key_path}")
        return False
    
    print(f"✅ Certificate found: {cert_path}")
    print(f"✅ Private key found: {key_path}")
    
    # Test loading certificates
    try:
        ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ctx.load_cert_chain(str(cert_path), str(key_path))
        print("✅ Certificate loading: SUCCESS")
        return True
    except Exception as e:
        print(f"❌ Certificate loading: FAILED - {e}")
        return False

def test_complete_ssl_setup():
    """Test complete SSL setup with fallbacks"""
    print("\n🛡️  Testing Complete SSL Setup:")
    print("-" * 50)
    
    try:
        # Server context
        server_ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        server_ctx.load_cert_chain('certs/server.crt', 'certs/server.key')
        
        # Try progressive fallback
        tls_version = "Unknown"
        
        try:
            if hasattr(ssl, 'TLSVersion') and hasattr(ssl.TLSVersion, 'TLSv1_3'):
                server_ctx.minimum_version = ssl.TLSVersion.TLSv1_3
                server_ctx.set_ciphers('TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256')
                tls_version = "TLS 1.3"
            else:
                raise AttributeError("TLS 1.3 not available")
                
        except (AttributeError, ssl.SSLError):
            # Fallback to TLS 1.2
            if hasattr(ssl, 'TLSVersion') and hasattr(ssl.TLSVersion, 'TLSv1_2'):
                server_ctx.minimum_version = ssl.TLSVersion.TLSv1_2
            
            # Progressive cipher fallback
            cipher_suites = [
                'ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS',
                'ECDHE+AES:DHE+AES:RSA+AES:!aNULL:!MD5:!DSS:!RC4',
                'HIGH:!aNULL:!MD5:!RC4:!DSS',
                'ALL:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!SRP:!CAMELLIA'
            ]
            
            cipher_set = False
            for cipher_suite in cipher_suites:
                try:
                    server_ctx.set_ciphers(cipher_suite)
                    cipher_set = True
                    break
                except ssl.SSLError:
                    continue
            
            if cipher_set:
                tls_version = "TLS 1.2"
            else:
                tls_version = "System Default"
        
        print(f"✅ Server SSL setup successful with {tls_version}")
        
        # Client context
        client_ctx = ssl.create_default_context()
        client_ctx.check_hostname = False
        client_ctx.verify_mode = ssl.CERT_NONE
        
        # Match server configuration
        try:
            if tls_version == "TLS 1.3":
                client_ctx.minimum_version = ssl.TLSVersion.TLSv1_3
                client_ctx.set_ciphers('TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256')
            else:
                if hasattr(ssl, 'TLSVersion') and hasattr(ssl.TLSVersion, 'TLSv1_2'):
                    client_ctx.minimum_version = ssl.TLSVersion.TLSv1_2
                
                # Use the same cipher suite that worked for server
                for cipher_suite in cipher_suites:
                    try:
                        client_ctx.set_ciphers(cipher_suite)
                        break
                    except ssl.SSLError:
                        continue
        except:
            pass  # Use system defaults
        
        print(f"✅ Client SSL setup successful with {tls_version}")
        
        return True, tls_version
        
    except Exception as e:
        print(f"❌ Complete SSL setup failed: {e}")
        return False, None

def generate_ssl_config():
    """Generate recommended SSL configuration"""
    print("\n⚙️  Generating Recommended Configuration:")
    print("-" * 50)
    
    success, tls_version = test_complete_ssl_setup()
    
    if success:
        config = f"""
# Recommended SSL Configuration for your system
TLS_VERSION = "{tls_version}"
SSL_CERT_PATH = "certs/server.crt"
SSL_KEY_PATH = "certs/server.key"

# Python SSL Context Settings:
import ssl

# Server Context
server_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
server_context.load_cert_chain('certs/server.crt', 'certs/server.key')

# Client Context  
client_context = ssl.create_default_context()
client_context.check_hostname = False
client_context.verify_mode = ssl.CERT_NONE

# Version and Cipher Configuration
{'# TLS 1.3 Configuration' if tls_version == 'TLS 1.3' else '# TLS 1.2 Configuration'}
"""
        
        print(config)
        
        # Save to file
        with open('ssl_config_recommended.py', 'w') as f:
            f.write(config.strip())
        
        print("💾 Configuration saved to: ssl_config_recommended.py")
        
    return success

def main():
    """Main SSL compatibility test"""
    print("🔐 SSL/TLS Compatibility Test Suite")
    print("=" * 60)
    print(f"Python version: {sys.version}")
    print(f"OpenSSL version: {ssl.OPENSSL_VERSION}")
    print("=" * 60)
    
    tests = [
        ("SSL Version Support", test_ssl_versions),
        ("Cipher Suite Compatibility", test_cipher_suites),
        ("Certificate Loading", test_certificate_loading),
        ("Complete SSL Setup", lambda: test_complete_ssl_setup()[0]),
        ("Generate Configuration", generate_ssl_config),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
            else:
                print(f"❌ {test_name} failed")
        except Exception as e:
            print(f"💥 {test_name} error: {e}")
    
    print("\n" + "=" * 60)
    print(f"📊 SSL COMPATIBILITY TEST RESULTS")
    print("=" * 60)
    print(f"Passed: {passed}/{total}")
    print(f"Success Rate: {(passed/total)*100:.1f}%")
    
    if passed == total:
        print("🎉 All SSL tests passed! Your system is fully compatible.")
        print("\n🚀 You can now run the TLS log system:")
        print("   python src/tls_log_server.py")
        print("   python src/tls_log_client.py")
    else:
        print("⚠️  Some SSL tests failed. Check the output above.")
        print("\n🔧 Try running the fixed version with fallback ciphers.")
    
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)