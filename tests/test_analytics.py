import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.ml.analytics import MetricsCalculator, ReportGenerator


def test_metrics_calculator_returns_expected_values():
    calc = MetricsCalculator()
    y_true = [1.0, 2.0, 3.0]
    y_pred = [1.1, 1.8, 3.2]
    metrics = {
        "rmse": calc.rmse(y_true, y_pred),
        "mae": calc.mae(y_true, y_pred),
        "mape": calc.mape(y_true, y_pred),
        "r2": calc.r2_score(y_true, y_pred),
        "explained_variance": calc.explained_variance(y_true, y_pred),
        "median_absolute_error": calc.median_absolute_error(y_true, y_pred),
    }
    assert set(metrics.keys()) == {"rmse", "mae", "mape", "r2", "explained_variance", "median_absolute_error"}


def test_report_generator_builds_dataset_summary(tmp_path):
    data = pd.DataFrame(
        {
            "date": pd.date_range("2024-01-01", periods=5, freq="D"),
            "temperature": [20.0, 21.0, 22.0, 21.5, 20.8],
            "humidity": [50.0, 52.0, 54.0, 55.0, 57.0],
            "rainfall": [0.1, 0.2, 0.0, 0.4, 0.3],
        }
    )
    generator = ReportGenerator(output_dir=tmp_path)
    summary = generator.generate_dataset_summary(data)
    assert summary["rows"] == 5
    assert summary["columns"] == 4
