FROM python:3.11-slim

WORKDIR /app

# Install build dependencies for psutil
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
COPY src ./src
COPY web ./web

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 5000

CMD ["python", "src/main/web_app.py"]
