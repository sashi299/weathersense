import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os

def generate_weather_data():
    cities = {
        "Delhi": {"temp_mean": 25, "temp_std": 10, "hum_mean": 45, "rain_prob": 0.1},
        "Mumbai": {"temp_mean": 27, "temp_std": 3, "hum_mean": 75, "rain_prob": 0.3},
        "Bangalore": {"temp_mean": 22, "temp_std": 4, "hum_mean": 60, "rain_prob": 0.2},
        "Hyderabad": {"temp_mean": 26, "temp_std": 6, "hum_mean": 50, "rain_prob": 0.15},
        "Chennai": {"temp_mean": 29, "temp_std": 4, "hum_mean": 70, "rain_prob": 0.25}
    }

    start_date = datetime(2019, 1, 1)
    end_date = datetime(2024, 1, 1)
    date_range = pd.date_range(start_date, end_date, freq='D')

    all_data = []

    for city, params in cities.items():
        for date in date_range:
            # Simple seasonality: sin wave over the year
            day_of_year = date.timetuple().tm_yday
            seasonality = np.sin(2 * np.pi * (day_of_year - 100) / 365)

            temp = params["temp_mean"] + (params["temp_std"] * seasonality) + np.random.normal(0, 2)
            hum = params["hum_mean"] - (10 * seasonality) + np.random.normal(0, 5)
            hum = max(10, min(100, hum))

            # Monsoon effect (roughly June to September)
            is_monsoon = 150 < day_of_year < 270
            rain_prob = params["rain_prob"] * (3 if is_monsoon else 0.5)
            rain = np.random.gamma(2, 5) if np.random.random() < rain_prob else 0.0

            wind = 3 + np.random.normal(0, 1) + (2 if is_monsoon else 0)
            wind = max(0.5, wind)

            all_data.append({
                "date": date.strftime("%Y-%m-%d"),
                "city": city,
                "temperature": round(temp, 1),
                "humidity": int(hum),
                "rainfall": round(rain, 1),
                "wind_speed": round(wind, 1)
            })

    df = pd.DataFrame(all_data)
    output_path = "C:/Users/hp/Documents/weathersense/data/weather_history.csv"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    df.to_csv(output_path, index=False)
    print(f"Generated {len(df)} records across {len(cities)} cities.")

if __name__ == "__main__":
    generate_weather_data()
