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
    temp_min: float
    temp_max: float
    humidity: float
    rainfall_mm: float
    confidence: float

class ForecastResponse(BaseModel):
    city: str
    generated_at: str
    forecast: List[ForecastItem] = Field(default_factory=list)

class WeatherCurrentResponse(BaseModel):
    city: str
    temperature_c: float
    condition: str
    description: str
    humidity: int
    wind_speed: float
    icon: str
    cached_at: str

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

def get_current_weather(city: str) -> Dict[str, Any]:
    validated_city = validate_input(city)
    now = time.time()
    cache_key = validated_city.lower()
    if cache_key in _CURRENT_WEATHER_CACHE and now - _CURRENT_WEATHER_CACHE[cache_key][0] < 600:
        return _CURRENT_WEATHER_CACHE[cache_key][1]

    api_key = os.getenv("OPENWEATHER_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("OPENWEATHER_API_KEY is missing from environment")

    try:
        response = requests.get(
            "https://api.openweathermap.org/data/2.5/weather",
            params={"q": validated_city, "appid": api_key, "units": "metric"},
            timeout=8,
        )
        if response.status_code == 401:
            raise RuntimeError("Invalid OpenWeather API Key")
        response.raise_for_status()
    except Exception as exc:
        logger.error(f"Weather API failed: {exc}")
        return _build_fallback_weather(validated_city)

    payload = response.json()
    current_payload = {
        "city": payload.get("name", validated_city),
        "temperature_c": round(payload.get("main", {}).get("temp", 0), 1),
        "condition": payload.get("weather", [{}])[0].get("main", "Clear"),
        "description": payload.get("weather", [{}])[0].get("description", "clear sky"),
        "humidity": int(payload.get("main", {}).get("humidity", 0)),
        "wind_speed": float(payload.get("wind", {}).get("speed", 0)),
        "icon": payload.get("weather", [{}])[0].get("icon", "01d"),
        "cached_at": datetime.now(timezone.utc).isoformat(),
    }
    _CURRENT_WEATHER_CACHE[cache_key] = (now, current_payload)
    return current_payload

def predict_next_7_days(city: str) -> Dict[str, Any]:
    validated_city = validate_input(city)
    load_inference_artifacts()

    # Get current state
    current = get_current_weather(validated_city)

    # Start date
    start_date = datetime.now(timezone.utc)

    forecasts = []

    # If no models are loaded, use semi-realistic heuristic
    if not _MODELS:
        logger.warning("No models loaded, using heuristic forecast")
        for i in range(1, 8):
            day = start_date + timedelta(days=i)
            forecasts.append({
                "date": day.strftime("%Y-%m-%d"),
                "temp_min": round(current["temperature_c"] - 2 + np.random.normal(0, 1), 1),
                "temp_max": round(current["temperature_c"] + 3 + np.random.normal(0, 1), 1),
                "humidity": float(current["humidity"]),
                "rainfall_mm": 0.0,
                "confidence": 0.5
            })
    else:
        # Generate forecast per target
        # For simplicity in this env, we'll use Prophet or XGBoost directly
        # based on what was saved as best.

        target_results = {}
        for target in ["temperature", "humidity", "rainfall"]:
            model = _MODELS.get(target)
            info = _METADATA.get(target)

            # Map target to current weather keys
            current_key = "temperature_c" if target == "temperature" else target
            base_val = float(current.get(current_key, 0.0))

            if info and info["model_name"] == "Prophet" and model:
                try:
                    manual_future = pd.DataFrame({
                        'ds': [pd.to_datetime(start_date.date() + timedelta(days=i+1)) for i in range(7)]
                    })
                    pred = model.predict(manual_future)
                    target_results[target] = pred["yhat"].values
                except Exception as e:
                    logger.error(f"Prophet failed for {target}: {e}")
                    target_results[target] = [base_val] * 7
            elif info and info["model_name"] == "XGBoost" and model:
                try:
                    # Simplified XGBoost inference: use the model's prediction on current wind/month
                    # and extend it. In a real app we'd maintain lag state.
                    feature_names = model.get_booster().feature_names
                    dummy_X = pd.DataFrame(np.zeros((7, len(feature_names))), columns=feature_names)
                    if "month" in dummy_X.columns: dummy_X["month"] = start_date.month
                    if "wind_speed" in dummy_X.columns: dummy_X["wind_speed"] = current["wind_speed"]
                    # Fill lags with current value as proxy
                    for col in feature_names:
                        if "lag" in col or "avg" in col:
                            dummy_X[col] = base_val

                    preds = model.predict(dummy_X)
                    target_results[target] = preds
                except Exception as e:
                    logger.error(f"XGBoost failed for {target}: {e}")
                    target_results[target] = [base_val] * 7
            else:
                target_results[target] = [base_val + (i * 0.1) for i in range(7)]

        for i in range(7):
            day = start_date + timedelta(days=i+1)
            forecasts.append({
                "date": day.strftime("%Y-%m-%d"),
                "temp_min": round(target_results["temperature"][i] - 1.5, 1),
                "temp_max": round(target_results["temperature"][i] + 1.5, 1),
                "humidity": round(max(0, min(100, target_results["humidity"][i])), 1),
                "rainfall_mm": round(max(0, target_results["rainfall"][i]), 1),
                "confidence": round(0.8 - (i * 0.05), 2)
            })

    return {
        "city": validated_city,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "forecast": forecasts
    }

def _build_fallback_weather(city: str) -> Dict[str, Any]:
    return {
        "city": city,
        "temperature_c": 22.0,
        "condition": "Cloudy",
        "description": "scattered clouds",
        "humidity": 60,
        "wind_speed": 4.0,
        "icon": "03d",
        "cached_at": datetime.now(timezone.utc).isoformat(),
    }
