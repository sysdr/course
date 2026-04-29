FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/  ./src/
COPY static/ ./static/
RUN mkdir -p logs
ENV LOG_FILE=/app/logs/app.log
ENV PORT=5170
EXPOSE 5170
CMD ["python3", "src/api_server.py"]
