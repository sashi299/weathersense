import pandas as pd
import requests
import time
import os
import logging
from pathlib import Path
import numpy as np

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

# Grid points from grid_calculator.py (cached here for simplicity)
GRID_POINTS = [
    (8.0, 73.0), (8.0, 78.0), (8.0, 83.0), (13.0, 73.0), (13.0, 78.0), (13.0, 83.0),
    (18.0, 73.0), (18.0, 78.0), (18.0, 83.0), (23.0, 68.0), (23.0, 73.0), (23.0, 78.0),
    (23.0, 83.0), (23.0, 88.0), (23.0, 93.0), (28.0, 68.0), (28.0, 73.0), (28.0, 78.0),
    (28.0, 83.0), (28.0, 88.0), (28.0, 93.0), (33.0, 73.0), (33.0, 78.0), (33.0, 83.0),
    (33.0, 88.0), (33.0, 93.0)
]

PARAMS = "T2M,RH2M,PRECTOTCORR,WS2M,PS"

def fetch_grid_data(lat, lon):
    url = "https://power.larc.nasa.gov/api/temporal/daily/point"
    # 5-year chunks to ensure 200 OK from NASA API
    ranges = []
    curr_start = 1981
    while curr_start <= 2024:
        curr_end = min(curr_start + 4, 2024)
        ranges.append((f"{curr_start}0101", f"{curr_end}1231"))
        curr_start += 5

    point_chunks = []
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

        logger.info(f"Fetching grid ({lat}, {lon}) chunk {start}-{end}...")
        try:
            response = requests.get(url, params=params, timeout=45)
            response.raise_for_status()
            data = response.json()

            properties = data["properties"]["parameter"]
            dates = list(properties["T2M"].keys())

            chunk_df = pd.DataFrame({"date": dates})
            chunk_df["latitude"] = lat
            chunk_df["longitude"] = lon
            chunk_df["temperature"] = [properties["T2M"][d] for d in dates]
            chunk_df["humidity"] = [properties["RH2M"][d] for d in dates]
            chunk_df["rainfall"] = [properties["PRECTOTCORR"][d] for d in dates]
            chunk_df["wind_speed"] = [properties["WS2M"][d] for d in dates]
            chunk_df["pressure"] = [round(properties["PS"][d] * 10, 1) if properties["PS"][d] != -999 else 1013.25 for d in dates]

            point_chunks.append(chunk_df)
            time.sleep(1.5)
        except Exception as e:
            logger.error(f"Failed chunk {start}-{end} for ({lat}, {lon}): {e}")

    if not point_chunks:
        return None

    return pd.concat(point_chunks, ignore_index=True)

def main():
    all_dfs = []

    start_time = time.time()
    for i, (lat, lon) in enumerate(GRID_POINTS):
        logger.info(f"Processing grid point {i+1}/{len(GRID_POINTS)}: ({lat}, {lon})")
        df = fetch_grid_data(lat, lon)
        if df is not None:
            all_dfs.append(df)

    if not all_dfs:
        logger.error("No data fetched at all.")
        return

    final_df = pd.concat(all_dfs, ignore_index=True)

    # NASA uses -999 for missing values
    for col in ["temperature", "humidity", "rainfall", "wind_speed", "pressure"]:
        final_df[col] = final_df[col].replace(-999, np.nan)

    # Format date
    final_df["date"] = pd.to_datetime(final_df["date"], format="%Y%m%d").dt.strftime("%Y-%m-%d")
    final_df = final_df.sort_values(["date", "latitude", "longitude"]).drop_duplicates().reset_index(drop=True)

    output_path = Path("C:/Users/hp/Documents/weathersense/data/india_weather_history_grid.csv")
    final_df.to_csv(output_path, index=False)

    duration = time.time() - start_time
    logger.info(f"Saved {len(final_df)} records to {output_path} (Took {duration/60:.2f} mins)")
    logger.info(f"Date range: {final_df['date'].min()} to {final_df['date'].max()}")
    logger.info(f"Locations: {len(final_df.groupby(['latitude', 'longitude']))} grid points")

if __name__ == "__main__":
    main()
