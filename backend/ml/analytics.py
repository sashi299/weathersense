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

        report = {
            "dataset_summary": summary,
            "model_metrics": metrics,
            "best_models": best_models
        }

        # Ensure directory exists before saving
        REPORTS_DIR.mkdir(parents=True, exist_ok=True)

        # Save report
        with open(REPORTS_DIR / "analytics_report.json", "w") as f:
            json.dump(report, f, indent=4)

        return report

    except Exception as e:
        logger.error(f"Analytics generation failed: {e}")
        return {}

if __name__ == "__main__":
    generate_analytics_report()
