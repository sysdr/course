#!/bin/bash
# Cleanup script for GitOps project
# Stops all services, Docker containers, and removes unnecessary files

set -e

echo "🧹 GitOps Project Cleanup Script"
echo "=================================="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 1: Stop Python services
echo -e "${BLUE}1️⃣  Stopping Python services...${NC}"
pkill -f "python.*dashboard/app.py" 2>/dev/null && echo -e "${GREEN}   ✓ Stopped dashboard${NC}" || echo -e "${YELLOW}   ⚠ No dashboard process found${NC}"
pkill -f "python.*main.py" 2>/dev/null && echo -e "${GREEN}   ✓ Stopped controller${NC}" || echo -e "${YELLOW}   ⚠ No controller process found${NC}"
sleep 2

# Step 2: Stop and remove Docker containers
echo -e "${BLUE}2️⃣  Stopping Docker containers...${NC}"
if command -v docker >/dev/null 2>&1; then
    # Stop all running containers
    RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null || true)
    if [ -n "$RUNNING_CONTAINERS" ]; then
        echo "   Stopping running containers..."
        docker stop $RUNNING_CONTAINERS 2>/dev/null || true
        echo -e "${GREEN}   ✓ Stopped all running containers${NC}"
    else
        echo -e "${YELLOW}   ⚠ No running containers${NC}"
    fi
    
    # Remove all containers
    ALL_CONTAINERS=$(docker ps -aq 2>/dev/null || true)
    if [ -n "$ALL_CONTAINERS" ]; then
        echo "   Removing all containers..."
        docker rm $ALL_CONTAINERS 2>/dev/null || true
        echo -e "${GREEN}   ✓ Removed all containers${NC}"
    else
        echo -e "${YELLOW}   ⚠ No containers to remove${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠ Docker not installed or not running${NC}"
fi

# Step 3: Remove unused Docker resources
echo -e "${BLUE}3️⃣  Cleaning up Docker resources...${NC}"
if command -v docker >/dev/null 2>&1; then
    # Remove unused images
    echo "   Removing unused images..."
    docker image prune -af 2>/dev/null || true
    echo -e "${GREEN}   ✓ Cleaned unused images${NC}"
    
    # Remove unused volumes
    echo "   Removing unused volumes..."
    docker volume prune -af 2>/dev/null || true
    echo -e "${GREEN}   ✓ Cleaned unused volumes${NC}"
    
    # Remove unused networks
    echo "   Removing unused networks..."
    docker network prune -af 2>/dev/null || true
    echo -e "${GREEN}   ✓ Cleaned unused networks${NC}"
    
    # System prune (optional - be careful)
    echo "   Running system prune..."
    docker system prune -af --volumes 2>/dev/null || true
    echo -e "${GREEN}   ✓ System cleanup complete${NC}"
else
    echo -e "${YELLOW}   ⚠ Docker not available${NC}"
fi

# Step 4: Remove Python cache files and directories
echo -e "${BLUE}4️⃣  Removing Python cache files...${NC}"
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
find . -type f -name "*.pyo" -delete 2>/dev/null || true
find . -type f -name "*.pyd" -delete 2>/dev/null || true
find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
echo -e "${GREEN}   ✓ Removed Python cache files${NC}"

# Step 5: Remove virtual environments
echo -e "${BLUE}5️⃣  Removing virtual environments...${NC}"
find . -type d -name "venv" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "ENV" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name ".venv" -exec rm -rf {} + 2>/dev/null || true
echo -e "${GREEN}   ✓ Removed virtual environments${NC}"

# Step 6: Remove test cache
echo -e "${BLUE}6️⃣  Removing test cache...${NC}"
find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name ".coverage" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "htmlcov" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name ".tox" -exec rm -rf {} + 2>/dev/null || true
echo -e "${GREEN}   ✓ Removed test cache${NC}"

# Step 7: Remove node_modules (if any)
echo -e "${BLUE}7️⃣  Removing node_modules...${NC}"
find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
echo -e "${GREEN}   ✓ Removed node_modules${NC}"

# Step 8: Remove Istio files (if any)
echo -e "${BLUE}8️⃣  Removing Istio files...${NC}"
find . -type f -name "*istio*" -delete 2>/dev/null || true
find . -type f -name "*Istio*" -delete 2>/dev/null || true
find . -type d -name "*istio*" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "*Istio*" -exec rm -rf {} + 2>/dev/null || true
echo -e "${GREEN}   ✓ Removed Istio files${NC}"

# Step 9: Remove log files
echo -e "${BLUE}9️⃣  Removing log files...${NC}"
find . -type f -name "*.log" -delete 2>/dev/null || true
find . -type f -name "dashboard.log" -delete 2>/dev/null || true
echo -e "${GREEN}   ✓ Removed log files${NC}"

# Step 10: Remove temporary files
echo -e "${BLUE}🔟 Removing temporary files...${NC}"
find . -type f -name "*.tmp" -delete 2>/dev/null || true
find . -type f -name "*.temp" -delete 2>/dev/null || true
find . -type f -name ".DS_Store" -delete 2>/dev/null || true
find . -type f -name "*.swp" -delete 2>/dev/null || true
find . -type f -name "*.swo" -delete 2>/dev/null || true
echo -e "${GREEN}   ✓ Removed temporary files${NC}"

# Summary
echo ""
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo "=================================="
echo ""
echo "Removed:"
echo "  • Python services stopped"
echo "  • Docker containers and resources"
echo "  • Python cache files (__pycache__, *.pyc)"
echo "  • Virtual environments (venv, ENV)"
echo "  • Test cache (.pytest_cache)"
echo "  • node_modules directories"
echo "  • Istio files"
echo "  • Log files"
echo "  • Temporary files"
echo ""
echo -e "${YELLOW}Note: Docker images may still exist. Run 'docker images' to check.${NC}"
