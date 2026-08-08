import os
from datetime import datetime, timedelta
from typing import List, Dict

import joblib
import numpy as np


class ForecastService:
    def __init__(self, model_path: str | None = None) -> None:
        self.model_path = model_path or os.getenv("MODEL_PATH", "./models/weather_model.joblib")
        self._model = None
        self._ensure_model()

    def _ensure_model(self) -> None:
        os.makedirs(os.path.dirname(self.model_path) or ".", exist_ok=True)
        if not os.path.exists(self.model_path):
            self._model = {"type": "heuristic", "city": "global"}
            joblib.dump(self._model, self.model_path)
        else:
            self._model = joblib.load(self.model_path)

    def train(self, city: str = "global") -> dict:
        payload = {
            "type": "heuristic",
            "city": city,
            "trained_at": datetime.utcnow().isoformat(),
        }
        joblib.dump(payload, self.model_path)
        return {"message": "model saved", "model_path": self.model_path, "city": city}

    def build_forecast(self, city: str, current_payload: dict) -> List[Dict[str, object]]:
        base_temp = float(current_payload.get("main", {}).get("temp", 20))
        humidity = float(current_payload.get("main", {}).get("humidity", 65))
        start_date = datetime.utcnow().date()
        forecast: List[Dict[str, object]] = []
        for offset in range(7):
            day = start_date + timedelta(days=offset)
            temp_min = round(base_temp - 2.5 + (offset * 0.4), 1)
            temp_max = round(base_temp + 3.2 + (offset * 0.35), 1)
            rainfall = round(max(0.0, 3.2 + (offset % 3) - (humidity / 40)), 1)
            humidity_pct = round(max(35, min(98, humidity + (offset - 3) * 2.5)), 1)
            confidence = round(max(0.55, min(0.96, 0.78 + (0.02 * offset))), 2)
            forecast.append(
                {
                    "date": day.strftime("%Y-%m-%d"),
                    "temp_min": temp_min,
                    "temp_max": temp_max,
                    "rainfall_mm": rainfall,
                    "humidity_pct": humidity_pct,
                    "confidence": confidence,
                }
            )
        return forecast
