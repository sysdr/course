FROM python:3.9-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the log collector script
COPY log_collector.py .

# Create directories for logs
RUN mkdir -p /app/logs /app/collected_logs

# Set default command
ENTRYPOINT ["python", "log_collector.py"]
CMD ["--log-files", "/app/logs/app.log", "--output-dir", "/app/collected_logs"]
