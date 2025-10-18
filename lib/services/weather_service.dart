import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature; // Celsius
  final double humidity; // Percentage (0-100)
  final double daylightHours; // Hours of daylight
  final DateTime timestamp;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.daylightHours,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'daylightHours': daylightHours,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: json['temperature']?.toDouble() ?? 0.0,
      humidity: json['humidity']?.toDouble() ?? 0.0,
      daylightHours: json['daylightHours']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class WeatherService {
  // OpenWeatherMap API (free tier)
  static const String _apiKey = 'YOUR_API_KEY_HERE'; // Replace with actual API key
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  
  // Cache for weather data to avoid excessive API calls
  static final Map<String, WeatherData> _cache = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);

  /// Get weather data for a specific location and month
  /// Falls back to calculated model if API fails
  static Future<WeatherData> getWeatherData(double latitude, double longitude, DateTime month) async {
    final cacheKey = '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}_${month.year}_${month.month}';
    final cached = _cache[cacheKey];
    
    // Return cached data if still valid
    if (cached != null && 
        DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
      return cached;
    }

    try {
      // Try to get real weather data from API
      final weatherData = await _fetchWeatherFromAPI(latitude, longitude, month);
      _cache[cacheKey] = weatherData;
      return weatherData;
    } catch (e) {
      // Fallback to calculated model
      print('Weather API failed, using calculated model: $e');
      final weatherData = _calculateWeatherModel(latitude, longitude, month);
      _cache[cacheKey] = weatherData;
      return weatherData;
    }
  }

  /// Fetch weather data from OpenWeatherMap API
  static Future<WeatherData> _fetchWeatherFromAPI(double latitude, double longitude, DateTime month) async {
    final url = Uri.parse('$_baseUrl?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric');
    
    final response = await http.get(url);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch weather data: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    
    return WeatherData(
      temperature: data['main']['temp']?.toDouble() ?? 0.0,
      humidity: data['main']['humidity']?.toDouble() ?? 0.0,
      daylightHours: _calculateDaylightHours(latitude, month),
      timestamp: month,
    );
  }

  /// Calculate weather data using a simple model based on location and time
  static WeatherData _calculateWeatherModel(double latitude, double longitude, DateTime month) {
    final monthValue = month.month;
    
    // Base temperature varies by latitude and season
    final baseTemp = _calculateBaseTemperature(latitude, monthValue);
    
    // Add some randomness for realism
    final random = Random();
    final tempVariation = (random.nextDouble() - 0.5) * 10; // ±5°C variation
    final temperature = baseTemp + tempVariation;
    
    // Humidity varies by season and temperature
    final baseHumidity = _calculateBaseHumidity(latitude, monthValue, temperature);
    final humidityVariation = (random.nextDouble() - 0.5) * 20; // ±10% variation
    final humidity = (baseHumidity + humidityVariation).clamp(20.0, 90.0);
    
    return WeatherData(
      temperature: temperature,
      humidity: humidity,
      daylightHours: _calculateDaylightHours(latitude, month),
      timestamp: month,
    );
  }

  /// Calculate base temperature based on latitude and month
  static double _calculateBaseTemperature(double latitude, int month) {
    // Seasonal temperature variation
    final seasonalTemp = _getSeasonalTemperature(latitude, month);
    
    // Latitude effect (colder at higher latitudes)
    final latitudeEffect = -latitude * 0.5;
    
    return seasonalTemp + latitudeEffect;
  }

  /// Get seasonal temperature based on hemisphere and month
  static double _getSeasonalTemperature(double latitude, int month) {
    final isNorthernHemisphere = latitude >= 0;
    
    // Base temperature for the location
    final baseTemp = isNorthernHemisphere ? 15.0 : 12.0;
    
    // Seasonal variation (colder in winter, warmer in summer)
    double seasonalVariation;
    if (isNorthernHemisphere) {
      // Northern hemisphere seasons
      switch (month) {
        case 12:
        case 1:
        case 2:
          seasonalVariation = -15.0; // Winter
          break;
        case 3:
        case 4:
        case 5:
          seasonalVariation = 0.0; // Spring
          break;
        case 6:
        case 7:
        case 8:
          seasonalVariation = 15.0; // Summer
          break;
        case 9:
        case 10:
        case 11:
          seasonalVariation = 0.0; // Fall
          break;
        default:
          seasonalVariation = 0.0;
      }
    } else {
      // Southern hemisphere seasons (opposite)
      switch (month) {
        case 12:
        case 1:
        case 2:
          seasonalVariation = 15.0; // Summer
          break;
        case 3:
        case 4:
        case 5:
          seasonalVariation = 0.0; // Fall
          break;
        case 6:
        case 7:
        case 8:
          seasonalVariation = -15.0; // Winter
          break;
        case 9:
        case 10:
        case 11:
          seasonalVariation = 0.0; // Spring
          break;
        default:
          seasonalVariation = 0.0;
      }
    }
    
    return baseTemp + seasonalVariation;
  }

  /// Calculate base humidity based on location, season, and temperature
  static double _calculateBaseHumidity(double latitude, int month, double temperature) {
    // Higher humidity in summer months
    final seasonalHumidity = _getSeasonalHumidity(month);
    
    // Temperature effect (higher temp can hold more moisture)
    final tempEffect = temperature > 25 ? 10 : -5;
    
    // Latitude effect (tropical regions are more humid)
    final latitudeEffect = (90 - latitude.abs()) * 0.2;
    
    return (seasonalHumidity + tempEffect + latitudeEffect).clamp(30.0, 80.0);
  }

  /// Get seasonal humidity variation
  static double _getSeasonalHumidity(int month) {
    // Higher humidity in summer months
    switch (month) {
      case 6:
      case 7:
      case 8:
        return 70.0; // Summer
      case 12:
      case 1:
      case 2:
        return 60.0; // Winter
      default:
        return 65.0; // Spring/Fall
    }
  }

  /// Calculate daylight hours for a given latitude and date
  static double _calculateDaylightHours(double latitude, DateTime date) {
    // Convert latitude to radians
    final latRad = latitude * pi / 180;
    
    // Day of year (1-365)
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    
    // Solar declination angle
    final declination = 23.45 * sin(2 * pi * (284 + dayOfYear) / 365) * pi / 180;
    
    // Hour angle at sunrise/sunset
    final hourAngle = acos(-tan(latRad) * tan(declination));
    
    // Daylight hours
    final daylightHours = 2 * hourAngle * 12 / pi;
    
    return daylightHours.clamp(0.0, 24.0);
  }

  /// Get weather data for a specific month (useful for historical analysis)
  static WeatherData getWeatherForMonth(double latitude, double longitude, DateTime month) {
    final targetMonth = DateTime(month.year, month.month, 15); // Mid-month
    
    return WeatherData(
      temperature: _calculateBaseTemperature(latitude, month.month),
      humidity: _calculateBaseHumidity(latitude, month.month, 
          _calculateBaseTemperature(latitude, month.month)),
      daylightHours: _calculateDaylightHours(latitude, targetMonth),
      timestamp: targetMonth,
    );
  }

  /// Clear weather cache
  static void clearCache() {
    _cache.clear();
  }

  /// Get cached weather data if available
  static WeatherData? getCachedWeather(double latitude, double longitude, DateTime month) {
    final cacheKey = '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}_${month.year}_${month.month}';
    final cached = _cache[cacheKey];
    
    if (cached != null && 
        DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
      return cached;
    }
    
    return null;
  }
}
