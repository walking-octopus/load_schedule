import 'package:flutter/material.dart';

class Bill {
  final String id;
  final DateTime month;
  final double totalAmount;
  final Map<String, ApplianceConsumption> breakdown;

  Bill({
    required this.id,
    required this.month,
    required this.totalAmount,
    required this.breakdown,
  });
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
