import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Household settings for electricity modeling
class HouseholdSettings {
  final String address;
  final double latitude;
  final double longitude;
  final double area; // m²
  final int occupants;
  final String buildingType; // 'Apartment', 'House', 'Townhouse'
  final int constructionYear;
  final String heatingType; // 'Electric', 'Gas', 'Heat Pump'
  final double insulationRating; // 1-10 scale
  final Map<String, double> applianceUsage; // hours per day
  final double evDailyKm; // km per day
  final double evBatteryCapacity; // kWh

  const HouseholdSettings({
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.area,
    required this.occupants,
    required this.buildingType,
    required this.constructionYear,
    required this.heatingType,
    required this.insulationRating,
    required this.applianceUsage,
    required this.evDailyKm,
    required this.evBatteryCapacity,
  });

  /// Get the base energy efficiency factor
  double get efficiencyFactor {
    double factor = 1.0;
    
    // Building type factor
    switch (buildingType) {
      case 'Apartment':
        factor *= 0.8; // Apartments are more efficient
        break;
      case 'House':
        factor *= 1.2; // Houses use more energy
        break;
      case 'Townhouse':
        factor *= 1.0; // Neutral
        break;
    }
    
    // Construction year factor (newer = more efficient)
    final age = DateTime.now().year - constructionYear;
    if (age < 10) {
      factor *= 0.7; // Very new
    } else if (age < 20) {
      factor *= 0.85; // New
    } else if (age < 30) {
      factor *= 1.0; // Average
    } else {
      factor *= 1.2; // Old
    }
    
    // Insulation factor
    factor *= (11 - insulationRating) / 10; // Lower rating = higher factor
    
    return factor;
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'area': area,
      'occupants': occupants,
      'buildingType': buildingType,
      'constructionYear': constructionYear,
      'heatingType': heatingType,
      'insulationRating': insulationRating,
      'applianceUsage': applianceUsage,
      'evDailyKm': evDailyKm,
      'evBatteryCapacity': evBatteryCapacity,
    };
  }

  factory HouseholdSettings.fromJson(Map<String, dynamic> json) {
    return HouseholdSettings(
      address: json['address'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      area: json['area'] as double,
      occupants: json['occupants'] as int,
      buildingType: json['buildingType'] as String,
      constructionYear: json['constructionYear'] as int,
      heatingType: json['heatingType'] as String,
      insulationRating: json['insulationRating'] as double,
      applianceUsage: Map<String, double>.from(json['applianceUsage'] as Map),
      evDailyKm: json['evDailyKm'] as double,
      evBatteryCapacity: json['evBatteryCapacity'] as double,
    );
  }
}

class SettingsStorageService {
  static const String _settingsKey = 'household_settings';

  /// Save household settings
  static Future<void> saveSettings(HouseholdSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      await prefs.setString(_settingsKey, jsonString);
    } catch (e) {
      throw Exception('Failed to save settings: $e');
    }
  }

  /// Load household settings
  static Future<HouseholdSettings?> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsKey);
      
      if (jsonString == null) {
        return null;
      }
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return HouseholdSettings.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Check if settings are complete and valid
  static Future<bool> hasValidSettings() async {
    final settings = await loadSettings();
    if (settings == null) return false;
    
    // Check if all required fields are present and valid
    return settings.address.isNotEmpty &&
           settings.latitude != 0.0 &&
           settings.longitude != 0.0 &&
           settings.area > 0 &&
           settings.occupants > 0 &&
           settings.buildingType.isNotEmpty &&
           settings.constructionYear > 1900 &&
           settings.heatingType.isNotEmpty &&
           settings.insulationRating > 0 &&
           settings.insulationRating <= 10;
  }

  /// Clear all settings
  static Future<void> clearSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
    } catch (e) {
      throw Exception('Failed to clear settings: $e');
    }
  }
}
