"""Training pipeline for WeatherSense forecasting models (Multi-target)."""

from __future__ import annotations

import json
import logging
import random
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import joblib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.preprocessing import StandardScaler

try:
    from xgboost import XGBRegressor
except Exception as exc:
    XGBRegressor = None
    XGBOOST_IMPORT_ERROR = exc
else:
    XGBOOST_IMPORT_ERROR = None

try:
    import tensorflow as tf
    from tensorflow.keras import Sequential
    from tensorflow.keras.callbacks import EarlyStopping
    from tensorflow.keras.layers import Dense, Dropout, LSTM
except Exception as exc:
    tf = None
    TENSORFLOW_IMPORT_ERROR = exc
else:
    TENSORFLOW_IMPORT_ERROR = None

try:
    from prophet import Prophet
except Exception as exc:
    Prophet = None
    PROPHET_IMPORT_ERROR = exc
else:
    PROPHET_IMPORT_ERROR = None

logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parents[1]
PROCESSED_DIR = BASE_DIR.parent / "data" / "processed"
MODELS_DIR = BASE_DIR.parent / "models"
PLOTS_DIR = BASE_DIR.parent / "plots"
REPORTS_DIR = BASE_DIR.parent / "reports"

TARGETS = ["temperature", "humidity", "rainfall"]

def configure_logging() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")

def set_seed(seed: int = 42) -> None:
    random.seed(seed)
    np.random.seed(seed)
    if tf is not None:
        tf.keras.utils.set_random_seed(seed)

def load_processed_datasets(data_dir: Optional[Path | str] = None) -> Dict[str, pd.DataFrame]:
    directory = Path(data_dir or PROCESSED_DIR)
    datasets: Dict[str, pd.DataFrame] = {}
    for split_name in ["train", "validation", "test"]:
        path = directory / f"{split_name}.csv"
        if not path.exists():
            raise FileNotFoundError(f"Missing processed dataset: {path}")
        datasets[split_name] = pd.read_csv(path)
    return datasets


def load_model(model_path: Path | str) -> Any:
    """Load a saved model from disk."""
    path = Path(model_path)
    if not path.exists():
        raise FileNotFoundError(f"Model file not found: {path}")
    if path.suffix == ".keras" and tf is not None:
        return tf.keras.models.load_model(path)
    return joblib.load(path)


def select_best_model(results: List[Dict[str, Any]]) -> str:
    """Select the best model by lowest RMSE."""
    if not results:
        raise ValueError("At least one model result is required")
    return min(results, key=lambda result: result["rmse"])["model"]

def _calculate_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> Dict[str, float]:
    y_pred = np.maximum(y_pred, 0) # Physical constraints (no negative rain/humidity)
    rmse = float(np.sqrt(mean_squared_error(y_true, y_pred)))
    mae = float(mean_absolute_error(y_true, y_pred))
    mape = float(np.mean(np.abs((y_true - y_pred) / np.maximum(y_true, 1e-8))) * 100)
    r2 = float(r2_score(y_true, y_pred))
    return {"rmse": rmse, "mae": mae, "mape": mape, "r2": r2}

def save_model(model: Any, model_path: Path | str) -> None:
    path = Path(model_path)
    if hasattr(model, "save") and str(path).endswith(".keras"):
        model.save(path)
    else:
        joblib.dump(model, path)

def train_prophet_model(train_data: pd.DataFrame, validation_data: pd.DataFrame, target: str) -> Dict[str, Any]:
    if Prophet is None:
        raise ImportError("Prophet not installed")

    # Prophet requires 'ds' and 'y'
    df = train_data[["date", target]].copy().rename(columns={"date": "ds", target: "y"})
    df["ds"] = pd.to_datetime(df["ds"])

    model = Prophet(daily_seasonality=True, yearly_seasonality=True)
    start = time.time()
    model.fit(df)
    training_time = time.time() - start

    future = model.make_future_dataframe(periods=len(validation_data), freq="D")
    forecast = model.predict(future)
    predictions = forecast["yhat"].tail(len(validation_data)).to_numpy()
    actual = validation_data[target].to_numpy()

    return {"model": model, "metrics": _calculate_metrics(actual, predictions), "training_time": training_time, "predictions": predictions}

def train_xgboost_model(train_data: pd.DataFrame, validation_data: pd.DataFrame, target: str) -> Dict[str, Any]:
    if XGBRegressor is None:
        raise ImportError("XGBoost not installed")

    drop_cols = ["date", "city", "temperature", "humidity", "rainfall"]
    X_train = train_data.drop(columns=drop_cols)
    y_train = train_data[target]
    X_val = validation_data.drop(columns=drop_cols)
    y_val = validation_data[target]

    model = XGBRegressor(n_estimators=100, learning_rate=0.1, random_state=42)
    start = time.time()
    model.fit(X_train, y_train)
    training_time = time.time() - start

    predictions = model.predict(X_val)
    return {"model": model, "metrics": _calculate_metrics(y_val.to_numpy(), predictions), "training_time": training_time, "predictions": predictions}

def train_lstm_model(train_data: pd.DataFrame, validation_data: pd.DataFrame, target: str) -> Dict[str, Any]:
    if tf is None:
        raise ImportError("TensorFlow not installed")

    drop_cols = ["date", "city", "temperature", "humidity", "rainfall"]
    X_train_raw = train_data.drop(columns=drop_cols)
    y_train = train_data[target].to_numpy()
    X_val_raw = validation_data.drop(columns=drop_cols)
    y_val = validation_data[target].to_numpy()

    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train_raw)
    X_val = scaler.transform(X_val_raw)

    X_train = X_train.reshape((X_train.shape[0], 1, X_train.shape[1]))
    X_val = X_val.reshape((X_val.shape[0], 1, X_val.shape[1]))

    model = Sequential([
        LSTM(50, activation='relu', input_shape=(1, X_train.shape[2])),
        Dense(1)
    ])
    model.compile(optimizer='adam', loss='mse')

    start = time.time()
    model.fit(X_train, y_train, epochs=20, batch_size=32, verbose=0)
    training_time = time.time() - start

    predictions = model.predict(X_val, verbose=0).flatten()
    return {"model": model, "scaler": scaler, "metrics": _calculate_metrics(y_val, predictions), "training_time": training_time, "predictions": predictions}

def run_training_pipeline():
    configure_logging()
    set_seed(42)
    datasets = load_processed_datasets()
    train, val, test = datasets["train"], datasets["validation"], datasets["test"]

    best_models_info = {}
    all_metrics = []

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    PLOTS_DIR.mkdir(parents=True, exist_ok=True)

    for target in TARGETS:
        logger.info(f"--- Training models for target: {target} ---")

        results = {}

        # Prophet
        try:
            results["Prophet"] = train_prophet_model(train, val, target)
        except Exception as e:
            logger.warning(f"Prophet failed for {target}: {e}")

        # XGBoost
        try:
            results["XGBoost"] = train_xgboost_model(train, val, target)
        except Exception as e:
            logger.warning(f"XGBoost failed for {target}: {e}")

        # LSTM
        try:
            results["LSTM"] = train_lstm_model(train, val, target)
        except Exception as e:
            logger.warning(f"LSTM failed for {target}: {e}")

        if not results:
            logger.error(f"No models trained successfully for {target}")
            continue

        # Select best
        best_name = min(results, key=lambda k: results[k]["metrics"]["rmse"])
        best_result = results[best_name]
        logger.info(f"Best model for {target}: {best_name} (RMSE: {best_result['metrics']['rmse']:.4f})")

        # Save best model
        ext = ".keras" if best_name == "LSTM" else ".joblib"
        model_filename = f"{target}_best{ext}"
        save_model(best_result["model"], MODELS_DIR / model_filename)

        if best_name == "LSTM":
            joblib.dump(best_result["scaler"], MODELS_DIR / f"{target}_scaler.joblib")

        best_models_info[target] = {
            "model_name": best_name,
            "filename": model_filename,
            "metrics": best_result["metrics"]
        }

        # Collect metrics for report
        for name, res in results.items():
            m = res["metrics"]
            all_metrics.append({
                "target": target,
                "model": name,
                "rmse": m["rmse"],
                "mae": m["mae"],
                "mape": m["mape"],
                "r2": m["r2"],
                "training_time": res["training_time"]
            })

        # Plot Actual vs Predicted for best model
        plt.figure(figsize=(10, 5))
        plt.plot(val[target].values[:100], label="Actual", alpha=0.7)
        plt.plot(best_result["predictions"][:100], label="Predicted", alpha=0.7)
        plt.title(f"{target.capitalize()} Forecast: {best_name} (Validation Set)")
        plt.legend()
        plt.savefig(PLOTS_DIR / f"{target}_best_val.png")
        plt.close()

    # Save metadata
    with open(MODELS_DIR / "best_models_metadata.json", "w") as f:
        json.dump(best_models_info, f, indent=4)

    # Save all metrics
    metrics_df = pd.DataFrame(all_metrics)
    metrics_df.to_csv(REPORTS_DIR / "model_metrics.csv", index=False)
    metrics_df.to_json(REPORTS_DIR / "model_metrics.json", orient="records", indent=4)

    # Generate simple text report
    report = [
        "# WeatherSense ML Training Report",
        f"Generated: {time.ctime()}",
        f"Dataset size: {len(train) + len(val) + len(test)} records",
        f"Cities: {train['city'].unique().tolist() if 'city' in train.columns else 'N/A'}",
        f"Date range: {train['date'].min()} to {test['date'].max()}",
        "\n## Best Models per Target",
    ]
    for target, info in best_models_info.items():
        report.append(f"- **{target.capitalize()}**: {info['model_name']} (RMSE: {info['metrics']['rmse']:.4f})")

    with open(REPORTS_DIR / "ml_report.md", "w") as f:
        f.write("\n".join(report))

    logger.info("Training pipeline completed successfully.")

if __name__ == "__main__":
    run_training_pipeline()
