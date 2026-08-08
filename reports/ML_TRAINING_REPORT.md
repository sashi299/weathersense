# WeatherSense ML Training Report

## 1. Dataset Overview
- **Source**: Synthetic historical weather data for major Indian cities.
- **Size**: 9,135 raw records (7,060 cleaned).
- **Cities Covered**: Delhi, Mumbai, Bangalore, Hyderabad, Chennai.
- **Date Range**: 2019-01-01 to 2024-01-01.
- **Features**: 
  - Meteorological: temperature, humidity, rainfall, wind_speed.
  - Temporal: day_of_week, month, quarter, day_of_year_sin/cos.
  - Lags: 1, 3, and 7-day lags for temperature.
  - Rolling: 3-day and 7-day averages.

## 2. Preprocessing Pipeline
- **Missing Values**: Handled using city-specific medians.
- **Outliers**: Removed using the Interquartile Range (IQR) method per feature.
- **Feature Engineering**: Implemented city-grouped window functions to prevent spatial data leakage. Lags and rolling stats are calculated strictly within city boundaries.
- **Normalization**: Standard scaling applied for neural network models (LSTM).

## 3. Model Training & Evaluation
We trained **Prophet** and **XGBoost** for three separate targets. **LSTM** was evaluated but skipped due to environment-specific dependency constraints (TensorFlow missing).

### Best Models Selected
| Target | Best Model | RMSE | MAE | R² |
| :--- | :--- | :--- | :--- | :--- |
| **Temperature** | XGBoost | 0.3372 | 0.2375 | 0.9959 |
| **Humidity** | XGBoost | 4.8310 | 3.8828 | 0.8915 |
| **Rainfall** | XGBoost | 0.5145 | 0.1759 | 0.1891 |

## 4. Inference Logic
- **/current**: Fetches live data from OpenWeather API using the production key.
- **/forecast**: 
  - If trained artifacts exist, it uses a multi-target inference loop.
  - **Prophet** is preferred for date-based trend analysis.
  - **XGBoost** is used for feature-rich local variability.
  - Fallback: Deterministic trend based on current city signal.

## 5. Limitations
- **LSTM Missing**: The current environment does not have TensorFlow, so deep learning temporal patterns are not yet utilized.
- **Stationarity**: The dataset assumes consistent climate patterns; extreme climate shift events are not modeled.
- **Real-world Correlation**: The synthetic data mimics Indian monsoon patterns but may lack localized micro-climate nuances.
