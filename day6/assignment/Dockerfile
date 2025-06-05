FROM python:3.9-slim

WORKDIR /app

COPY advanced_log_query.py .
RUN chmod +x advanced_log_query.py

# Create directory for logs
RUN mkdir -p /logs

ENTRYPOINT ["./advanced_log_query.py"]
CMD ["/logs/*.log"]
