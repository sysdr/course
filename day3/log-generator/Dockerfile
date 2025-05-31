FROM python:3.9-slim

WORKDIR /app

COPY log_generator.py .

RUN chmod +x log_generator.py

ENTRYPOINT ["python", "log_generator.py"]
CMD ["--file", "/app/logs/application.log", "--rate", "1", "--type", "json"]
