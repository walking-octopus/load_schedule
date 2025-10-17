import 'package:flutter/material.dart';
// import 'dart:math' as math;

import 'models.dart';
import 'constants.dart';

class TimeFormatter {
  static String formatScheduleTime(ScheduledLoad load) {
    final minMinutes = load.minTimeLeft.inMinutes;
    final maxMinutes = load.maxTimeLeft.inMinutes;

    if (maxMinutes <= 120) {
      if (minMinutes < 60 && maxMinutes < 60) {
        return '$minMinutes–${maxMinutes}m';
      } else {
        final minHours = minMinutes ~/ 60;
        final maxHours = maxMinutes ~/ 60;
        final maxMins = maxMinutes % 60;
        return maxMins == 0
            ? '$minHours–$maxHours h'
            : '${maxHours}h ${maxMins}m';
      }
    }

    final now = DateTime.now();
    final endTime = now.add(Duration(minutes: maxMinutes));
    return '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
  }

  static String formatRelativeTime(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    return '$hours h $mins min';
  }

  static String formatTimeFromMinutes(int minutes) {
    final now = DateTime.now();
    final targetTime = now.add(Duration(minutes: minutes));
    return '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
  }
}

class ApplianceUtils {
  static IconData getIcon(String appliance) {
    switch (appliance.toLowerCase()) {
      case 'washing machine':
        return Icons.local_laundry_service_outlined;
      case 'dishwasher':
        return Icons.countertops_outlined;
      case 'electric vehicle':
        return Icons.electric_car_outlined;
      case 'water heater':
        return Icons.water_drop_outlined;
      case 'dryer':
        return Icons.dry_outlined;
      case 'pool pump':
        return Icons.pool_outlined;
      default:
        return Icons.power_outlined;
    }
  }

  static List<ApplianceOption> getDefaultAppliances() {
    return [
      ApplianceOption(
        'Washing Machine',
        Icons.local_laundry_service_outlined,
        1500,
      ),
      ApplianceOption('Dishwasher', Icons.countertops_outlined, 1200),
      ApplianceOption('Electric Vehicle', Icons.electric_car_outlined, 7000),
      ApplianceOption('Water Heater', Icons.water_drop_outlined, 3000),
      ApplianceOption('Dryer', Icons.dry_outlined, 2500),
      ApplianceOption('Pool Pump', Icons.pool_outlined, 1800),
      ApplianceOption('Custom Load', Icons.tune, 0),
    ];
  }

  static double calculatePotentialSavings(int watts) {
    final energyKwh = (watts / 1000) * 1;
    return energyKwh * (AppConstants.peakRate - AppConstants.offPeakRate);
  }
}
