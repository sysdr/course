#!/bin/bash

# Log Ingestor Script for Day 92 Log Viewer Demo
# This script collects real system and application logs and ingests them into the log viewer

echo "🔍 Starting log ingestion for Day 92 Log Viewer Demo..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
API_URL="http://localhost:5000/api"

# Function to collect Docker container logs
collect_docker_logs() {
    echo -e "${YELLOW}[COLLECTING]${NC} Docker container logs..."
    
    # Collect backend logs
    echo "Collecting backend container logs..."
    docker logs day92-log-viewer-backend-1 --tail 5 2>/dev/null | while read -r line; do
        if [[ -n "$line" ]]; then
            timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            # Escape quotes and limit message length
            message=$(echo "$line" | sed 's/"/\\"/g' | head -c 200)
            
            curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "{
                    \"timestamp\": \"$timestamp\",
                    \"level\": \"INFO\",
                    \"service\": \"docker-backend\",
                    \"message\": \"$message\",
                    \"metadata\": {\"source\": \"docker\", \"container\": \"day92-log-viewer-backend-1\"}
                }" \
                "$API_URL/logs" > /dev/null
            
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}[SUCCESS]${NC} Ingested backend log"
            else
                echo -e "${RED}[ERROR]${NC} Failed to ingest backend log"
            fi
        fi
    done
    
    # Collect frontend logs
    echo "Collecting frontend container logs..."
    docker logs day92-log-viewer-frontend-1 --tail 3 2>/dev/null | while read -r line; do
        if [[ -n "$line" ]]; then
            timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            message=$(echo "$line" | sed 's/"/\\"/g' | head -c 200)
            
            curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "{
                    \"timestamp\": \"$timestamp\",
                    \"level\": \"INFO\",
                    \"service\": \"docker-frontend\",
                    \"message\": \"$message\",
                    \"metadata\": {\"source\": \"docker\", \"container\": \"day92-log-viewer-frontend-1\"}
                }" \
                "$API_URL/logs" > /dev/null
            
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}[SUCCESS]${NC} Ingested frontend log"
            else
                echo -e "${RED}[ERROR]${NC} Failed to ingest frontend log"
            fi
        fi
    done
}

# Function to collect system information
collect_system_info() {
    echo -e "${YELLOW}[COLLECTING]${NC} System information..."
    
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # CPU usage (macOS)
    cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "0")
    if [[ -z "$cpu_usage" ]]; then cpu_usage="0"; fi
    
    # Memory usage (macOS)
    memory_info=$(vm_stat 2>/dev/null | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    if [[ -n "$memory_info" ]]; then
        total_memory=$(sysctl -n hw.memsize 2>/dev/null || echo "8589934592")
        memory_usage=$((100 - (memory_info * 4096 * 100) / total_memory))
    else
        memory_usage="0"
    fi
    
    # Disk usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    
    # Network connections
    network_connections=$(netstat -an | grep ESTABLISHED | wc -l 2>/dev/null || echo "0")
    
    # Create system info log
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"timestamp\": \"$timestamp\",
            \"level\": \"INFO\",
            \"service\": \"system-monitor\",
            \"message\": \"System health check completed - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%\",
            \"metadata\": {
                \"cpu_usage\": \"${cpu_usage}%\",
                \"memory_usage\": \"${memory_usage}%\",
                \"disk_usage\": \"${disk_usage}%\",
                \"network_connections\": $network_connections,
                \"hostname\": \"$(hostname)\",
                \"os\": \"$(uname -s)\",
                \"kernel\": \"$(uname -r)\"
            }
        }" \
        "$API_URL/logs" > /dev/null
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} Ingested system info"
    else
        echo -e "${RED}[ERROR]${NC} Failed to ingest system info"
    fi
}

# Function to generate realistic application logs
generate_application_logs() {
    echo -e "${YELLOW}[GENERATING]${NC} Realistic application logs..."
    
    services=("api-gateway" "user-service" "payment-service" "auth-service" "notification-service" "database-service")
    levels=("INFO" "WARN" "ERROR" "DEBUG")
    
    for i in {1..20}; do
        service=${services[$((RANDOM % ${#services[@]}))]}
        level=${levels[$((RANDOM % ${#levels[@]}))]}
        timestamp=$(date -u -d "$((RANDOM % 24)) hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-${RANDOM}H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        case $service in
            "api-gateway")
                messages=(
                    "Request processed successfully for endpoint /api/v1/users"
                    "Rate limit exceeded for IP 192.168.1.$((RANDOM % 255))"
                    "Authentication failed for user user$((RANDOM % 1000))"
                    "API endpoint /api/v1/payments accessed"
                    "Request timeout after 30 seconds"
                )
                ;;
            "user-service")
                messages=(
                    "User profile updated successfully for user ID $((RANDOM % 10000))"
                    "Database connection established to user_db"
                    "User authentication successful for user$((RANDOM % 1000))"
                    "Failed to update user preferences - validation error"
                    "User session expired for user ID $((RANDOM % 10000))"
                )
                ;;
            "payment-service")
                messages=(
                    "Payment processed successfully - Transaction ID: TX$((RANDOM % 999999))"
                    "Payment gateway timeout - retrying transaction"
                    "Invalid payment method - card declined"
                    "Transaction completed - Amount: \$$((RANDOM % 1000)).$((RANDOM % 100))"
                    "Payment verification failed - insufficient funds"
                )
                ;;
            "auth-service")
                messages=(
                    "Token validation successful for user$((RANDOM % 1000))"
                    "JWT token expired - refresh required"
                    "User login successful from IP 192.168.1.$((RANDOM % 255))"
                    "Authentication failed - invalid credentials"
                    "Password reset requested for user@example.com"
                )
                ;;
            "notification-service")
                messages=(
                    "Email notification sent to user@example.com"
                    "SMS notification failed - invalid phone number"
                    "Push notification delivered to device ID $((RANDOM % 10000))"
                    "Notification queue processed - 150 messages sent"
                    "Template rendering error - missing variable"
                )
                ;;
            "database-service")
                messages=(
                    "Database query executed successfully - 1.2ms"
                    "Connection pool exhausted - creating new connection"
                    "Query timeout occurred - killing long-running query"
                    "Index optimization completed for users table"
                    "Backup process started - estimated time: 15 minutes"
                )
                ;;
        esac
        
        message=${messages[$((RANDOM % ${#messages[@]}))]}
        
        # Add realistic metadata based on level
        case $level in
            "ERROR")
                metadata="{\"error_code\": \"ERR_$((RANDOM % 9999))\", \"retry_count\": $((RANDOM % 3))}"
                ;;
            "WARN")
                metadata="{\"warning_type\": \"PERFORMANCE\", \"threshold\": \"80%\", \"current\": \"$((70 + RANDOM % 30))%\"}"
                ;;
            "DEBUG")
                metadata="{\"debug_level\": \"TRACE\", \"component\": \"$service\", \"trace_id\": \"$(uuidgen | tr -d '-' | head -c 16)\"}"
                ;;
            *)
                metadata="{\"response_time\": $((10 + RANDOM % 200)), \"status_code\": 200}"
                ;;
        esac
        
        # Send log via API
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{
                \"timestamp\": \"$timestamp\",
                \"level\": \"$level\",
                \"service\": \"$service\",
                \"message\": \"$message\",
                \"metadata\": $metadata
            }" \
            "$API_URL/logs" > /dev/null
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}[SUCCESS]${NC} Ingested $service log"
        else
            echo -e "${RED}[ERROR]${NC} Failed to ingest $service log"
        fi
        
        # Small delay to avoid overwhelming the API
        sleep 0.1
    done
}

# Function to create sample data if no logs collected
create_sample_data() {
    echo -e "${YELLOW}[CREATING]${NC} Sample data..."
    
    response=$(curl -s -X POST "$API_URL/logs/init")
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} Sample data created successfully"
        echo "$response" | jq -r '.message' 2>/dev/null || echo "Sample data loaded"
    else
        echo -e "${RED}[ERROR]${NC} Failed to create sample data"
    fi
}

# Main execution
main() {
    # Collect various types of logs
    collect_docker_logs
    collect_system_info
    generate_application_logs
    
    echo -e "${GREEN}[SUCCESS]${NC} Log ingestion completed!"
    echo ""
    echo "📊 View your logs at: http://localhost:3000"
    echo "🔧 API endpoint: http://localhost:5000/api"
    echo ""
    echo "Useful API endpoints:"
    echo "  - GET /api/logs - List all logs"
    echo "  - GET /api/logs/stats - Get log statistics"
    echo "  - POST /api/logs/init - Initialize sample data"
    echo "  - POST /api/logs - Create new log entry"
}

# Run main function
main "$@"
