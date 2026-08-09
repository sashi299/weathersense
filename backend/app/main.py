import logging
import os
import traceback
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

try:
    from app.services.forecast_service import ForecastService
except ImportError:  # pragma: no cover - support running from repository root
    from backend.app.services.forecast_service import ForecastService

try:
    from backend.ml.analytics import generate_analytics_report
    from backend.ml.inference import ForecastResponse, WeatherCurrentResponse, get_api_key, get_current_weather, predict_next_7_days, validate_input, reverse_geocode
except ImportError:  # pragma: no cover - support running from backend directory
    from ml.analytics import generate_analytics_report
    from ml.inference import ForecastResponse, WeatherCurrentResponse, get_api_key, get_current_weather, predict_next_7_days, validate_input, reverse_geocode

load_dotenv()

logger = logging.getLogger("weather_api")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")

app = FastAPI(title="WeatherSense API", version="0.1.0")

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled Exception: %s", exc)
    logger.error(traceback.format_exc())
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "error_type": type(exc).__name__},
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SERVICE = ForecastService()
# Load key from environment, ensure it is set
ADMIN_KEY = os.getenv("ADMIN_KEY", "")


@app.get("/health")
def health() -> dict:
    api_key = get_api_key()
    if not api_key:
        return {
            "status": "degraded",
            "reason": "Configuration error: OPENWEATHER_API_KEY is missing",
            "action": "Please set OPENWEATHER_API_KEY in your environment variables."
        }
    return {"status": "ok", "service": "WeatherSense", "config": "verified"}


@app.get("/current", response_model=WeatherCurrentResponse)
def get_current(
    city: str = Query(..., min_length=2),
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None)
) -> WeatherCurrentResponse:
    logger.info("GET /current city=%s lat=%s lon=%s", city, lat, lon)
    try:
        validated_city = validate_input(city)
        payload = get_current_weather(validated_city, lat=lat, lon=lon)
        return WeatherCurrentResponse(**payload)
    except ValueError as exc:
        # Catch validation or configuration errors (like missing/invalid API key)
        logger.warning("Configuration or input error: %s", exc)
        status_code = 401 if "API Key" in str(exc) else 400
        raise HTTPException(status_code=status_code, detail=str(exc)) from exc
    except TimeoutError as exc:
        logger.error("Current weather request timed out: %s", exc)
        raise HTTPException(status_code=504, detail="Weather API request timed out") from exc
    except RuntimeError as exc:
        logger.error("Current weather request failed: %s", exc)
        # 503 is more appropriate for upstream failures than 502 in many cases,
        # but let's keep it clear.
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.get("/forecast", response_model=ForecastResponse)
def get_forecast(
    city: str = Query(..., min_length=2),
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None)
) -> ForecastResponse:
    logger.info("GET /forecast city=%s lat=%s lon=%s", city, lat, lon)
    try:
        validated_city = validate_input(city)
        payload = predict_next_7_days(validated_city, lat=lat, lon=lon)
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
    except Exception as exc:
        logger.error("Unexpected forecast error: %s", exc)
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Internal forecasting error") from exc


@app.get("/analytics")
def get_analytics() -> dict:
    logger.info("GET /analytics")
    try:
        report = generate_analytics_report()
        # Even if there's an error field, return 200 with fallback insights
        return report
    except Exception as exc:
        logger.error("Analytics generation failed: %s", exc)
        return {
            "dataset_summary": {"total_records": 0, "cities": [], "date_range": [], "features": []},
            "model_metrics": [],
            "best_models": {},
            "ai_insights": [{"icon": "error", "title": "Analytics Offline", "explanation": "Statistical data is currently being re-indexed.", "status": "Busy"}]
        }


@app.get("/search")
def search_cities(q: str = Query(..., min_length=2)) -> list:
    logger.info("GET /search q=%s", q)
    try:
        api_key = get_api_key()
        if not api_key:
            logger.error("Search failed: OPENWEATHER_API_KEY is missing")
            return []

        # Debugging what is being sent
        logger.info("Calling OWM Search for: '%s' with key: %s...", q, api_key[:4])
        url = "https://api.openweathermap.org/geo/1.0/direct"
        params = {"q": q, "limit": 5, "appid": api_key}
        res = requests.get(url, params=params, timeout=5)

        if res.status_code == 200:
            results = res.json()
            logger.info("OWM returned %d results for '%s'", len(results), q)
            return results

        logger.error("OWM returned status %d", res.status_code)
        return []

        logger.error("Search API returned %s: %s", res.status_code, res.text)
        return []
    except Exception as exc:
        logger.error("Search failed for %s: %s", q, exc)
        return []

@app.get("/reverse")
def reverse_geo(lat: float, lon: float) -> dict:
    logger.info("GET /reverse lat=%s lon=%s", lat, lon)
    try:
        return reverse_geocode(lat, lon)
    except Exception as exc:
        logger.error("Reverse geo failed: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/train")
def train_model(admin_key: Optional[str] = Header(default=None)) -> dict:
    if ADMIN_KEY and admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="Admin access required")

    result = SERVICE.train(city="global")
    return result
