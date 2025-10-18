import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'models.dart';
import 'bill_models.dart';
import '../services/optimal_t.dart';

class TimeFormatter {
  // Cache for formatArrivalTimes to avoid expensive recalculations
  static final Map<String, _ArrivalTimeCache> _arrivalTimeCache = {};

  static String formatRelativeTime(int minutes) {
    if (minutes == 0) return 'Now';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    return '$hours h $mins min';
  }

  static String formatTimeFromMinutes(int minutes) {
    final now = DateTime.now();
    // Round now to the minute to match minutesToHour calculation
    final nowRounded = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    final targetTime = nowRounded.add(Duration(minutes: minutes));

    // Round to nearest 15-minute tariff boundary
    final minutesSinceMidnight = targetTime.hour * 60 + targetTime.minute;
    final roundedMinutes = ((minutesSinceMidnight / 15).round() * 15);
    final roundedTime = DateTime(
      targetTime.year,
      targetTime.month,
      targetTime.day,
    ).add(Duration(minutes: roundedMinutes));

    return '${roundedTime.hour.toString().padLeft(2, '0')}:${roundedTime.minute.toString().padLeft(2, '0')}';
  }

  /// Calculate minutes from now to reach a specific hour today/tomorrow
  static int minutesToHour(int targetHour) {
    final now = DateTime.now();
    // Start from current hour:minute, ignoring seconds to avoid rounding errors
    final nowRounded = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    var target = DateTime(now.year, now.month, now.day, targetHour, 0);
    if (target.isBefore(nowRounded) || target == nowRounded) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(nowRounded).inMinutes;
  }

  /// Formats multiple time points for display on appliance cards.
  /// Returns either relative times ("In 10 min, 40 min, 1 hour")
  /// or absolute times ("At 14:00, 14:45, 16:00") depending on the window.
  static String formatArrivalTimes(ScheduledLoad load) {
    final now = DateTime.now();

    // Check cache (invalidate every minute)
    final cacheKey = load.id;
    final cached = _arrivalTimeCache[cacheKey];
    if (cached != null &&
        now.difference(cached.timestamp).inSeconds < 60) {
      return cached.result;
    }

    final window = OptimalTimeService.windowForLoad(load);

    // Convert relative durations to actual DateTime objects
    var minTime = now.add(window.minTimeLeft);
    var maxTime = now.add(window.maxTimeLeft);

    // Ensure times are in chronological order
    if (minTime.isAfter(maxTime)) {
      final temp = minTime;
      minTime = maxTime;
      maxTime = temp;
    }

    // Round to 15-minute intervals from midnight (tariff boundaries)
    minTime = _roundTo15MinuteInterval(minTime);
    maxTime = _roundTo15MinuteInterval(maxTime);

    // Ensure rounded times are not in the past
    if (minTime.isBefore(now) || minTime.isAtSameMomentAs(now)) {
      minTime = _nextTariffBoundary(now);
    }
    if (maxTime.isBefore(now) || maxTime.isAtSameMomentAs(now)) {
      maxTime = _nextTariffBoundary(now);
    }

    // Ensure they're still ordered after rounding
    if (minTime.isAfter(maxTime)) {
      final temp = minTime;
      minTime = maxTime;
      maxTime = temp;
    }

    // Convert back to minutes from now
    var minMinutes = minTime.difference(now).inMinutes;
    var maxMinutes = maxTime.difference(now).inMinutes;

    // Collect distinct time points at least 15 minutes apart
    final timePoints = <int>[minMinutes];

    // Add middle point only if it's at least 15 min from start and end
    if (maxMinutes - minMinutes >= 30) {
      final midTime = minTime.add(
        Duration(minutes: (maxMinutes - minMinutes) ~/ 2),
      );
      final roundedMidTime = _roundTo15MinuteInterval(midTime);
      final midMinutes = roundedMidTime.difference(now).inMinutes;

      if (midMinutes - minMinutes >= 15 && maxMinutes - midMinutes >= 15) {
        timePoints.add(midMinutes);
      }
    }

    // Add end point only if different from start
    if (maxMinutes - minMinutes >= 15) {
      timePoints.add(maxMinutes);
    }

    // Use relative format if max is within 2 hours
    String result;
    if (maxMinutes <= 120) {
      final times = timePoints.map(formatRelativeTime).toList();
      final firstTime = times.first;
      // Don't add "In" prefix if the first time is "Now"
      result = firstTime == 'Now' ? times.join(', ') : 'In ${times.join(', ')}';
    } else {
      // Use absolute format for longer windows
      final times = timePoints.map(formatTimeFromMinutes).toList();
      result = 'At ${times.join(', ')}';
    }

    // Cache the result
    _arrivalTimeCache[cacheKey] = _ArrivalTimeCache(now, result);

    return result;
  }

  /// Rounds a DateTime to the nearest 15-minute interval from midnight
  static DateTime _roundTo15MinuteInterval(DateTime time) {
    final minutesSinceMidnight = time.hour * 60 + time.minute;
    final roundedMinutes = ((minutesSinceMidnight / 15).round() * 15);
    return DateTime(
      time.year,
      time.month,
      time.day,
    ).add(Duration(minutes: roundedMinutes));
  }

  /// Returns the next 15-minute tariff boundary after the given time
  static DateTime _nextTariffBoundary(DateTime time) {
    final minutesSinceMidnight = time.hour * 60 + time.minute;
    final nextBoundary = ((minutesSinceMidnight / 15).ceil() * 15);
    return DateTime(
      time.year,
      time.month,
      time.day,
    ).add(Duration(minutes: nextBoundary));
  }
}

class _ArrivalTimeCache {
  final DateTime timestamp;
  final String result;

  _ArrivalTimeCache(this.timestamp, this.result);
}

class ApplianceUtils {
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
      ApplianceOption('Air Conditioner', Icons.ac_unit_outlined, 3500),
      ApplianceOption('Space Heater', Icons.heat_pump_outlined, 1500),
      ApplianceOption('Oven', Icons.kitchen_outlined, 2400),
      ApplianceOption('Hot Tub', Icons.hot_tub_outlined, 4500),
      ApplianceOption('Dehumidifier', Icons.water_damage_outlined, 700),
      ApplianceOption(
        'Battery Storage',
        Icons.battery_charging_full_outlined,
        5000,
      ),
      ApplianceOption('Custom Load', Icons.tune, 0),
    ];
  }

  static double potentialSavings(
    int watts, {
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return OptimalTimeService.calculateSavings(
      watts: watts,
      startTime: startTime,
      endTime: endTime,
    );
  }
}

class BillUtils {
  /// Month names for display
  static const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Short month names for charts
  static const monthNamesShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Default appliance colors
  static const heatingColor = Color(0xFFFF6B6B);
  static const waterHeaterColor = Color(0xFF4ECDC4);
  static const refrigeratorColor = Color(0xFF45B7D1);
  static const washingMachineColor = Color(0xFF96CEB4);
  static const dishwasherColor = Color(0xFFFECEA8);
  static const otherColor = Color(0xFFDFE6E9);

  /// Format a month for display (e.g., "January 2024")
  static String formatMonth(DateTime month) {
    return '${monthNames[month.month - 1]} ${month.year}';
  }

  /// Format a month for short display (e.g., "Jan")
  static String formatMonthShort(DateTime month) {
    return monthNamesShort[month.month - 1];
  }

  /// Assumed average electricity price in EUR/kWh for conversions
  /// Typical Lithuanian residential rate is around 0.15-0.25 EUR/kWh
  static const double averageElectricityPricePerKwh = 0.20;

  /// Create default bill breakdown based on total amount
  static Map<String, ApplianceConsumption> createDefaultBillBreakdown(
    double totalAmount,
  ) {
    // Convert EUR to kWh by dividing by price per kWh
    double eurToKwh(double euros) => euros / averageElectricityPricePerKwh;

    return {
      'Heating': ApplianceConsumption(
        name: 'Heating',
        amount: totalAmount * 0.45,
        kwh: eurToKwh(totalAmount * 0.45),
        color: heatingColor,
      ),
      'Water Heater': ApplianceConsumption(
        name: 'Water Heater',
        amount: totalAmount * 0.20,
        kwh: eurToKwh(totalAmount * 0.20),
        color: waterHeaterColor,
      ),
      'Refrigerator': ApplianceConsumption(
        name: 'Refrigerator',
        amount: totalAmount * 0.12,
        kwh: eurToKwh(totalAmount * 0.12),
        color: refrigeratorColor,
      ),
      'Washing Machine': ApplianceConsumption(
        name: 'Washing Machine',
        amount: totalAmount * 0.08,
        kwh: eurToKwh(totalAmount * 0.08),
        color: washingMachineColor,
      ),
      'Dishwasher': ApplianceConsumption(
        name: 'Dishwasher',
        amount: totalAmount * 0.07,
        kwh: eurToKwh(totalAmount * 0.07),
        color: dishwasherColor,
      ),
      'Other': ApplianceConsumption(
        name: 'Other',
        amount: totalAmount * 0.08,
        kwh: eurToKwh(totalAmount * 0.08),
        color: otherColor,
      ),
    };
  }

  /// Get total kWh consumption from a bill
  static double getTotalKwh(Bill bill) {
    return bill.breakdown.values.fold<double>(
      0,
      (sum, item) => sum + item.kwh,
    );
  }
}

class StatsUtils {
  /// Calculate normal distribution probability density function
  static double normalPdf(double x, double mean, double stdDev) {
    final exponent = -((x - mean) * (x - mean)) / (2 * stdDev * stdDev);
    return (1 / (stdDev * math.sqrt(2 * math.pi))) * math.exp(exponent);
  }

  /// Calculate mean of a list of numbers
  static double mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate standard deviation of a list of numbers
  static double stdDev(List<double> values) {
    if (values.isEmpty) return 0;
    final avg = mean(values);
    final variance = values
        .map((v) => math.pow(v - avg, 2))
        .reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }
}
