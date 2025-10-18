import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/bill_models.dart';

class BillService {
  static const String _billsKey = 'saved_bills';
  static final List<Bill> _bills = [];

  /// Save a bill to storage
  static Future<void> saveBill(Bill bill) async {
    try {
      _bills.add(bill);
      await _persistBills();
    } catch (e) {
      throw Exception('Failed to save bill: $e');
    }
  }

  /// Load bills from storage
  static Future<void> loadBills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_billsKey);

      if (jsonString != null) {
        final List<dynamic> billsJson = jsonDecode(jsonString);
        _bills.clear();
        _bills.addAll(
          billsJson.map((json) => _billFromJson(json as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('Error loading bills: $e');
    }
  }

  /// Persist bills to storage
  static Future<void> _persistBills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final billsJson = _bills.map((bill) => _billToJson(bill)).toList();
      final jsonString = jsonEncode(billsJson);
      await prefs.setString(_billsKey, jsonString);
    } catch (e) {
      throw Exception('Failed to persist bills: $e');
    }
  }

  /// Convert Bill to JSON
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
          'color': value.color.value,
        }),
      ),
    };
  }

  /// Convert JSON to Bill
  static Bill _billFromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] as String,
      month: DateTime.parse(json['month'] as String),
      totalAmount: json['totalAmount'] as double,
      breakdown: (json['breakdown'] as Map<String, dynamic>).map((key, value) {
        final data = value as Map<String, dynamic>;
        return MapEntry(
          key,
          ApplianceConsumption(
            name: data['name'] as String,
            amount: data['amount'] as double,
            kwh: data['kwh'] as double,
            color: Color(data['color'] as int),
          ),
        );
      }),
    );
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
    await _persistBills();
  }

  // Mock data for demonstration (fallback)
  static Bill? getMockBill() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);

    return Bill(
      id: 'bill_${lastMonth.millisecondsSinceEpoch}',
      month: lastMonth,
      totalAmount: 142.50,
      breakdown: {
        'Heating': ApplianceConsumption(
          name: 'Heating',
          amount: 65.0,
          kwh: 325.0,
          color: const Color(0xFFFF6B6B),
        ),
        'Water Heater': ApplianceConsumption(
          name: 'Water Heater',
          amount: 28.5,
          kwh: 142.5,
          color: const Color(0xFF4ECDC4),
        ),
        'Refrigerator': ApplianceConsumption(
          name: 'Refrigerator',
          amount: 18.0,
          kwh: 90.0,
          color: const Color(0xFF45B7D1),
        ),
        'Washing Machine': ApplianceConsumption(
          name: 'Washing Machine',
          amount: 12.0,
          kwh: 60.0,
          color: const Color(0xFF96CEB4),
        ),
        'Dishwasher': ApplianceConsumption(
          name: 'Dishwasher',
          amount: 9.5,
          kwh: 47.5,
          color: const Color(0xFFFECEA8),
        ),
        'Other': ApplianceConsumption(
          name: 'Other',
          amount: 9.5,
          kwh: 47.5,
          color: const Color(0xFFDFE6E9),
        ),
      },
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
