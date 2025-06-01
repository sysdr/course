FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Generate Protocol Buffer code
RUN python -m grpc_tools.protoc --proto_path=proto --python_out=proto --grpc_python_out=proto proto/log_entry.proto

# Expose port for web interface
EXPOSE 5000

# Command to run the application
CMD ["python", "web/log_viewer.py"]
