import logging
from pathlib import Path
from typing import Dict, Optional
import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

DATA_PATH = Path("C:/Users/hp/Documents/weathersense/data/india_weather_history_grid.csv")
PROCESSED_DIR = Path("C:/Users/hp/Documents/weathersense/data/processed_india")

def clean_india_data(data: pd.DataFrame) -> pd.DataFrame:
    cleaned = data.copy()
    cleaned = cleaned.drop_duplicates()

    cleaned["date"] = pd.to_datetime(cleaned["date"], errors="coerce")
    cleaned = cleaned.dropna(subset=["date"]).sort_values("date").reset_index(drop=True)

    numeric_columns = ["temperature", "humidity", "rainfall", "wind_speed", "pressure", "latitude", "longitude"]
    for col in numeric_columns:
        cleaned[col] = pd.to_numeric(cleaned[col], errors="coerce")
        cleaned[col] = cleaned[col].fillna(cleaned[col].median())

    # Outlier removal (Meteorological ranges for India)
    # Temp: -10 to 60C, Hum: 0 to 100%, Rain: 0 to 500mm/day, Wind: 0 to 100m/s
    cleaned = cleaned[(cleaned["temperature"] > -20) & (cleaned["temperature"] < 65)]
    cleaned = cleaned[(cleaned["humidity"] >= 0) & (cleaned["humidity"] <= 100)]
    cleaned = cleaned[(cleaned["rainfall"] >= 0) & (cleaned["rainfall"] < 1000)]

    logger.info(f"Cleaned data shape: {cleaned.shape}")
    return cleaned

def engineer_india_features(data: pd.DataFrame) -> pd.DataFrame:
    features = data.copy()
    features = features.sort_values("date").reset_index(drop=True)

    # Time features
    features["month"] = features["date"].dt.month
    features["day_of_year"] = features["date"].dt.dayofyear
    features["sin_day"] = np.sin(2 * np.pi * features["day_of_year"] / 365)
    features["cos_day"] = np.cos(2 * np.pi * features["day_of_year"] / 365)

    # Location-aware features
    processed_groups = []
    for (lat, lon), group in features.groupby(["latitude", "longitude"]):
        group = group.sort_values("date")

        # Lags (Daily)
        group["temp_lag_1"] = group["temperature"].shift(1)
        group["temp_lag_3"] = group["temperature"].shift(3)
        group["temp_lag_7"] = group["temperature"].shift(7)
        group["hum_lag_1"] = group["humidity"].shift(1)
        group["rain_lag_1"] = group["rainfall"].shift(1)

        # Rolling
        group["temp_3d_avg"] = group["temperature"].rolling(window=3, min_periods=1).mean()
        group["temp_7d_avg"] = group["temperature"].rolling(window=7, min_periods=1).mean()
        group["hum_7d_avg"] = group["humidity"].rolling(window=7, min_periods=1).mean()
        group["rain_7d_avg"] = group["rainfall"].rolling(window=7, min_periods=1).mean()

        group["temp_diff"] = group["temperature"].diff().fillna(0)
        processed_groups.append(group)

    features = pd.concat(processed_groups).sort_values("date").reset_index(drop=True)
    features = features.bfill().ffill()
    return features

def main():
    logging.basicConfig(level=logging.INFO)
    if not DATA_PATH.exists():
        logger.error(f"Dataset not found at {DATA_PATH}")
        return

    raw = pd.read_csv(DATA_PATH)
    cleaned = clean_india_data(raw)
    engineered = engineer_india_features(cleaned)

    # Chronological Split
    # Train: 1981-2011, Val: 2012-2018, Test: 2019-2024
    train = engineered[engineered["date"] < "2012-01-01"]
    val = engineered[(engineered["date"] >= "2012-01-01") & (engineered["date"] < "2019-01-01")]
    test = engineered[engineered["date"] >= "2019-01-01"]

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    train.to_csv(PROCESSED_DIR / "train.csv", index=False)
    val.to_csv(PROCESSED_DIR / "validation.csv", index=False)
    test.to_csv(PROCESSED_DIR / "test.csv", index=False)

    logger.info(f"Split data: Train={len(train)}, Val={len(val)}, Test={len(test)}")
    logger.info(f"Total engineered features: {len(engineered.columns)}")
    logger.info("Nationwide preprocessing complete.")

if __name__ == "__main__":
    main()
