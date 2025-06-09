# storage/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY storage.py /app/

# Create required directories
RUN mkdir -p /data/parsed /data/storage /data/storage/index /data/storage/active /data/storage/archive

CMD ["python", "storage.py"]