FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/
COPY config/ ./config/
COPY tests/ ./tests/

# Create data and logs directories
RUN mkdir -p data logs

# Expose dashboard port
EXPOSE 8080

# Run monitoring service
CMD ["python", "-m", "src.monitoring_service"]
