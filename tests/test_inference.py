from backend.ml.inference import validate_input


def test_validate_input_rejects_empty_city():
    try:
        validate_input(" ")
    except ValueError:
        pass
    else:
        raise AssertionError("Expected ValueError for empty city")


def test_validate_input_accepts_normal_city_name():
    assert validate_input("Mumbai") == "Mumbai"
