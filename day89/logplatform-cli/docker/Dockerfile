FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY setup.py .

# Install the CLI package
RUN pip install -e .

# Create non-root user
RUN useradd -m -s /bin/bash loguser
USER loguser

# Set entry point
ENTRYPOINT ["logplatform"]
CMD ["--help"]
