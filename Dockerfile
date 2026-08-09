FROM python:3.11-slim

WORKDIR /app
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY backend ./backend
COPY data ./data
COPY models ./models
COPY reports ./reports
EXPOSE 8000
COPY start.sh ./start.sh
RUN chmod +x ./start.sh

# Entrypoint script handles dynamic PORT expansion for Railway/Render
CMD ["./start.sh"]
