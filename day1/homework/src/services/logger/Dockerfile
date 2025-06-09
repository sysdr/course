
FROM python:3.9-slim

WORKDIR /app

# Copy just the requirements.txt first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create logs directory if it doesn't exist
RUN mkdir -p /logs

# Make sure the directory is writable
RUN chmod -R 755 /logs

# Run the application
ENTRYPOINT ["python", "-u"]
CMD ["app.py"]