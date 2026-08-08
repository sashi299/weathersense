import logging
import os
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

try:
    from app.services.forecast_service import ForecastService
except ImportError:  # pragma: no cover - support running from repository root
    from backend.app.services.forecast_service import ForecastService

try:
    from backend.ml.analytics import generate_analytics_report
    from backend.ml.inference import ForecastResponse, WeatherCurrentResponse, get_current_weather, predict_next_7_days, validate_input
except ImportError:  # pragma: no cover - support running from backend directory
    from ml.analytics import generate_analytics_report
    from ml.inference import ForecastResponse, WeatherCurrentResponse, get_current_weather, predict_next_7_days, validate_input

load_dotenv()

logger = logging.getLogger("weather_api")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")

app = FastAPI(title="WeatherSense API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SERVICE = ForecastService()
# Load key from environment, ensure it is set
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY", "").strip()
ADMIN_KEY = os.getenv("ADMIN_KEY", "")


@app.get("/health")
def health() -> dict:
    if not OPENWEATHER_API_KEY:
        return {"status": "degraded", "reason": "OPENWEATHER_API_KEY is missing"}
    return {"status": "ok", "service": "WeatherSense"}


@app.get("/current", response_model=WeatherCurrentResponse)
def get_current(city: str = Query(..., min_length=2)) -> WeatherCurrentResponse:
    logger.info("GET /current city=%s", city)
    try:
        validated_city = validate_input(city)
        payload = get_current_weather(validated_city)
        return WeatherCurrentResponse(**payload)
    except ValueError as exc:
        logger.warning("Invalid city: %s", exc)
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except TimeoutError as exc:
        logger.error("Current weather request timed out: %s", exc)
        raise HTTPException(status_code=504, detail="Weather API request timed out") from exc
    except RuntimeError as exc:
        logger.error("Current weather request failed: %s", exc)
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.get("/forecast", response_model=ForecastResponse)
def get_forecast(city: str = Query(..., min_length=2)) -> ForecastResponse:
    logger.info("GET /forecast city=%s", city)
    try:
        validated_city = validate_input(city)
        payload = predict_next_7_days(validated_city)
        return ForecastResponse(**payload)
    except ValueError as exc:
        logger.warning("Forecast input error: %s", exc)
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except FileNotFoundError as exc:
        logger.error("Forecast model files missing: %s", exc)
        raise HTTPException(status_code=500, detail="Trained models are not available") from exc
    except RuntimeError as exc:
        logger.error("Forecast inference failed: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/analytics")
def get_analytics() -> dict:
    logger.info("GET /analytics")
    try:
        report = generate_analytics_report()
        return report
    except Exception as exc:
        logger.error("Analytics generation failed: %s", exc)
        raise HTTPException(status_code=500, detail="Analytics report could not be generated") from exc


@app.post("/train")
def train_model(admin_key: Optional[str] = Header(default=None)) -> dict:
    if ADMIN_KEY and admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="Admin access required")

    result = SERVICE.train(city="global")
    return result
