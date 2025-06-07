FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY web/ ./web/
COPY partitions.json .

# Create data directory
RUN mkdir -p data

# Expose port
EXPOSE 8080

# Run the coordinator by default
CMD ["python", "-m", "src.main"]
