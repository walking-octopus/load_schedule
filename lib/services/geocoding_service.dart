import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'PowerTime/1.0';

  /// Reverse geocode coordinates to an address
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
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
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Search for addresses matching a query
  static Future<List<AddressSuggestion>> searchAddress(String query) async {
    if (query.isEmpty) return [];

    try {
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
      }
    } catch (e) {
      // Silently fail
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
