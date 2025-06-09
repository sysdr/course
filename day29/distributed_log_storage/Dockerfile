FROM python:3.9-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Create data directories
RUN mkdir -p data/node_a data/node_b data/node_c logs

# Expose port
EXPOSE 5000

# Run application
CMD ["python", "main.py"]
