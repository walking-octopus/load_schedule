import 'package:flutter/material.dart';

class ScheduledLoad {
  final String id;
  final String appliance;
  final IconData icon;
  final int loadWatts;
  final Duration minTimeLeft;
  final Duration maxTimeLeft;
  final bool isPinned;

  ScheduledLoad({
    String? id,
    required this.appliance,
    required this.icon,
    required this.loadWatts,
    required this.minTimeLeft,
    required this.maxTimeLeft,
    this.isPinned = false,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_$appliance';
}

class ApplianceOption {
  final String name;
  final IconData icon;
  final int watts;

  ApplianceOption(this.name, this.icon, this.watts);
}

enum ScheduleMode { relative, absolute }
