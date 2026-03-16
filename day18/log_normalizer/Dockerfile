FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY tests/ ./tests/
COPY sample_logs/ ./sample_logs/
COPY test_integration.py .
COPY performance_test.py .

CMD ["python", "-m", "pytest", "tests/", "-v"]
