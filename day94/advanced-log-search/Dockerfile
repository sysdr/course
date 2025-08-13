FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Copy backend requirements and install
COPY backend/requirements.txt backend/
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy application code
COPY backend/ backend/
COPY frontend/ frontend/
COPY data/ data/

# Create data directory with proper permissions
RUN mkdir -p data && chmod 755 data

# Expose port
EXPOSE 8000

# Start command
CMD ["python", "backend/main.py"]
