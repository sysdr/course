FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY demo/ ./demo/
COPY tests/ ./tests/

# Expose port for web dashboard
EXPOSE 8080

# Run the web dashboard
CMD ["python", "demo/web_dashboard.py"]
