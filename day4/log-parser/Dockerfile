# Use Python 3.9 slim image as base
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy our log parser files
COPY ../src/log_parser.py /app/
COPY ../src/log_parser_demo.py /app/

# Make the demo script executable
RUN chmod +x /app/log_parser_demo.py

# Create a directory for logs
RUN mkdir -p /logs

# Entry point
ENTRYPOINT ["python3", "log_parser_demo.py"]
