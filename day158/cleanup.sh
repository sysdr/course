#!/bin/bash
# Cleanup script: Stop containers and remove unused Docker resources

set -e

echo "🧹 Starting Cleanup Process"
echo "============================"

# 1. Stop all running containers
echo ""
echo "1️⃣  Stopping all Docker containers..."
if command -v docker &> /dev/null; then
    RUNNING_CONTAINERS=$(docker ps -q)
    if [ -n "$RUNNING_CONTAINERS" ]; then
        echo "   Stopping $(echo $RUNNING_CONTAINERS | wc -w) running container(s)..."
        docker stop $RUNNING_CONTAINERS 2>/dev/null || true
        echo "   ✅ Containers stopped"
    else
        echo "   ℹ️  No running containers found"
    fi
else
    echo "   ⚠️  Docker not found, skipping container cleanup"
fi

# 2. Remove stopped containers
echo ""
echo "2️⃣  Removing stopped containers..."
if command -v docker &> /dev/null; then
    STOPPED_CONTAINERS=$(docker ps -aq)
    if [ -n "$STOPPED_CONTAINERS" ]; then
        echo "   Removing $(echo $STOPPED_CONTAINERS | wc -w) stopped container(s)..."
        docker rm $STOPPED_CONTAINERS 2>/dev/null || true
        echo "   ✅ Stopped containers removed"
    else
        echo "   ℹ️  No stopped containers found"
    fi
else
    echo "   ⚠️  Docker not found, skipping"
fi

# 3. Remove unused images
echo ""
echo "3️⃣  Removing unused Docker images..."
if command -v docker &> /dev/null; then
    UNUSED_IMAGES=$(docker images -q --filter "dangling=true")
    if [ -n "$UNUSED_IMAGES" ]; then
        echo "   Removing $(echo $UNUSED_IMAGES | wc -w) unused image(s)..."
        docker rmi $UNUSED_IMAGES 2>/dev/null || true
        echo "   ✅ Unused images removed"
    else
        echo "   ℹ️  No unused images found"
    fi
else
    echo "   ⚠️  Docker not found, skipping"
fi

# 4. Remove unused volumes
echo ""
echo "4️⃣  Removing unused Docker volumes..."
if command -v docker &> /dev/null; then
    UNUSED_VOLUMES=$(docker volume ls -q --filter "dangling=true")
    if [ -n "$UNUSED_VOLUMES" ]; then
        echo "   Removing $(echo $UNUSED_VOLUMES | wc -w) unused volume(s)..."
        docker volume rm $UNUSED_VOLUMES 2>/dev/null || true
        echo "   ✅ Unused volumes removed"
    else
        echo "   ℹ️  No unused volumes found"
    fi
else
    echo "   ⚠️  Docker not found, skipping"
fi

# 5. Remove unused networks
echo ""
echo "5️⃣  Removing unused Docker networks..."
if command -v docker &> /dev/null; then
    UNUSED_NETWORKS=$(docker network ls -q --filter "dangling=true")
    if [ -n "$UNUSED_NETWORKS" ]; then
        echo "   Removing $(echo $UNUSED_NETWORKS | wc -w) unused network(s)..."
        docker network rm $UNUSED_NETWORKS 2>/dev/null || true
        echo "   ✅ Unused networks removed"
    else
        echo "   ℹ️  No unused networks found"
    fi
else
    echo "   ⚠️  Docker not found, skipping"
fi

# 6. Docker system prune (optional - commented out by default)
# echo ""
# echo "6️⃣  Running docker system prune..."
# docker system prune -f 2>/dev/null || true

echo ""
echo "✅ Docker cleanup complete!"
echo ""
echo "📊 Docker Status:"
if command -v docker &> /dev/null; then
    echo "   Containers: $(docker ps -aq | wc -l) total"
    echo "   Images: $(docker images -q | wc -l) total"
    echo "   Volumes: $(docker volume ls -q | wc -l) total"
fi
