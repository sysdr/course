FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8175
CMD ["uvicorn", "src.api.server:app", "--host", "0.0.0.0", "--port", "8175"]
