FROM python:3.9-slim

WORKDIR /app

COPY log_query.py .
RUN chmod +x log_query.py

# Create directory for logs
RUN mkdir -p /logs

ENTRYPOINT ["./log_query.py"]
CMD ["/logs/app.log"]