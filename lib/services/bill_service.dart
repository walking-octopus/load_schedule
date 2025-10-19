import '../core/bill_models.dart';
import '../core/utils.dart';
import '../models/probabilistic_bill_model.dart';
import 'storage.dart';

/// Service for managing bills and consumption data
class BillService {
  static final List<Bill> _bills = [];

  /// Save a bill
  static Future<void> saveBill(Bill bill) async {
    _bills.add(bill);
    await StorageService.saveBills(_bills);
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

  static List<MonthlyConsumption> getMonthlyConsumption() {
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
        ),
      );
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

    final weatherProfile = WeatherProfile.typical(month);
    final model = ProbabilisticBillModel(
      settings: settings,
      month: month,
      weatherProfile: weatherProfile,
    );

    final probabilisticBill = model.generateBill(sampleCount: 2000);
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
