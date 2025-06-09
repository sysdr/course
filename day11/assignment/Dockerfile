# assignment/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY assignment/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY assignment/ ./

ENTRYPOINT ["python", "-m", "demo.demo_app"]
CMD ["--server-host=log-server", "--batch-size=100", "--batch-interval=5.0", "--logs-per-second=10.0"]