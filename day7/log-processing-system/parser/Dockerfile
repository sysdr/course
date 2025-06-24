# parser/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY parser.py /app/

# Create required directories
RUN mkdir -p /data/collected /data/parsed

CMD ["python", "parser.py"]