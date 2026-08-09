from backend.ml.analytics import generate_analytics_report

def test_generate_analytics_report_returns_dict():
    report = generate_analytics_report()
    assert isinstance(report, dict)
    if report:
        assert "dataset_summary" in report
