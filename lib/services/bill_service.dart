import 'package:flutter/foundation.dart';
import '../core/bill_models.dart';
import '../core/utils.dart';
import '../models/probabilistic_bill_model.dart';
import 'storage.dart';

// Top-level function for compute() isolate
ProbabilisticBill _generateBillInIsolate(Map<String, dynamic> params) {
  final settings = HouseholdSettings.fromJson(params['settings'] as Map<String, dynamic>);
  final month = DateTime.fromMillisecondsSinceEpoch(params['monthMillis'] as int);
  final sampleCount = params['sampleCount'] as int;

  final weatherProfile = WeatherProfile.typical(month);
  final model = ProbabilisticBillModel(
    settings: settings,
    month: month,
    weatherProfile: weatherProfile,
  );

  return model.generateBill(sampleCount: sampleCount);
}

/// Service for managing bills and consumption data
class BillService {
  static final List<Bill> _bills = [];

  // Cache for generated bills to avoid expensive recomputation
  static final Map<String, ProbabilisticBill> _billCache = {};
  static HouseholdSettings? _cachedSettings;

  /// Generate cache key for a specific month and settings
  static String _getCacheKey(DateTime month, HouseholdSettings settings) {
    // Include key settings that affect bill generation
    return '${month.year}-${month.month}_${settings.hashCode}';
  }

  /// Clear the bill cache (e.g., when settings change)
  static void clearCache() {
    _billCache.clear();
    _cachedSettings = null;
  }

  /// Generate a bill using an isolate to avoid blocking the UI thread
  /// Results are cached to avoid regenerating the same bill
  static Future<ProbabilisticBill> _generateBillAsync(
    HouseholdSettings settings,
    DateTime month,
    int sampleCount,
  ) async {
    // Check if settings have changed, if so clear cache
    if (_cachedSettings != null && _cachedSettings.hashCode != settings.hashCode) {
      clearCache();
    }
    _cachedSettings = settings;

    // Check cache first
    final cacheKey = _getCacheKey(month, settings);
    if (_billCache.containsKey(cacheKey)) {
      return _billCache[cacheKey]!;
    }

    // Generate new bill and cache it
    final bill = await compute(
      _generateBillInIsolate,
      {
        'settings': settings.toJson(),
        'monthMillis': month.millisecondsSinceEpoch,
        'sampleCount': sampleCount,
      },
    );

    _billCache[cacheKey] = bill;
    return bill;
  }

  /// Save a bill
  static Future<void> saveBill(Bill bill) async {
    _bills.add(bill);
    await StorageService.saveBills(_bills);
  }

  /// Create a bill breakdown using the probabilistic model
  /// If settings are available, generates realistic breakdown based on household
  /// Otherwise falls back to static percentages
  static Future<Map<String, ApplianceConsumption>> createBillBreakdown(
    double totalAmount,
    DateTime month,
  ) async {
    final settings = await StorageService.loadSettings();

    if (settings != null) {
      // Use probabilistic model to generate realistic breakdown (using isolate)
      final probabilisticBill = await _generateBillAsync(
        settings,
        month,
        1000,
      );

      // Scale the breakdown to match the user's actual total amount
      final modelTotal = probabilisticBill.totalAmount;
      final scaleFactor = totalAmount / modelTotal;

      final breakdown = <String, ApplianceConsumption>{};
      probabilisticBill.breakdown.forEach((key, value) {
        breakdown[key] = ApplianceConsumption(
          name: value.name,
          kwh: value.kwh * scaleFactor,
          amount: value.amount * scaleFactor,
          color: value.color,
        );
      });

      return breakdown;
    } else {
      // Fall back to static breakdown
      return BillUtils.createDefaultBillBreakdown(totalAmount);
    }
  }

  /// Load bills from storage
  static Future<void> loadBills() async {
    final loadedBills = await StorageService.loadBills();
    _bills.clear();
    _bills.addAll(loadedBills);
  }

  /// Get the latest bill
  static Bill? getLatestBill() {
    if (_bills.isEmpty) return null;
    _bills.sort((a, b) => b.month.compareTo(a.month));
    return _bills.first;
  }

  /// Get all bills
  static List<Bill> getAllBills() {
    final sortedBills = List<Bill>.from(_bills);
    sortedBills.sort((a, b) => b.month.compareTo(a.month));
    return sortedBills;
  }

  /// Get bills for a specific month
  static Bill? getBillForMonth(DateTime month) {
    return _bills.firstWhere(
      (bill) =>
          bill.month.year == month.year && bill.month.month == month.month,
      orElse: () => throw StateError('No bill found for month'),
    );
  }

  /// Check if a bill exists for a specific month
  static bool hasBillForMonth(DateTime month) {
    return _bills.any(
      (bill) =>
          bill.month.year == month.year && bill.month.month == month.month,
    );
  }

  /// Delete a bill
  static Future<void> deleteBill(String billId) async {
    _bills.removeWhere((bill) => bill.id == billId);
    await StorageService.saveBills(_bills);
  }

  static Future<List<MonthlyConsumption>> getMonthlyConsumption() async {
    final data = <MonthlyConsumption>[];

    // Return actual bills data
    for (final bill in _bills) {
      final totalKwh = bill.breakdown.values.fold<double>(
        0,
        (sum, item) => sum + item.kwh,
      );
      data.add(
        MonthlyConsumption(
          month: bill.month,
          kwh: totalKwh,
          isPredicted: false,
        ),
      );
    }

    // Add predicted future months if settings are configured
    final settings = await StorageService.loadSettings();
    if (settings != null) {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);

      // Generate predictions for next 12 months
      for (var i = 0; i < 12; i++) {
        final futureMonth = DateTime(currentMonth.year, currentMonth.month + i);

        // Skip if we already have actual data for this month
        if (_bills.any(
          (b) =>
              b.month.year == futureMonth.year &&
              b.month.month == futureMonth.month,
        )) {
          continue;
        }

        // Generate prediction using isolate to avoid blocking UI
        final probabilisticBill = await _generateBillAsync(
          settings,
          futureMonth,
          1000,
        );

        data.add(
          MonthlyConsumption(
            month: futureMonth,
            kwh: probabilisticBill.totalKwh,
            isPredicted: true,
          ),
        );
      }
    }

    // Sort by month
    data.sort((a, b) => a.month.compareTo(b.month));
    return data;
  }

  /// Generate a predicted bill for a specific month using the probabilistic model
  /// Returns null if household settings are not configured
  static Future<Bill?> generatePredictedBill(DateTime month) async {
    final settings = await StorageService.loadSettings();
    if (settings == null) return null;

    // Check if we already have an actual bill for this month
    if (hasBillForMonth(month)) {
      return null;
    }

    final probabilisticBill = await _generateBillAsync(
      settings,
      month,
      2000,
    );
    return probabilisticBill.toRegularBill();
  }

  /// Get the latest bill (actual or predicted)
  /// If no actual bills exist, generates a prediction for current month
  static Future<Bill?> getLatestBillOrPrediction() async {
    final actualBill = getLatestBill();
    if (actualBill != null) return actualBill;

    // Generate prediction for current month
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    return await generatePredictedBill(currentMonth);
  }
}
