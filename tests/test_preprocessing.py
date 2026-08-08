import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.ml.preprocessing import clean_data, engineer_features, split_dataset


def test_clean_data_handles_duplicates_and_dates():
    data = pd.DataFrame(
        {
            "date": ["2024-01-01", "2024-01-01", "2024-01-02"],
            "temperature": [20.0, 20.0, 22.0],
            "humidity": [50.0, 50.0, 55.0],
            "rainfall": [1.0, 1.0, 0.5],
        }
    )

    cleaned = clean_data(data)
    assert len(cleaned) == 2
    assert pd.api.types.is_datetime64_any_dtype(cleaned["date"])
    assert cleaned["date"].is_monotonic_increasing


def test_engineer_features_creates_expected_columns():
    data = pd.DataFrame(
        {
            "date": pd.date_range("2024-01-01", periods=10, freq="D"),
            "temperature": [20, 21, 22, 21, 20, 19, 18, 19, 20, 21],
            "humidity": [50, 52, 53, 54, 55, 56, 57, 58, 59, 60],
            "rainfall": [0.0, 0.3, 0.1, 0.2, 0.4, 0.0, 0.1, 0.0, 0.2, 0.1],
        }
    )

    engineered = engineer_features(data)
    expected_columns = {
        "day_of_week",
        "month",
        "week_of_year",
        "quarter",
        "temperature_lag_1",
        "temperature_lag_3",
        "temperature_lag_7",
        "humidity_lag_1",
        "rainfall_lag_1",
        "temperature_3day_avg",
        "temperature_7day_avg",
        "humidity_7day_avg",
        "rainfall_7day_avg",
        "temperature_7day_std",
        "temperature_difference",
        "sin_day_of_year",
        "cos_day_of_year",
    }
    assert expected_columns.issubset(set(engineered.columns))


def test_split_dataset_returns_expected_parts():
    data = pd.DataFrame({"date": pd.date_range("2024-01-01", periods=20, freq="D")})
    data["temperature"] = range(20)
    data["humidity"] = range(20)
    data["rainfall"] = range(20)

    splits = split_dataset(data)
    assert set(splits.keys()) == {"train", "validation", "test"}
    assert len(splits["train"]) + len(splits["validation"]) + len(splits["test"]) == len(data)
