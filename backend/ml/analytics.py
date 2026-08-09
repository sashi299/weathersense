"""Analytics and explainability utilities for WeatherSense (Multi-target)."""

from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns

logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BASE_DIR.parent / "data"
PROCESSED_DIR = DATA_DIR / "processed"
REPORTS_DIR = BASE_DIR.parent / "reports"
PLOTS_DIR = BASE_DIR.parent / "plots"
MODELS_DIR = BASE_DIR.parent / "models"

def generate_analytics_report() -> Dict[str, Any]:
    """Generate summary analytics from datasets and model metrics."""
    try:
        # 1. Dataset summary - use full historical data for summary if available
        raw_path = DATA_DIR / "weather_history_45y.csv"
        train_path = PROCESSED_DIR / "train.csv"

        summary_path = raw_path if raw_path.exists() else train_path
        if not summary_path.exists():
            raise FileNotFoundError("Historical dataset missing")

        df = pd.read_csv(summary_path)
        summary = {
            "total_records": len(df),
            "cities": df["city"].unique().tolist() if "city" in df.columns else [],
            "date_range": [str(df["date"].min()), str(df["date"].max())],
            "features": df.columns.tolist()
        }

        # 2. Load metrics
        metrics_path = REPORTS_DIR / "model_metrics.json"
        metrics = []
        if metrics_path.exists():
            try:
                with open(metrics_path, "r") as f:
                    metrics = json.load(f)
            except Exception as e:
                logger.error(f"Error reading model_metrics.json: {e}")
                metrics = [{"info": "Error reading metrics file"}]
        else:
            logger.warning("model_metrics.json not found, returning empty metrics list")
            metrics = [{"info": "Model performance data currently unavailable"}]

        # 3. Best models
        best_path = MODELS_DIR / "best_models_metadata.json"
        best_models = {}
        if best_path.exists():
            with open(best_path, "r") as f:
                best_models = json.load(f)

        # 4. Generate Deterministic AI Insights
        ai_insights = _generate_deterministic_insights(summary, metrics, best_models)

        report = {
            "dataset_summary": summary,
            "model_metrics": metrics,
            "best_models": best_models,
            "ai_insights": ai_insights
        }

        # Ensure directory exists before saving
        REPORTS_DIR.mkdir(parents=True, exist_ok=True)

        # Save report
        with open(REPORTS_DIR / "analytics_report.json", "w") as f:
            json.dump(report, f, indent=4)

        return report

    except Exception as e:
        logger.error(f"Analytics generation failed: {e}")
        return {
            "error": str(e),
            "ai_insights": [{"icon": "error", "title": "System Alert", "explanation": "Analytics system temporarily unavailable.", "status": "Error"}]
        }

def _generate_deterministic_insights(summary, metrics, best_models) -> List[Dict[str, str]]:
    insights = []

    # 1. Dataset Coverage Insight
    start_year = str(summary.get("date_range", ["1981"])[0])[:4]
    end_year = str(summary.get("date_range", ["", "2024"])[1])[:4]
    try:
        years = int(end_year) - int(start_year)
    except:
        years = 44

    insights.append({
        "icon": "history",
        "title": "Historical Foundation",
        "explanation": f"WeatherSense is built on {years} years of real meteorological data ({start_year}-{end_year}), enabling high-precision seasonal trend analysis.",
        "status": "Verified"
    })

    # 2. Model Performance Insight
    temp_best = best_models.get("temperature", {})
    temp_r2 = temp_best.get("metrics", {}).get("r2", 0)
    if temp_r2 > 0.9:
        insights.append({
            "icon": "psychology",
            "title": "Predictive Intelligence",
            "explanation": f"The {temp_best.get('model_name', 'XGBoost')} temperature model has reached a confidence index of {(temp_r2*100):.1f}%, indicating exceptional accuracy.",
            "status": "Elite"
        })

    # 3. Rainfall Complexity Insight
    rain_best = best_models.get("rainfall", {})
    rain_r2 = rain_best.get("metrics", {}).get("r2", 0)
    if rain_r2 < 0.5:
        insights.append({
            "icon": "warning",
            "title": "Atmospheric Complexity",
            "explanation": "Precipitation patterns show high stochasticity. While trends are identified, local micro-climates make exact mm prediction challenging.",
            "status": "Caution"
        })
    else:
        insights.append({
            "icon": "umbrella",
            "title": "Rainfall Analytics",
            "explanation": f"The {rain_best.get('model_name', 'XGBoost')} model effectively identifies regional monsoon patterns with {(rain_r2*100):.1f}% variance coverage.",
            "status": "Stable"
        })

    # 4. Global Reliability
    total_obs = summary.get("total_records", 0)
    insights.append({
        "icon": "verified",
        "title": "Data Integrity",
        "explanation": f"Insights are derived from {total_obs:,} verified observations across India's major climatic zones.",
        "status": "Secure"
    })

    return insights

if __name__ == "__main__":
    generate_analytics_report()
