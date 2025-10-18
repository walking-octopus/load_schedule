import '../core/bill_models.dart';
import '../core/utils.dart';
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

  /// Get mock bill for demonstration (fallback)
  static Bill? getMockBill() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);

    return Bill(
      id: 'bill_${lastMonth.millisecondsSinceEpoch}',
      month: lastMonth,
      totalAmount: 142.50,
      breakdown: BillUtils.createDefaultBillBreakdown(142.50),
    );
  }

  static List<MonthlyConsumption> getMonthlyConsumption() {
    final now = DateTime.now();
    final data = <MonthlyConsumption>[];

    // Generate 9 past months + current month (10 total)
    for (int i = 9; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);

      if (i <= 2) {
        // Last 3 months are actual data
        data.add(
          MonthlyConsumption(
            month: month,
            kwh: 620 + (i % 2 == 0 ? 40 : -25) + (i * 5),
          ),
        );
      } else {
        // Older months with some variation
        data.add(
          MonthlyConsumption(month: month, kwh: 650 + ((i % 3) * 30) - 20),
        );
      }
    }

    // Add 2 future months as predicted (total = 12 months)
    final lastActual = data.last.kwh;
    for (int i = 1; i <= 2; i++) {
      final month = DateTime(now.year, now.month + i);
      // Predict slightly lower consumption (assuming optimization)
      data.add(
        MonthlyConsumption(
          month: month,
          kwh: lastActual - (i * 20),
          isPredicted: true,
        ),
      );
    }

    return data;
  }
}
