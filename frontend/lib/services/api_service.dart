import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  /// Base URL for the weather API.
  /// Can be overridden at build time using:
  /// --dart-define=API_BASE_URL=http://10.169.34.226:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://weathersense-backend-production.up.railway.app',
  );

  Future<Map<String, dynamic>> getCurrentWeather(String city) async {
    final encodedCity = Uri.encodeQueryComponent(city);
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/current?city=$encodedCity'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Unexpected weather payload');
    } on SocketException {
      throw Exception(
          'Unable to connect to weather server at $baseUrl. Ensure backend is running and on the same network.');
    } on FormatException {
      throw Exception('Invalid response format from server');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timed out. Check your network connection.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getForecast(String city) async {
    final encodedCity = Uri.encodeQueryComponent(city);
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/forecast?city=$encodedCity'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Unable to load forecast: ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Unexpected forecast payload');
    } on SocketException {
      throw Exception('Unable to connect to forecast server.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Forecast request timed out.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/analytics'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return {};
      }

      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<List<dynamic>> getSuggestions(String query) async {
    if (query.length < 2) return [];
    try {
      final encodedQuery = Uri.encodeQueryComponent(query);
      final response = await http
          .get(Uri.parse('$baseUrl/search?q=$encodedQuery'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
