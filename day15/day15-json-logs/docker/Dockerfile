# Use Python 3.11 slim image as our base
# This gives us a lightweight Linux environment with Python pre-installed
FROM python:3.11-slim

# Set working directory inside the container
# Think of this as choosing which folder to work in
WORKDIR /app

# Copy requirements file first (for better Docker layer caching)
# Docker builds in layers, and copying requirements first allows us
# to cache the dependency installation step
COPY requirements.txt .

# Install Python dependencies
# The --no-cache-dir flag saves space by not storing pip cache
RUN pip install --no-cache-dir -r requirements.txt

# Copy our application source code
# This includes all our Python files and schemas
COPY src/ ./src/
COPY schemas/ ./schemas/
COPY tests/ ./tests/

# Create a non-root user for security
# Running as root inside containers is a security risk
RUN useradd --create-home --shell /bin/bash app && \
    chown -R app:app /app
USER app

# Expose the port our server will listen on
# This tells Docker which port should be available for external connections
EXPOSE 8080

# Set environment variables for better Python behavior in containers
ENV PYTHONPATH=/app/src
ENV PYTHONUNBUFFERED=1

# Default command to run when container starts
# This can be overridden when running the container
CMD ["python", "src/json_server.py"]