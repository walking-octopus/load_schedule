import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'PowerTime/1.0';
  static DateTime? _lastRequestTime;

  /// Ensure we respect Nominatim's rate limit (1 request per second)
  static Future<void> _respectRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest.inMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - timeSinceLastRequest.inMilliseconds));
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Reverse geocode coordinates to an address
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      await _respectRateLimit();

      final url = Uri.parse(
        '$_nominatimBaseUrl/reverse?format=json&lat=$latitude&lon=$longitude&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      } else {
        debugPrint('Reverse geocoding failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
    return null;
  }

  /// Search for addresses matching a query
  static Future<List<AddressSuggestion>> searchAddress(String query) async {
    if (query.isEmpty) return [];

    try {
      await _respectRateLimit();

      final url = Uri.parse(
        '$_nominatimBaseUrl/search?format=json&q=${Uri.encodeComponent(query)}&addressdetails=1&limit=5',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => AddressSuggestion(
          displayName: item['display_name'] as String,
          latitude: double.parse(item['lat'] as String),
          longitude: double.parse(item['lon'] as String),
        )).toList();
      } else {
        debugPrint('Address search failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Address search error: $e');
    }
    return [];
  }
}

class AddressSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;

  AddressSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}
