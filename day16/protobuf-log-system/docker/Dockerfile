FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY . .

# Generate protobuf code
RUN python -m grpc_tools.protoc \
    --proto_path=proto \
    --python_out=proto \
    --grpc_python_out=proto \
    proto/log_entry.proto

# Create log directories
RUN mkdir -p logs/{json,protobuf}

# Run performance tests by default
CMD ["python", "src/performance_tester.py"]
