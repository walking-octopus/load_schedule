import 'package:flutter/material.dart';

class ScheduledLoad {
  final String appliance;
  final int loadWatts;
  final Duration minTimeLeft;
  final Duration maxTimeLeft;
  final bool isPinned;

  ScheduledLoad({
    required this.appliance,
    required this.loadWatts,
    required this.minTimeLeft,
    required this.maxTimeLeft,
    this.isPinned = false,
  });
}

class ApplianceOption {
  final String name;
  final IconData icon;
  final int watts;

  ApplianceOption(this.name, this.icon, this.watts);
}

enum ScheduleMode { relative, absolute }
