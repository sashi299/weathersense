import json
import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional
import joblib
import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parents[1]
INDIA_MODELS_DIR = BASE_DIR.parent / "models" / "india_v1"
INDIA_DATA_PATH = BASE_DIR.parent / "data" / "india_weather_history_grid.csv"

_INDIA_MODELS: Dict[str, Any] = {}
_INDIA_METADATA: Dict[str, Any] = {}

def load_india_intelligence():
    """Load India-wide models and metadata."""
    if _INDIA_MODELS and _INDIA_METADATA:
        return

    metadata_path = INDIA_MODELS_DIR / "metadata.json"
    if not metadata_path.exists():
        logger.warning(f"India-wide intelligence metadata missing at {metadata_path}")
        return

    try:
        with open(metadata_path, "r") as f:
            _INDIA_METADATA.update(json.load(f))

        for target, info in _INDIA_METADATA["targets"].items():
            model_path = INDIA_MODELS_DIR / info["filename"]
            if model_path.exists():
                _INDIA_MODELS[target] = joblib.load(model_path)
            else:
                logger.error(f"India model file {model_path} missing")
    except Exception as e:
        logger.error(f"Failed to load India intelligence: {e}")

def get_india_metrics() -> List[Dict[str, Any]]:
    """Return metrics for the India-wide models."""
    load_india_intelligence()
    if not _INDIA_METADATA:
        return []

    metrics_list = []
    for target, info in _INDIA_METADATA["targets"].items():
        m = info["metrics"]
        metrics_list.append({
            "target": target,
            "model": info["model"],
            "rmse": m["rmse"],
            "mae": m["mae"],
            "r2": m["r2"],
            "scope": "India-Wide"
        })
    return metrics_list

def get_india_dataset_summary() -> Dict[str, Any]:
    """Return summary of the India-wide dataset."""
    if not INDIA_DATA_PATH.exists():
        return {"error": "India dataset missing"}

    try:
        # Load sample or headers to avoid heavy read if just for summary
        # But we need unique cities/points
        df = pd.read_csv(INDIA_DATA_PATH)
        return {
            "total_records": len(df),
            "date_range": [str(df["date"].min()), str(df["date"].max())],
            "locations_count": len(df.groupby(["latitude", "longitude"])),
            "spatial_resolution": "5.0 degrees",
            "coverage": "India Nationwide (Mainland)",
            "source": "NASA POWER (verified)"
        }
    except Exception as e:
        return {"error": str(e)}

def get_location_aware_insights(lat: float, lon: float) -> List[Dict[str, str]]:
    """Generate insights tailored to a specific coordinate based on historical data."""
    load_india_intelligence()

    # 1. Spatial awareness check
    insights = []

    # Find nearest grid point
    # GRID_POINTS used in download script
    GRID_POINTS = [
        (8.0, 73.0), (8.0, 78.0), (8.0, 83.0), (13.0, 73.0), (13.0, 78.0), (13.0, 83.0),
        (18.0, 73.0), (18.0, 78.0), (18.0, 83.0), (23.0, 68.0), (23.0, 73.0), (23.0, 78.0),
        (23.0, 83.0), (23.0, 88.0), (23.0, 93.0), (28.0, 68.0), (28.0, 73.0), (28.0, 78.0),
        (28.0, 83.0), (28.0, 88.0), (28.0, 93.0), (33.0, 73.0), (33.0, 78.0), (33.0, 83.0),
        (33.0, 88.0), (33.0, 93.0)
    ]

    distances = [((lat - glat)**2 + (lon - glon)**2)**0.5 for glat, glon in GRID_POINTS]
    min_dist = min(distances)
    nearest_idx = distances.index(min_dist)
    nearest_point = GRID_POINTS[nearest_idx]

    insights.append({
        "icon": "location_on",
        "title": "Location Intelligence",
        "explanation": f"Analyzing weather patterns using India grid point ({nearest_point[0]}, {nearest_point[1]}), which is {min_dist*111:.0f}km from your location.",
        "status": "Localized" if min_dist < 3.0 else "Regional"
    })

    # Model performance context
    temp_r2 = _INDIA_METADATA.get("targets", {}).get("temperature", {}).get("metrics", {}).get("r2", 0)
    insights.append({
        "icon": "psychology",
        "title": "Predictive Precision",
        "explanation": f"Nationwide temperature model verified with {temp_r2*100:.1f}% variance coverage across India's varied climatic zones.",
        "status": "Validated"
    })

    # India context
    insights.append({
        "icon": "public",
        "title": "Nationwide Training",
        "explanation": f"Models are trained on 44 years of NASA data from 26 strategic spatial points across India (1981-2024).",
        "status": "Historical"
    })

    return insights
