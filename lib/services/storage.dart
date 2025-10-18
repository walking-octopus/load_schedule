import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';

class StorageService {
  static const String _loadsKey = 'pending_loads';
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
}
