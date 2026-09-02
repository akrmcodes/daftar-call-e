# Custom FastAPI entrypoint: ADK /run + send-batch + POST /v1/tts + plan-batch.
# Built by `gcloud run deploy --source` from agent/. Do not `adk deploy`.
FROM python:3.12-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app:/app/adk_apps

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
COPY email_send ./email_send
COPY tts ./tts
COPY calls ./calls
COPY closing_agent ./adk_apps/closing_agent

EXPOSE 8000

CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
