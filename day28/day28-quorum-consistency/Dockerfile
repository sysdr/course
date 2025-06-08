FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --only-binary=all -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "src.web_interface:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
