FROM python:3.9-slim

WORKDIR /app

# Copy just the requirements.txt first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create logs directory
RUN mkdir -p /logs

# Copy application code
COPY . .

# Run the application
CMD ["python", "app.py"]