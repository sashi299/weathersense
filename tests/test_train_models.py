import sys
from pathlib import Path

import joblib
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.ml.train_models import _calculate_metrics, load_model, select_best_model


def test_calculate_metrics_returns_expected_keys():
    y_true = np.array([1.0, 2.0, 3.0])
    y_pred = np.array([1.1, 1.8, 3.2])
    metrics = _calculate_metrics(y_true, y_pred)
    assert set(metrics.keys()) == {"rmse", "mae", "mape", "r2"}


def test_select_best_model_chooses_lowest_rmse():
    results = [
        {"model": "Prophet", "rmse": 2.5},
        {"model": "LSTM", "rmse": 1.2},
        {"model": "XGBoost", "rmse": 1.8},
    ]
    best_model = select_best_model(results)
    assert best_model == "LSTM"


def test_select_best_model_raises_on_empty_results():
    try:
        select_best_model([])
    except ValueError:
        pass
    else:
        raise AssertionError("Expected ValueError for empty model results")


def test_load_model_reads_saved_joblib_artifact(tmp_path):
    model_path = tmp_path / "dummy.joblib"
    joblib.dump({"value": 1}, model_path)
    loaded = load_model(model_path)
    assert loaded["value"] == 1
