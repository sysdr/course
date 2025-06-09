# query/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY query.py /app/

# Create required directories
RUN mkdir -p /data/storage

CMD ["python", "query.py"]