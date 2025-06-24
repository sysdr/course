FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY config/ ./config/
COPY tests/ ./tests/
COPY logs/ ./logs/
COPY ui/ ./ui/

# Create non-root user
RUN useradd -m -u 1000 logprocessor && \
    chown -R logprocessor:logprocessor /app

USER logprocessor

# Expose port for web UI
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "from src.compatibility_processor import CompatibilityProcessor; CompatibilityProcessor()" || exit 1

# Default command
CMD ["python3", "-m", "http.server", "8080", "--directory", "ui"] 