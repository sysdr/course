# collector/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY collector.py /app/

# Create required directories
RUN mkdir -p /logs /data/collected

CMD ["python", "collector.py"]