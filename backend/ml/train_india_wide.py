import json
import logging
import time
from pathlib import Path
from typing import Any, Dict
import joblib
import numpy as np
import pandas as pd
from xgboost import XGBRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

logger = logging.getLogger(__name__)

PROCESSED_DIR = Path("C:/Users/hp/Documents/weathersense/data/processed_india")
MODELS_DIR = Path("C:/Users/hp/Documents/weathersense/models/india_v1")
REPORTS_DIR = Path("C:/Users/hp/Documents/weathersense/reports/india_v1")

TARGETS = ["temperature", "humidity", "rainfall"]

def calculate_metrics(y_true, y_pred):
    y_pred = np.maximum(y_pred, 0)
    rmse = float(np.sqrt(mean_squared_error(y_true, y_pred)))
    mae = float(mean_absolute_error(y_true, y_pred))
    r2 = float(r2_score(y_true, y_pred))
    return {"rmse": rmse, "mae": mae, "r2": r2}

def train_india_models():
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    train = pd.read_csv(PROCESSED_DIR / "train.csv")
    val = pd.read_csv(PROCESSED_DIR / "validation.csv")

    # Identify feature columns
    # We drop date, temperature, humidity, rainfall (targets)
    drop_cols = ["date", "temperature", "humidity", "rainfall"]
    X_train = train.drop(columns=drop_cols)
    X_val = val.drop(columns=drop_cols)

    logger.info(f"Training on {len(X_train)} records with {len(X_train.columns)} features.")
    logger.info(f"Features: {X_train.columns.tolist()}")

    model_metadata = {
        "version": "india_v1",
        "training_period": "1981-2011",
        "spatial_resolution": "5.0 degrees",
        "targets": {}
    }

    all_metrics = []

    for target in TARGETS:
        logger.info(f"Training XGBoost for {target}...")
        y_train = train[target]
        y_val = val[target]

        start = time.time()
        model = XGBRegressor(n_estimators=150, learning_rate=0.08, max_depth=7, random_state=42)
        model.fit(X_train, y_train)
        duration = time.time() - start

        preds = model.predict(X_val)
        metrics = calculate_metrics(y_val, preds)

        logger.info(f"{target} Results - RMSE: {metrics['rmse']:.4f}, R2: {metrics['r2']:.4f}")

        # Save model
        filename = f"{target}_india.joblib"
        joblib.dump(model, MODELS_DIR / filename)

        model_metadata["targets"][target] = {
            "model": "XGBoost",
            "filename": filename,
            "metrics": metrics,
            "features": X_train.columns.tolist()
        }

        all_metrics.append({"target": target, **metrics})

    # Save Metadata
    with open(MODELS_DIR / "metadata.json", "w") as f:
        json.dump(model_metadata, f, indent=4)

    # Save Metrics Report
    metrics_df = pd.DataFrame(all_metrics)
    metrics_df.to_json(REPORTS_DIR / "metrics.json", orient="records", indent=4)

    logger.info("Nationwide training complete.")

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    train_india_models()
