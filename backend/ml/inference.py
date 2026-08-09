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
    resolution: str = "hourly"
    model: str = "AI-Model"

class WeatherCurrentResponse(BaseModel):
    city: str
    state: Optional[str] = None
    country: str
    lat: Optional[float] = None
    lon: Optional[float] = None
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

def reverse_geocode(lat: float, lon: float) -> Dict[str, Any]:
    """Resolve coordinates to a human-readable location using OpenWeather Geocoding API."""
    api_key = get_api_key()
    if not api_key:
        raise ValueError("API Key missing")

    try:
        url = "https://api.openweathermap.org/geo/1.0/reverse"
        res = requests.get(url, params={"lat": lat, "lon": lon, "limit": 1, "appid": api_key}, timeout=5)
        res.raise_for_status()
        data = res.json()
        if not data:
            return {"name": f"{lat:.2f}, {lon:.2f}", "country": "Unknown", "lat": lat, "lon": lon}

        location = data[0]
        return {
            "name": location.get("name"),
            "state": location.get("state"),
            "country": location.get("country"),
            "lat": lat,
            "lon": lon
        }
    except Exception as e:
        logger.error(f"Reverse geocoding failed: {e}")
        return {"name": f"{lat:.2f}, {lon:.2f}", "country": "Error", "lat": lat, "lon": lon}

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

def get_current_weather(city: str, lat: Optional[float] = None, lon: Optional[float] = None) -> Dict[str, Any]:
    validated_city = validate_input(city)
    now = time.time()

    # Use coordinates in cache key if provided to avoid collisions for same-named cities
    cache_key = f"{validated_city.lower()}_{lat}_{lon}" if lat is not None else validated_city.lower()

    if cache_key in _CURRENT_WEATHER_CACHE and now - _CURRENT_WEATHER_CACHE[cache_key][0] < 600:
        return _CURRENT_WEATHER_CACHE[cache_key][1]

    api_key = get_api_key()
    if not api_key:
        raise ValueError("OPENWEATHER_API_KEY is missing from environment. Please set it in your configuration.")

    display_name, state, country = validated_city, None, "Unknown"

    # 1. Resolve City via Geocoding API if lat/lon not provided
    if lat is None or lon is None:
        try:
            geo_res = requests.get(
                "https://api.openweathermap.org/geo/1.0/direct",
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
            if "not found" in str(exc): raise
            # Fallback to direct weather search if geo fails
            lat, lon, display_name, state, country = None, None, validated_city, None, "Unknown"
    else:
        # If lat/lon provided, we can optionally reverse geocode or just use provided city name
        # For simplicity, we'll trust the provided name or fetch it if needed.
        # But we must have lat/lon for the actual weather call.
        display_name = validated_city

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

    # Extract basic info
    timezone_offset = payload.get("timezone", 0)
    coord = payload.get("coord", {})
    lat, lon = coord.get("lat"), coord.get("lon")

    # Extract condition for animation mapping
    main_weather = payload.get("weather", [{}])[0].get("main", "Clear")
    weather_id = payload.get("weather", [{}])[0].get("id", 800)

    # Map to internal conditions
    if 200 <= weather_id <= 232:
        condition = "Thunderstorm"
    elif 300 <= weather_id <= 531:
        condition = "Rainy"
    elif 600 <= weather_id <= 622:
        condition = "Snowy"
    elif weather_id == 800:
        # Determine day/night based on local time
        local_hour = (datetime.now(timezone.utc).hour + (timezone_offset // 3600)) % 24
        condition = "Sunny" if 6 <= local_hour <= 18 else "Clear Night"
    else:
        condition = main_weather

    # Formatting helpers
    def format_time(ts):
        dt = datetime.fromtimestamp(ts, timezone.utc) + timedelta(seconds=timezone_offset)
        return dt.strftime("%H:%M")

    # Fetch Air Quality
    air_quality = "Moderate"
    if lat is not None and lon is not None:
        try:
            aq_res = requests.get(
                "https://api.openweathermap.org/data/2.5/air_pollution",
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
        "lat": lat,
        "lon": lon,
        "temperature_c": round(payload.get("main", {}).get("temp", 0), 1),
        "condition": condition,
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

def predict_next_7_days(city: str, lat: Optional[float] = None, lon: Optional[float] = None) -> Dict[str, Any]:
    validated_city = validate_input(city)
    load_inference_artifacts()

    # 1. Get current state as the starting point
    current = get_current_weather(validated_city, lat=lat, lon=lon)
    current_temp = current["temperature_c"]
    current_hum = current["humidity"]
    current_rain = 0.0 # Today's rain so far (not used as lag here)

    # 2. Generate 7 Days of Daily AI Predictions using XGBoost
    # To predict 7 days, we'll use the current weather to initialize lags
    # and then recursively predict each day.

    daily_predictions = []

    # Initialize history with current data (Day 0)
    # Using current weather to fill lag_1
    history = {
        "temp": [current_temp] * 7, # Simplified history for lags
        "hum": [current_hum] * 7,
        "rain": [0.0] * 7
    }

    start_dt = datetime.now(timezone.utc)

    for d in range(1, 8):
        target_date = start_dt + timedelta(days=d)

        # Build features for this day
        # Order: day_of_week, month, quarter, sin_day_of_year, cos_day_of_year,
        # temperature_lag_1, temperature_lag_3, temperature_lag_7,
        # humidity_lag_1, rainfall_lag_1,
        # temperature_3day_avg, temperature_7day_avg, humidity_7day_avg, rainfall_7day_avg,
        # temperature_7day_std, temperature_difference

        day_of_year = target_date.timetuple().tm_yday
        features = [
            float(current.get("wind_speed", 3.0)), # wind_speed
            float(current.get("pressure", 1013.0)), # pressure
            target_date.weekday(), # day_of_week
            target_date.month,
            (target_date.month - 1) // 3 + 1, # quarter
            np.sin(2 * np.pi * day_of_year / 365),
            np.cos(2 * np.pi * day_of_year / 365),
            history["temp"][-1], # lag_1
            history["temp"][-3], # lag_3
            history["temp"][-7], # lag_7
            history["hum"][-1],  # hum lag_1
            history["rain"][-1], # rain lag_1
            np.mean(history["temp"][-3:]), # 3day avg
            np.mean(history["temp"]),      # 7day avg
            np.mean(history["hum"]),       # 7day hum avg
            np.mean(history["rain"]),      # 7day rain avg
            np.std(history["temp"]),       # 7day std
            history["temp"][-1] - history["temp"][-2] # temp diff
        ]

        X = np.array([features])

        # Use AI models
        p_temp = float(_MODELS["temperature"].predict(X)[0]) if "temperature" in _MODELS else 25.0
        p_hum = float(_MODELS["humidity"].predict(X)[0]) if "humidity" in _MODELS else 60.0
        p_rain = float(_MODELS["rainfall"].predict(X)[0]) if "rainfall" in _MODELS else 0.0

        # Bound sanity
        p_hum = max(10, min(100, p_hum))
        p_rain = max(0, p_rain)

        daily_predictions.append({
            "date": target_date.strftime("%Y-%m-%d"),
            "temp_avg": p_temp,
            "hum_avg": p_hum,
            "rain_total": p_rain
        })

        # Update history for next day prediction
        history["temp"].append(p_temp)
        history["temp"].pop(0)
        history["hum"].append(p_hum)
        history["hum"].pop(0)
        history["rain"].append(p_rain)
        history["rain"].pop(0)

    # 3. Generate 168 Hourly points (Interpolated and Clamped)
    # We anchor the curve at Hour 0 = Current Temp
    # And we follow the AI-predicted daily trend.

    forecasts = []

    for i in range(1, 169):
        target_time = start_dt + timedelta(hours=i)
        day_idx = i // 24 if i % 24 != 0 else (i // 24) - 1
        day_idx = min(day_idx, 6)

        daily_ai = daily_predictions[day_idx]

        # Diurnal Cycle Model
        # Peak usually at 3-4 PM (Hour 15), Minimum at 5-6 AM (Hour 5)
        hour = target_time.hour
        # Amplitude of variation (approx 4-6 degrees)
        amplitude = 5.0
        cycle = -np.cos((hour - 5) * (2 * np.pi / 24)) * amplitude

        # Baseline is the AI-predicted daily average
        # Target Temp = AI Average + Diurnal offset (centered around avg)
        target_temp = daily_ai["temp_avg"] + cycle

        # SMOOTH TRANSITION: Anchor to current weather
        # We apply a weight that decreases over time (Decay anchor)
        # For the first 12 hours, we blend current weather with the AI curve.
        # This prevents the 33C -> 39C jump.

        decay_factor = np.exp(-i / 12) # Influence of current weather drops over 12-18 hours
        # The offset between current weather and the "ideal" model curve at t=0
        ideal_start_cycle = -np.cos((start_dt.hour - 5) * (2 * np.pi / 24)) * amplitude
        initial_offset = current_temp - (daily_predictions[0]["temp_avg"] + ideal_start_cycle)

        predicted_temp = target_temp + (initial_offset * decay_factor)

        # Humidity variation (Inverse of temp)
        predicted_humidity = daily_ai["hum_avg"] - (cycle * 1.5)
        predicted_humidity = max(20, min(100, predicted_humidity))

        # Rainfall (Distribute total rain)
        # If it's a rainy day, show it in the evening/early morning slots
        rainfall = 0.0
        if daily_ai["rain_total"] > 0.5:
            # Simple probability: peak rain at night or early morning
            rain_prob = np.sin((hour) * (2 * np.pi / 24)) + 1.0 # 0 to 2
            if rain_prob > 1.5:
                rainfall = round(daily_ai["rain_total"] / 4.0, 1)

        # Condition logic
        condition = "Clear"
        if rainfall > 0.5: condition = "Rainy"
        elif predicted_humidity > 85: condition = "Overcast"
        elif predicted_humidity > 70: condition = "Cloudy"
        else:
            condition = "Sunny" if 6 <= hour <= 18 else "Clear Night"

        forecasts.append({
            "date": target_time.strftime("%Y-%m-%d"),
            "time": target_time.strftime("%H:%M"),
            "temp": round(float(predicted_temp), 1),
            "humidity": round(float(predicted_humidity), 1),
            "rainfall_mm": float(rainfall),
            "condition": condition,
            "confidence": round(float(0.9 - (i * 0.002)), 2)
        })

    return {
        "city": validated_city,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "forecast": forecasts,
        "resolution": "hourly",
        "model": "XGBoost-Recursive"
    }

def _build_fallback_weather(city: str) -> Dict[str, Any]:
    return {
        "city": city,
        "state": "Fallback",
        "country": "Unknown",
        "lat": 0.0,
        "lon": 0.0,
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
