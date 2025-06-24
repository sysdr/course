FROM python:3.10-slim

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ src/
COPY sample_logs.txt .

# Environment variables for configuration
ENV LOG_FILE=/app/sample_logs.txt
ENV SERVER_HOST=log-server
ENV SERVER_PORT=9000
ENV SHIPPING_MODE=continuous

# Run the log shipper
CMD python -m src.main --log-file $LOG_FILE --server-host $SERVER_HOST --server-port $SERVER_PORT $([ "$SHIPPING_MODE" = "batch" ] && echo "--batch")