FROM python:3.11-slim

WORKDIR /app

# Install system build dependencies for Python ML libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY backend ./backend
COPY data ./data
COPY models ./models
COPY reports ./reports
RUN mkdir -p /app/models /app/plots /app/reports

EXPOSE 8000
COPY start.sh ./start.sh
RUN chmod +x ./start.sh

# Entrypoint script handles dynamic PORT expansion for Render
CMD ["./start.sh"]
