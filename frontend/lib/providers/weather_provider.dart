import 'dart:convert';
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

  Future<void> loadWeather(String city, {double? lat, double? lon, Map<String, dynamic>? extra}) async {
    final normalizedCity = city.trim();
    if (normalizedCity.isEmpty) {
      errorMessage = 'Enter a city name';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = '';
    // Clear old weather to prevent stale state display
    currentWeather = null;
    forecast = null;
    notifyListeners();

    try {
      final current = await _apiService.getCurrentWeather(normalizedCity, lat: lat, lon: lon);
      final forecastData = await _apiService.getForecast(normalizedCity, lat: lat, lon: lon);
      final analyticsData = await _apiService.getAnalytics();
      currentWeather = current;
      forecast = forecastData;
      analytics = analyticsData;
      
      // Update lastCity to canonical name from server if available
      final canonicalName = current['city'] ?? normalizedCity;
      lastCity = canonicalName;
      await _saveLastCity(canonicalName);

      // Create history entry with full details
      final historyEntry = {
        'name': current['city'] ?? normalizedCity,
        'state': current['state'],
        'country': current['country'],
        'lat': lat ?? current['lat'], // Backend might not return lat/lon in current weather yet
        'lon': lon ?? current['lon'],
      };
      
      if (extra != null) historyEntry.addAll(extra);
      
      await _saveHistory(json.encode(historyEntry));
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

  Future<void> _saveHistory(String entryJson) async {
    String newName;
    try {
      newName = json.decode(entryJson)['name'];
    } catch (_) {
      newName = entryJson;
    }
    
    final prefs = await SharedPreferences.getInstance();
    
    final List<String> updatedHistory = [entryJson];
    for (var item in history) {
      String existingName;
      try {
        existingName = json.decode(item)['name'];
      } catch (_) {
        existingName = item;
      }
      
      if (existingName != newName) {
        updatedHistory.add(item);
      }
    }
    
    history = updatedHistory.take(10).toList(); // Store up to 10
    await prefs.setStringList('history', history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    history = [];
    notifyListeners();
  }
}
