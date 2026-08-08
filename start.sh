#!/bin/sh
set -e

# Default to 8000 if PORT is not set
LISTENING_PORT="${PORT:-8000}"

echo "WeatherSense AI: Starting server on port $LISTENING_PORT"

# Use exec to replace the shell process with uvicorn
exec uvicorn backend.app.main:app --host 0.0.0.0 --port "$LISTENING_PORT"
