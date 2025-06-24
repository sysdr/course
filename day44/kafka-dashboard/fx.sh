#!/bin/bash

echo "🔧 Fixing Kafka Dashboard Setup Issues..."

# 1. Install Python dependencies first
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# 2. Create missing Dockerfile
echo "🐳 Creating Dockerfile..."
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "src/main/web_app.py"]
EOF

# 3. Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker/docker-compose.yml down 2>/dev/null || true

# 4. Start Docker services
echo "🚀 Starting Docker services..."
docker-compose -f docker/docker-compose.yml up -d

# 5. Wait for Kafka to be ready
echo "⏳ Waiting for Kafka to be ready..."
sleep 45

# 6. Check if Kafka is running
echo "🔍 Checking Kafka status..."
docker ps | grep kafka

# 7. Create Kafka topics
echo "📝 Creating Kafka topics..."
docker exec kafka-dashboard-kafka-1 kafka-topics --create --topic log-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists
docker exec kafka-dashboard-kafka-1 kafka-topics --create --topic error-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists  
docker exec kafka-dashboard-kafka-1 kafka-topics --create --topic user-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists

# 8. Verify topics were created
echo "✅ Verifying topics..."
docker exec kafka-dashboard-kafka-1 kafka-topics --list --bootstrap-server localhost:9092

echo ""
echo "🎉 Setup complete!"
echo "📊 Dashboard will be available at: http://localhost:5000"
echo ""
echo "🚀 To start the dashboard:"
echo "python src/main/web_app.py"
echo ""
echo "📈 To start data generator (in another terminal):"
echo "python src/main/data_generator.py"