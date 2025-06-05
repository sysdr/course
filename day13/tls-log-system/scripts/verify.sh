#!/bin/bash

# Comprehensive verification script
set -e

echo "🔍 Verifying TLS Log System..."

# Check file structure
echo "📁 Checking file structure..."
required_files=(
    "src/tls_log_server.py"
    "src/tls_log_client.py" 
    "src/web_dashboard.py"
    "certs/server.crt"
    "certs/server.key"
    "docker-compose.yml"
    "requirements.txt"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done

# Check certificates
echo "🔐 Verifying SSL certificates..."
openssl x509 -in certs/server.crt -text -noout > /dev/null
echo "✅ SSL certificate is valid"

# Check Python syntax
echo "🐍 Checking Python syntax..."
python -m py_compile src/tls_log_server.py
python -m py_compile src/tls_log_client.py
python -m py_compile src/web_dashboard.py
echo "✅ Python syntax is valid"

# Check Docker configuration
echo "🐳 Validating Docker configuration..."
docker-compose config > /dev/null
echo "✅ Docker configuration is valid"

# Test certificate generation
echo "🔑 Testing certificate generation..."
openssl verify -CAfile certs/server.crt certs/server.crt
echo "✅ Certificate verification passed"

echo "🎉 All verifications passed!"
