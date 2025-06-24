FROM python:3.9-slim

WORKDIR /app

# Install dependencies
RUN pip install PyYAML

# Copy application files
COPY src/ ./src/
COPY config/ ./config/
COPY tests/ ./tests/
COPY web/ ./web/

# Create data directories
RUN mkdir -p data/{node1,node2,node3,node4} logs

# Expose ports for nodes and web dashboard
EXPOSE 8080 8001 8002 8003 9090

# Default command
CMD ["python", "src/cluster_coordinator.py"]
