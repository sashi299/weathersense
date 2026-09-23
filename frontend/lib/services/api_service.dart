import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  /// Base URL for the weather API.
  /// Defaults to production Render deployment.
  /// Can be overridden at build time using:
  /// --dart-define=API_BASE_URL=https://weathersense-backend.onrender.com
  static const String defaultRenderUrl = 'https://weathersense-backend.onrender.com';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultRenderUrl,
  );

  Future<Map<String, dynamic>> getCurrentWeather(String city, {double? lat, double? lon}) async {
    final encodedCity = Uri.encodeQueryComponent(city);
    String url = '$baseUrl/current?city=$encodedCity';
    if (lat != null && lon != null) {
      url += '&lat=$lat&lon=$lon';
    }
    
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        String msg = 'Weather service error (${response.statusCode})';
        try {
          final errBody = json.decode(response.body);
          if (errBody['detail'] != null) msg = errBody['detail'];
        } catch (_) {}
        throw Exception(msg);
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

  Future<Map<String, dynamic>> getForecast(String city, {double? lat, double? lon}) async {
    final encodedCity = Uri.encodeQueryComponent(city);
    String url = '$baseUrl/forecast?city=$encodedCity';
    if (lat != null && lon != null) {
      url += '&lat=$lat&lon=$lon';
    }

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        String msg = 'Forecast unavailable (${response.statusCode})';
        try {
          final errBody = json.decode(response.body);
          if (errBody['detail'] != null) msg = errBody['detail'];
        } catch (_) {}
        throw Exception(msg);
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
      throw Exception('Search failed: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> reverseGeocode(double lat, double lon) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/reverse?lat=$lat&lon=$lon'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}
