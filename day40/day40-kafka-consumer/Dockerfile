FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY web/ ./web/
COPY scripts/ ./scripts/
COPY tests/ ./tests/

# Create logs directory
RUN mkdir -p logs

# Expose dashboard port
EXPOSE 8080

# Set Python path and start application
ENV PYTHONPATH=/app
WORKDIR /app/src
CMD ["python", "main.py"]
