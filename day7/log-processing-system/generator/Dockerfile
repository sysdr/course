# generator/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY generator.py /app/

# Create directory for logs
RUN mkdir -p /logs

CMD ["python", "generator.py"]