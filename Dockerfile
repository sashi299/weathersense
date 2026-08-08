FROM python:3.11-slim

WORKDIR /app
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY backend ./backend
COPY data ./data
COPY models ./models
EXPOSE 8000
# Use shell form to allow environment variable expansion (required for Railway's $PORT)
CMD uvicorn backend.app.main:app --host 0.0.0.0 --port ${PORT:-8000}
