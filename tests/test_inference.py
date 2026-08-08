import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.ml.inference import calculate_confidence, validate_input


def test_validate_input_rejects_empty_city():
    try:
        validate_input(" ")
    except ValueError:
        pass
    else:
        raise AssertionError("Expected ValueError for empty city")


def test_calculate_confidence_returns_reasonable_value():
    confidence = calculate_confidence("prophet", 22.5)
    assert 0.0 < confidence <= 1.0


def test_validate_input_accepts_normal_city_name():
    assert validate_input("Mumbai") == "Mumbai"
