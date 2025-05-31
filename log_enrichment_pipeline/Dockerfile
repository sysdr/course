FROM python:3.13-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY demo/ ./demo/
COPY config/ ./config/
COPY tests/ ./tests/

# Set environment variables
ENV PYTHONPATH=/app
ENV FLASK_APP=demo/demo_server.py
ENV ENVIRONMENT=docker

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/stats || exit 1

# Run the demo server
CMD ["python", "demo/demo_server.py"]
