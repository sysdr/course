# Dockerfile (root)
FROM python:3.9-slim

WORKDIR /app

# Install required packages
RUN pip install pyyaml

# Copy component files
COPY generator/generator.py /app/generator/
COPY collector/collector.py /app/collector/
COPY parser/parser.py /app/parser/
COPY storage/storage.py /app/storage/
COPY query/query.py /app/query/
COPY integration/pipeline.py /app/integration/
COPY integration/config.yml /app/integration/

# Create required directories
RUN mkdir -p /logs /data/collected /data/parsed /data/storage /data/storage/index /data/storage/active /data/storage/archive

# Expose port for potential web interface
EXPOSE 8000

# Set the entrypoint
CMD ["python", "/app/integration/pipeline.py"]