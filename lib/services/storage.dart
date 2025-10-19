import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../core/bill_models.dart';
import '../core/utils.dart';

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

class StorageService {
  static const String _loadsKey = 'pending_loads';
  static const String _billsKey = 'saved_bills';
  static const String _settingsKey = 'household_settings';
  static const String _debugDisableStorageKey = 'debug_disable_storage';

  /// Save loads to persistent storage
  static Future<void> saveLoads(List<ScheduledLoad> loads) async {
    try {
      // Check if storage is disabled for debugging
      final prefs = await SharedPreferences.getInstance();
      final storageDisabled = prefs.getBool(_debugDisableStorageKey) ?? false;

      if (storageDisabled) {
        debugPrint('Storage disabled - skipping save');
        return;
      }

      final loadsJson = loads.map((load) => _loadToJson(load)).toList();
      final jsonString = jsonEncode(loadsJson);
      await prefs.setString(_loadsKey, jsonString);
      debugPrint('Saved ${loads.length} loads to storage');
    } catch (e) {
      debugPrint('Error saving loads: $e');
      debugPrint('Storage may not be available. Run "flutter clean && flutter pub get" and rebuild.');
    }
  }

  /// Load loads from persistent storage
  static Future<List<ScheduledLoad>> loadLoads() async {
    try {
      // Check if storage is disabled for debugging
      final prefs = await SharedPreferences.getInstance();
      final storageDisabled = prefs.getBool(_debugDisableStorageKey) ?? false;

      if (storageDisabled) {
        debugPrint('Storage disabled - returning empty list');
        return [];
      }

      final jsonString = prefs.getString(_loadsKey);
      if (jsonString == null) {
        debugPrint('No saved loads found');
        return [];
      }

      final List<dynamic> loadsJson = jsonDecode(jsonString);
      final loads = loadsJson
          .map((json) => _loadFromJson(json as Map<String, dynamic>))
          .whereType<ScheduledLoad>() // Filter out any null values
          .toList();

      debugPrint('Loaded ${loads.length} loads from storage');
      return loads;
    } catch (e) {
      debugPrint('Error loading loads: $e');
      debugPrint('Storage may not be available. Run "flutter clean && flutter pub get" and rebuild.');
      return [];
    }
  }

  /// Clear all stored loads
  static Future<void> clearLoads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_loadsKey);
      debugPrint('Cleared stored loads');
    } catch (e) {
      debugPrint('Error clearing loads: $e');
    }
  }

  /// Set whether storage is disabled for debugging
  static Future<void> setStorageDisabled(bool disabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_debugDisableStorageKey, disabled);
      debugPrint('Storage ${disabled ? 'disabled' : 'enabled'}');
    } catch (e) {
      debugPrint('Error setting storage disabled flag: $e');
    }
  }

  /// Check if storage is currently disabled
  static Future<bool> isStorageDisabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_debugDisableStorageKey) ?? false;
    } catch (e) {
      debugPrint('Error checking storage disabled flag: $e');
      return false;
    }
  }

  /// Convert a ScheduledLoad to JSON
  static Map<String, dynamic> _loadToJson(ScheduledLoad load) {
    return {
      'id': load.id,
      'appliance': load.appliance,
      'iconCodePoint': load.icon.codePoint,
      'loadWatts': load.loadWatts,
      'minTimeLeftMinutes': load.minTimeLeft.inMinutes,
      'maxTimeLeftMinutes': load.maxTimeLeft.inMinutes,
      'isPinned': load.isPinned,
    };
  }

  /// Convert JSON to a ScheduledLoad
  static ScheduledLoad? _loadFromJson(Map<String, dynamic> json) {
    try {
      return ScheduledLoad(
        id: json['id'] as String,
        appliance: json['appliance'] as String,
        icon: IconData(
          json['iconCodePoint'] as int,
          fontFamily: 'MaterialIcons',
        ),
        loadWatts: json['loadWatts'] as int,
        minTimeLeft: Duration(minutes: json['minTimeLeftMinutes'] as int),
        maxTimeLeft: Duration(minutes: json['maxTimeLeftMinutes'] as int),
        isPinned: json['isPinned'] as bool,
      );
    } catch (e) {
      debugPrint('Error parsing load from JSON: $e');
      return null;
    }
  }

  /// Save bills to persistent storage
  static Future<void> saveBills(List<Bill> bills) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageDisabled = prefs.getBool(_debugDisableStorageKey) ?? false;

      if (storageDisabled) {
        debugPrint('Storage disabled - skipping bill save');
        return;
      }

      final billsJson = bills.map((bill) => _billToJson(bill)).toList();
      final jsonString = jsonEncode(billsJson);
      await prefs.setString(_billsKey, jsonString);
      debugPrint('Saved ${bills.length} bills to storage');
    } catch (e) {
      debugPrint('Error saving bills: $e');
    }
  }

  /// Load bills from persistent storage
  static Future<List<Bill>> loadBills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageDisabled = prefs.getBool(_debugDisableStorageKey) ?? false;

      if (storageDisabled) {
        debugPrint('Storage disabled - returning empty bill list');
        return [];
      }

      final jsonString = prefs.getString(_billsKey);
      if (jsonString == null) {
        debugPrint('No saved bills found');
        return [];
      }

      final List<dynamic> billsJson = jsonDecode(jsonString);
      final bills = billsJson
          .map((json) => _billFromJson(json as Map<String, dynamic>))
          .whereType<Bill>()
          .toList();

      debugPrint('Loaded ${bills.length} bills from storage');
      return bills;
    } catch (e) {
      debugPrint('Error loading bills: $e');
      return [];
    }
  }

  /// Clear all stored bills
  static Future<void> clearBills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_billsKey);
      debugPrint('Cleared stored bills');
    } catch (e) {
      debugPrint('Error clearing bills: $e');
    }
  }

  /// Convert a Bill to JSON
  static Map<String, dynamic> _billToJson(Bill bill) {
    return {
      'id': bill.id,
      'month': bill.month.toIso8601String(),
      'totalAmount': bill.totalAmount,
      'breakdown': bill.breakdown.map(
        (key, value) => MapEntry(key, {
          'name': value.name,
          'amount': value.amount,
          'kwh': value.kwh,
          // Don't serialize color - derive it from appliance name on load
        }),
      ),
      if (bill.taxes != null) 'taxes': bill.taxes,
      if (bill.fees != null) 'fees': bill.fees,
    };
  }

  /// Convert JSON to a Bill
  static Bill? _billFromJson(Map<String, dynamic> json) {
    try {
      return Bill(
        id: json['id'] as String,
        month: DateTime.parse(json['month'] as String),
        totalAmount: json['totalAmount'] as double,
        breakdown: (json['breakdown'] as Map<String, dynamic>).map((key, value) {
          final data = value as Map<String, dynamic>;
          final name = data['name'] as String;
          return MapEntry(
            key,
            ApplianceConsumption(
              name: name,
              amount: data['amount'] as double,
              kwh: data['kwh'] as double,
              color: _getColorForAppliance(name),
            ),
          );
        }),
        taxes: json['taxes'] as double?,
        fees: json['fees'] as double?,
      );
    } catch (e) {
      debugPrint('Error parsing bill from JSON: $e');
      return null;
    }
  }

  /// Get the standard color for an appliance based on its name
  static Color _getColorForAppliance(String name) {
    switch (name.toLowerCase()) {
      case 'heating':
        return BillUtils.heatingColor;
      case 'water heater':
        return BillUtils.waterHeaterColor;
      case 'refrigerator':
        return BillUtils.refrigeratorColor;
      case 'washing machine':
        return BillUtils.washingMachineColor;
      case 'dishwasher':
        return BillUtils.dishwasherColor;
      case 'other':
        return BillUtils.otherColor;
      default:
        return BillUtils.otherColor; // Fallback for unknown appliances
    }
  }

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

  /// Clear all data (settings, bills, and loads)
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception('Failed to clear all data: $e');
    }
  }
}
