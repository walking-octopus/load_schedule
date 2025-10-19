import 'package:flutter/material.dart';

class Bill {
  final String id;
  final DateTime month;
  final double totalAmount;
  final Map<String, ApplianceConsumption> breakdown;
  final double? taxes; // Optional taxes amount in EUR
  final double? fees; // Optional distribution/network fees in EUR

  Bill({
    required this.id,
    required this.month,
    required this.totalAmount,
    required this.breakdown,
    this.taxes,
    this.fees,
  });

  /// Get the subtotal (total before taxes and fees)
  double get subtotal {
    final taxesAmount = taxes ?? 0.0;
    final feesAmount = fees ?? 0.0;
    return totalAmount - taxesAmount - feesAmount;
  }

  /// Get the energy cost (sum of all appliance consumption)
  double get energyCost {
    return breakdown.values.fold<double>(0, (sum, item) => sum + item.amount);
  }
}

class ApplianceConsumption {
  final String name;
  final double amount; // EUR
  final double kwh;
  final Color color;

  ApplianceConsumption({
    required this.name,
    required this.amount,
    required this.kwh,
    required this.color,
  });
}

class MonthlyConsumption {
  final DateTime month;
  final double kwh;
  final bool isPredicted;

  MonthlyConsumption({
    required this.month,
    required this.kwh,
    this.isPredicted = false,
  });
}
