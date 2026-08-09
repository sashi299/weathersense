import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_sense/services/api_service.dart';

class WeatherProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? currentWeather;
  Map<String, dynamic>? forecast;
  Map<String, dynamic>? analytics;
  bool isLoading = false;
  String errorMessage = '';
  List<String> history = [];
  bool isCelsius = true;
  String lastCity = 'London';

  Future<void> loadWeather(String city) async {
    final normalizedCity = city.trim();
    if (normalizedCity.isEmpty) {
      errorMessage = 'Enter a city name';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final current = await _apiService.getCurrentWeather(normalizedCity);
      final forecastData = await _apiService.getForecast(normalizedCity);
      final analyticsData = await _apiService.getAnalytics();
      currentWeather = current;
      forecast = forecastData;
      analytics = analyticsData;
      lastCity = normalizedCity;
      await _saveLastCity(normalizedCity);
      await _saveHistory(normalizedCity);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveLastCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_city', city);
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    lastCity = prefs.getString('last_city') ?? 'London';
    isCelsius = prefs.getBool('is_celsius') ?? true;
    history = prefs.getStringList('history') ?? [];
    notifyListeners();
  }

  void toggleUnit() async {
    isCelsius = !isCelsius;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_celsius', isCelsius);
    notifyListeners();
  }

  double convertTemp(double celsius) {
    if (isCelsius) return celsius;
    return (celsius * 9 / 5) + 32;
  }

  String get tempUnit => isCelsius ? '°C' : '°F';

  Future<void> refreshAnalytics() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();
    try {
      analytics = await _apiService.getAnalytics();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveHistory(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [city, ...history.where((item) => item != city)].take(6).toList();
    history = updated;
    await prefs.setStringList('history', history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    history = [];
    notifyListeners();
  }
}
