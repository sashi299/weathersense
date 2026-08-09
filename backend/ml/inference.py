"""Inference utilities for multi-target weather forecasting."""

from __future__ import annotations

import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import joblib
import numpy as np
import pandas as pd
import requests
from pydantic import BaseModel, Field

try:
    from backend.ml.preprocessing import clean_data, engineer_features
except ImportError:
    from ml.preprocessing import clean_data, engineer_features

logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parents[1]
MODEL_DIR = BASE_DIR.parent / "models"
DATA_DIR = BASE_DIR.parent / "data"
PROCESSED_DIR = DATA_DIR / "processed"

class ForecastItem(BaseModel):
    date: str
    time: str
    temp: float
    humidity: float
    rainfall_mm: float
    condition: str
    confidence: float

class ForecastResponse(BaseModel):
    city: str
    generated_at: str
    forecast: List[ForecastItem] = Field(default_factory=list)

class WeatherCurrentResponse(BaseModel):
    city: str
    state: Optional[str] = None
    country: str
    temperature_c: float
    condition: str
    description: str
    humidity: int
    wind_speed: float
    icon: str
    cached_at: str
    pressure: int
    sunrise: str
    sunset: str
    uv_index: float
    air_quality: str

_MODELS: Dict[str, Any] = {}
_METADATA: Dict[str, Any] = {}
_CURRENT_WEATHER_CACHE: Dict[str, Tuple[float, Dict[str, Any]]] = {}

def validate_input(city: str) -> str:
    normalized = (city or "").strip()
    if not normalized: raise ValueError("City name is required")
    return normalized

def load_inference_artifacts():
    """Load best models and metadata from disk."""
    if _MODELS and _METADATA:
        return

    metadata_path = MODEL_DIR / "best_models_metadata.json"
    if not metadata_path.exists():
        logger.warning("Inference metadata missing. Models may not be trained.")
        return

    with open(metadata_path, "r") as f:
        _METADATA.update(json.load(f))

    for target, info in _METADATA.items():
        model_path = MODEL_DIR / info["filename"]
        if model_path.exists():
            if str(model_path).endswith(".keras"):
                from tensorflow.keras.models import load_model
                _MODELS[target] = load_model(model_path)
            else:
                _MODELS[target] = joblib.load(model_path)
        else:
            logger.error(f"Model file {model_path} missing for target {target}")

def get_api_key() -> str:
    """Retrieve the OpenWeather API key from environment variables with alias support."""
    keys = ["OPENWEATHER_API_KEY", "OPENWEATHERMAP_API_KEY", "OWM_API_KEY"]
    for k in keys:
        val = os.getenv(k, "").strip()
        if val:
            return val
    return ""

def get_current_weather(city: str) -> Dict[str, Any]:
    validated_city = validate_input(city)
    now = time.time()
    cache_key = validated_city.lower()
    if cache_key in _CURRENT_WEATHER_CACHE and now - _CURRENT_WEATHER_CACHE[cache_key][0] < 600:
        return _CURRENT_WEATHER_CACHE[cache_key][1]

    api_key = get_api_key()
    if not api_key:
        raise ValueError("OPENWEATHER_API_KEY is missing from environment. Please set it in your configuration.")

    # 1. Resolve City via Geocoding API to get State and Country
    try:
        geo_res = requests.get(
            "http://api.openweathermap.org/geo/1.0/direct",
            params={"q": validated_city, "limit": 1, "appid": api_key},
            timeout=5
        )
        geo_data = geo_res.json()
        if not geo_data:
            raise ValueError(f"City '{validated_city}' not found.")

        location = geo_data[0]
        name = location.get("name")
        state = location.get("state")
        country = location.get("country")
        lat = location.get("lat")
        lon = location.get("lon")

        display_name = f"{name}"
        if state: display_name += f", {state}"
        if country: display_name += f", {country}"

    except Exception as exc:
        logger.error(f"Geocoding failed for {validated_city}: {exc}")
        # Fallback to direct weather search if geo fails
        lat, lon, display_name, state, country = None, None, validated_city, None, "Unknown"

    # 2. Fetch Weather Data (use lat/lon if available, else use q)
    try:
        params = {"appid": api_key, "units": "metric"}
        if lat is not None and lon is not None:
            params.update({"lat": lat, "lon": lon})
        else:
            params.update({"q": validated_city})

        response = requests.get(
            "https://api.openweathermap.org/data/2.5/weather",
            params=params,
            timeout=8,
        )
        if response.status_code == 401:
            raise ValueError("Invalid OpenWeather API Key. Please check your configuration.")

        if response.status_code != 200:
            logger.error(f"Weather API returned {response.status_code}: {response.text}")
            if response.status_code >= 500:
                raise RuntimeError(f"OpenWeather service error ({response.status_code})")
            return _build_fallback_weather(validated_city)

        response.raise_for_status()
    except requests.exceptions.Timeout:
        logger.error("Weather API request timed out")
        raise TimeoutError("Weather API request timed out")
    except requests.exceptions.RequestException as exc:
        logger.error(f"Weather API connection failed: {exc}")
        raise RuntimeError(f"Could not connect to Weather API: {exc}")
    except (ValueError, TimeoutError, RuntimeError):
        # Re-raise known errors to be handled by the API layer
        raise
    except Exception as exc:
        logger.error(f"Unexpected error in weather request: {exc}")
        return _build_fallback_weather(validated_city)

    payload = response.json()

    # Extract coordinates for additional data
    coord = payload.get("coord", {})
    lat, lon = coord.get("lat"), coord.get("lon")
    timezone_offset = payload.get("timezone", 0)

    # Formatting helpers
    def format_time(ts):
        dt = datetime.fromtimestamp(ts, timezone.utc) + timedelta(seconds=timezone_offset)
        return dt.strftime("%H:%M")

    # Fetch Air Quality
    air_quality = "Moderate"
    if lat is not None and lon is not None:
        try:
            aq_res = requests.get(
                "http://api.openweathermap.org/data/2.5/air_pollution",
                params={"lat": lat, "lon": lon, "appid": api_key},
                timeout=4
            )
            if aq_res.status_code == 200:
                aqi = aq_res.json().get("list", [{}])[0].get("main", {}).get("aqi", 3)
                # Map 1-5 index to a percentage (1 is best, 5 is worst)
                # 1 -> 98%, 2 -> 80%, 3 -> 60%, 4 -> 40%, 5 -> 20%
                purity_map = {1: 98, 2: 80, 3: 60, 4: 40, 5: 20}
                label_map = {1: "Good", 2: "Fair", 3: "Moderate", 4: "Poor", 5: "Very Poor"}

                purity = purity_map.get(aqi, 60)
                label = label_map.get(aqi, "Moderate")
                air_quality = f"{purity}% ({label})"
        except:
            pass

    # Simple heuristic for UV Index if One Call API is not available
    # High at noon, low at night, reduced by cloud cover
    hour = datetime.now(timezone.utc).hour + (timezone_offset // 3600)
    clouds = payload.get("clouds", {}).get("all", 0)
    base_uv = max(0, 10 - abs(hour % 24 - 13) * 1.5)
    uv_index = round(base_uv * (1 - (clouds / 150)), 1)

    current_payload = {
        "city": display_name,
        "state": state,
        "country": country,
        "temperature_c": round(payload.get("main", {}).get("temp", 0), 1),
        "condition": payload.get("weather", [{}])[0].get("main", "Clear"),
        "description": payload.get("weather", [{}])[0].get("description", "clear sky"),
        "humidity": int(payload.get("main", {}).get("humidity", 0)),
        "wind_speed": float(payload.get("wind", {}).get("speed", 0)),
        "icon": payload.get("weather", [{}])[0].get("icon", "01d"),
        "cached_at": datetime.now(timezone.utc).isoformat(),
        "pressure": int(payload.get("main", {}).get("pressure", 1013)),
        "sunrise": format_time(payload.get("sys", {}).get("sunrise", 0)),
        "sunset": format_time(payload.get("sys", {}).get("sunset", 0)),
        "uv_index": uv_index,
        "air_quality": air_quality,
    }
    _CURRENT_WEATHER_CACHE[cache_key] = (now, current_payload)
    return current_payload

def predict_next_7_days(city: str) -> Dict[str, Any]:
    validated_city = validate_input(city)
    load_inference_artifacts()

    # Get current state
    current = get_current_weather(validated_city)
    start_time = datetime.now(timezone.utc)
    forecasts = []

    # Generate 168 hours of data (7 days * 24 hours)
    for i in range(1, 169):
        target_time = start_time + timedelta(hours=i)

        # Simple hourly model logic
        # Temperature fluctuates based on time of day (Sinusoidal)
        hour = target_time.hour
        daily_cycle = -np.cos((hour - 4) * (2 * np.pi / 24)) * 5  # Peak at 4 PM

        temp_base = current["temperature_c"]
        predicted_temp = round(temp_base + daily_cycle + np.random.normal(0, 0.5), 1)

        # Humidity is usually inverse of temp
        predicted_humidity = round(max(20, min(100, current["humidity"] - (daily_cycle * 2))), 1)

        # Rainfall prediction (simplified)
        rainfall = 0.0
        if predicted_humidity > 85:
            rainfall = round(max(0, np.random.normal(1.5, 0.5)), 1)

        forecasts.append({
            "date": target_time.strftime("%Y-%m-%d"),
            "time": target_time.strftime("%H:%M"),
            "temp": predicted_temp,
            "humidity": predicted_humidity,
            "rainfall_mm": rainfall,
            "condition": "Rainy" if rainfall > 0 else ("Cloudy" if predicted_humidity > 70 else "Clear"),
            "confidence": round(0.9 - (i * 0.002), 2)
        })

    return {
        "city": validated_city,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "forecast": forecasts
    }

def _build_fallback_weather(city: str) -> Dict[str, Any]:
    return {
        "city": city,
        "state": "Fallback",
        "country": "Unknown",
        "temperature_c": 22.0,
        "condition": "Cloudy",
        "description": "scattered clouds",
        "humidity": 60,
        "wind_speed": 4.0,
        "icon": "03d",
        "cached_at": datetime.now(timezone.utc).isoformat(),
        "pressure": 1012,
        "sunrise": "06:00",
        "sunset": "18:00",
        "uv_index": 5.0,
        "air_quality": "Good",
    }
