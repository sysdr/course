# query/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY query.py web_interface.py /app/

# Install Flask
RUN pip install flask

# Create required directories
RUN mkdir -p /data/storage

# Expose port for web interface
EXPOSE 8000

CMD ["python", "web_interface.py"]