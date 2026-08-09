import pandas as pd
import requests
import time
import os
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

CITIES = {
    "Delhi": {"lat": 28.61, "lon": 77.21},
    "Mumbai": {"lat": 19.08, "lon": 72.88},
    "Bangalore": {"lat": 12.97, "lon": 77.59},
    "Hyderabad": {"lat": 17.39, "lon": 78.49},
    "Chennai": {"lat": 13.08, "lon": 80.27}
}

# NASA POWER Parameters mapping
# T2M: Temperature at 2 Meters (C)
# RH2M: Relative Humidity at 2 Meters (%)
# PRECTOTCORR: Precipitation Corrected (mm/day)
# WS2M: Wind Speed at 2 Meters (m/s)
# PS: Surface Pressure (kPa) -> convert to hPa (kPa * 10)
PARAMS = "T2M,RH2M,PRECTOTCORR,WS2M,PS"

def fetch_city_data(city_name, lat, lon):
    url = "https://power.larc.nasa.gov/api/temporal/daily/point"
    # Let's try 1-year chunks to be absolutely certain we don't hit range limits
    ranges = []
    curr_start = 1981
    end_limit = 2024
    while curr_start <= end_limit:
        ranges.append((f"{curr_start}0101", f"{curr_start}1231"))
        curr_start += 1

    city_chunks = []
    for start, end in ranges:
        params = {
            "start": start,
            "end": end,
            "latitude": lat,
            "longitude": lon,
            "parameters": PARAMS,
            "community": "RE",
            "format": "JSON"
        }

        logger.info(f"Fetching {city_name} chunk {start}-{end}...")
        try:
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            data = response.json()

            properties = data["properties"]["parameter"]
            dates = list(properties["T2M"].keys())

            chunk_df = pd.DataFrame({"date": dates})
            chunk_df["temperature"] = [properties["T2M"][d] for d in dates]
            chunk_df["humidity"] = [properties["RH2M"][d] for d in dates]
            chunk_df["rainfall"] = [properties["PRECTOTCORR"][d] for d in dates]
            chunk_df["wind_speed"] = [properties["WS2M"][d] for d in dates]
            chunk_df["pressure"] = [round(properties["PS"][d] * 10, 1) if properties["PS"][d] != -999 else 1013.25 for d in dates]

            city_chunks.append(chunk_df)
            time.sleep(1)
        except Exception as e:
            logger.error(f"Failed chunk {start}-{end} for {city_name}: {e}")

    if not city_chunks:
        return None

    city_df = pd.concat(city_chunks, ignore_index=True)
    city_df["city"] = city_name

    # NASA uses -999 for missing values
    for col in ["temperature", "humidity", "rainfall", "wind_speed", "pressure"]:
        city_df[col] = city_df[col].replace(-999, pd.NA)

    return city_df

def main():
    all_city_dfs = []

    for city, coords in CITIES.items():
        df = fetch_city_data(city, coords["lat"], coords["lon"])
        if df is not None:
            all_city_dfs.append(df)

    if not all_city_dfs:
        logger.error("No data fetched at all.")
        return

    final_df = pd.concat(all_city_dfs, ignore_index=True)

    # Format date
    final_df["date"] = pd.to_datetime(final_df["date"], format="%Y%m%d").dt.strftime("%Y-%m-%d")
    final_df = final_df.sort_values(["date", "city"]).drop_duplicates().reset_index(drop=True)

    output_path = Path("C:/Users/hp/Documents/weathersense/data/weather_history_45y.csv")
    final_df.to_csv(output_path, index=False)

    logger.info(f"Saved {len(final_df)} real records to {output_path}")
    logger.info(f"Date range: {final_df['date'].min()} to {final_df['date'].max()}")

if __name__ == "__main__":
    main()
