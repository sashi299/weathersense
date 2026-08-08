"""Data preprocessing and feature engineering utilities for WeatherSense."""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Dict, Optional

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

DEFAULT_DATA_PATH = Path(__file__).resolve().parents[1] / ".." / "data" / "weather_history.csv"
PROCESSED_DIR = Path(__file__).resolve().parents[1] / ".." / "data" / "processed"


def load_dataset(data_path: Optional[Path | str] = None) -> pd.DataFrame:
    """Load historical weather data from a CSV file.

    Args:
        data_path: Optional path to a CSV dataset. Defaults to the repository
            data/weather_history.csv location.

    Returns:
        A pandas DataFrame containing the loaded dataset.

    Raises:
        FileNotFoundError: If the dataset file does not exist.
    """
    path = Path(data_path or DEFAULT_DATA_PATH)
    if not path.exists():
        raise FileNotFoundError(f"Dataset not found at {path}")

    logger.info("Loading dataset from %s", path)
    data = pd.read_csv(path)
    if data.empty:
        raise ValueError("The provided dataset is empty")
    return data


def clean_data(data: pd.DataFrame, date_column: str = "date") -> pd.DataFrame:
    """Clean and validate a weather dataset.

    The function removes duplicates, fills missing values using sensible defaults,
    converts the date column to datetime, sorts chronologically and removes
    obvious outliers using the IQR rule for numeric columns.

    Args:
        data: Raw weather data.
        date_column: Name of the column containing dates.

    Returns:
        A cleaned pandas DataFrame.
    """
    cleaned = data.copy()
    cleaned = cleaned.drop_duplicates()
    logger.info("Removed duplicates; %s rows remain", len(cleaned))

    if date_column in cleaned.columns:
        cleaned[date_column] = pd.to_datetime(cleaned[date_column], errors="coerce")
        cleaned = cleaned.dropna(subset=[date_column]).sort_values(date_column).reset_index(drop=True)
    else:
        raise KeyError(f"Date column '{date_column}' not found")

    numeric_columns = [
        col
        for col in ["temperature", "humidity", "rainfall", "wind_speed"]
        if col in cleaned.columns
    ]
    for column in numeric_columns:
        cleaned[column] = pd.to_numeric(cleaned[column], errors="coerce")

    for column in numeric_columns:
        cleaned[column] = cleaned[column].fillna(cleaned[column].median())

    for column in numeric_columns:
        q1 = cleaned[column].quantile(0.25)
        q3 = cleaned[column].quantile(0.75)
        iqr = q3 - q1
        lower_bound = q1 - 1.5 * iqr
        upper_bound = q3 + 1.5 * iqr
        cleaned = cleaned[(cleaned[column] >= lower_bound) & (cleaned[column] <= upper_bound)]

    cleaned = cleaned.reset_index(drop=True)
    logger.info("Cleaned data shape: %s", cleaned.shape)
    return cleaned


def engineer_features(data: pd.DataFrame, date_column: str = "date") -> pd.DataFrame:
    """Create time-based and lag-based features for forecasting per city."""
    if date_column not in data.columns:
        raise KeyError(f"Date column '{date_column}' not found")

    features = data.copy()
    features = features.sort_values(date_column).reset_index(drop=True)

    required_columns = {"temperature", "humidity", "rainfall"}
    missing = required_columns.difference(features.columns)
    if missing:
        raise KeyError(f"Required columns missing: {sorted(missing)}")

    # Time features (global)
    features["day_of_week"] = features[date_column].dt.dayofweek
    features["month"] = features[date_column].dt.month
    features["quarter"] = features[date_column].dt.quarter
    features["day_of_year"] = features[date_column].dt.dayofyear
    features["sin_day_of_year"] = np.sin(2 * np.pi * features["day_of_year"] / 365)
    features["cos_day_of_year"] = np.cos(2 * np.pi * features["day_of_year"] / 365)

    # City-specific lag and rolling features
    if "city" in features.columns:
        processed_groups = []
        for city, group in features.groupby("city"):
            group = group.sort_values(date_column)

            # Lags
            group["temperature_lag_1"] = group["temperature"].shift(1)
            group["temperature_lag_3"] = group["temperature"].shift(3)
            group["temperature_lag_7"] = group["temperature"].shift(7)
            group["humidity_lag_1"] = group["humidity"].shift(1)
            group["rainfall_lag_1"] = group["rainfall"].shift(1)

            # Rolling stats
            group["temperature_3day_avg"] = group["temperature"].rolling(window=3, min_periods=1).mean()
            group["temperature_7day_avg"] = group["temperature"].rolling(window=7, min_periods=1).mean()
            group["humidity_7day_avg"] = group["humidity"].rolling(window=7, min_periods=1).mean()
            group["rainfall_7day_avg"] = group["rainfall"].rolling(window=7, min_periods=1).mean()

            group["temperature_7day_std"] = group["temperature"].rolling(window=7, min_periods=1).std().fillna(0)
            group["temperature_difference"] = group["temperature"].diff().fillna(0)
            processed_groups.append(group)

        features = pd.concat(processed_groups).sort_values(date_column).reset_index(drop=True)
    else:
        # Fallback for single city datasets
        features = features.sort_values(date_column)
        features["temperature_lag_1"] = features["temperature"].shift(1)
        features["temperature_lag_3"] = features["temperature"].shift(3)
        features["temperature_lag_7"] = features["temperature"].shift(7)
        features["humidity_lag_1"] = features["humidity"].shift(1)
        features["rainfall_lag_1"] = features["rainfall"].shift(1)
        features["temperature_3day_avg"] = features["temperature"].rolling(window=3, min_periods=1).mean()
        features["temperature_7day_avg"] = features["temperature"].rolling(window=7, min_periods=1).mean()
        features["humidity_7day_avg"] = features["humidity"].rolling(window=7, min_periods=1).mean()
        features["rainfall_7day_avg"] = features["rainfall"].rolling(window=7, min_periods=1).mean()
        features["temperature_7day_std"] = features["temperature"].rolling(window=7, min_periods=1).std().fillna(0)
        features["temperature_difference"] = features["temperature"].diff().fillna(0)

    features = features.drop(columns=["day_of_year"])
    features = features.bfill().ffill()
    return features


def split_dataset(
    data: pd.DataFrame,
    train_ratio: float = 0.7,
    validation_ratio: float = 0.15,
    test_ratio: float = 0.15,
) -> Dict[str, pd.DataFrame]:
    """Split the processed dataset into train/validation/test partitions.

    Args:
        data: Engineered dataset.
        train_ratio: Fraction used for training.
        validation_ratio: Fraction used for validation.
        test_ratio: Fraction used for testing.

    Returns:
        A dictionary mapping split names to DataFrames.
    """
    if not np.isclose(train_ratio + validation_ratio + test_ratio, 1.0):
        raise ValueError("The split ratios must sum to 1.0")

    n_rows = len(data)
    train_end = int(n_rows * train_ratio)
    validation_end = train_end + int(n_rows * validation_ratio)

    train = data.iloc[:train_end].copy()
    validation = data.iloc[train_end:validation_end].copy()
    test = data.iloc[validation_end:].copy()

    logger.info("Split data into train=%s validation=%s test=%s", len(train), len(validation), len(test))
    return {"train": train, "validation": validation, "test": test}


def save_processed_data(
    splits: Dict[str, pd.DataFrame],
    output_dir: Optional[Path | str] = None,
) -> Path:
    """Persist train/validation/test datasets to disk.

    Args:
        splits: Dictionary of split DataFrames.
        output_dir: Directory where processed datasets should be stored.

    Returns:
        The output directory path.
    """
    output_path = Path(output_dir or PROCESSED_DIR)
    output_path.mkdir(parents=True, exist_ok=True)

    for split_name, frame in splits.items():
        destination = output_path / f"{split_name}.csv"
        frame.to_csv(destination, index=False)
        logger.info("Saved %s to %s", split_name, destination)

    return output_path


def preprocess_pipeline(
    data_path: Optional[Path | str] = None,
    output_dir: Optional[Path | str] = None,
) -> Dict[str, pd.DataFrame]:
    """Run the full preprocessing pipeline and save processed datasets."""
    raw_data = load_dataset(data_path)
    cleaned = clean_data(raw_data)
    engineered = engineer_features(cleaned)
    splits = split_dataset(engineered)
    save_processed_data(splits, output_dir)
    return splits


if __name__ == "__main__":
    import logging

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    preprocess_pipeline()
