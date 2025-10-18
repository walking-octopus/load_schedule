import '../core/models.dart';
import 'price_data.dart';

class OptimalTimeService {
  /// Calculates potential savings within a specific time window
  static double calculateSavings({
    required int watts,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    final priceData = PriceDataService.generatePriceData();

    // Filter prices to only those within the operating window
    List<double> prices;
    if (startTime != null && endTime != null) {
      prices = priceData
          .where((spot) {
            final hour = spot.x.toInt();
            return hour >= startTime.hour && hour <= endTime.hour;
          })
          .map((spot) => spot.y)
          .toList();
    } else {
      prices = priceData.map((spot) => spot.y).toList();
    }

    if (prices.isEmpty) {
      // No prices in window, cannot calculate savings
      return 0.0;
    }

    // Calculate savings: difference between max and min price in window
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final minPrice = prices.reduce((a, b) => a < b ? a : b);

    final energyKwh = (watts / 1000) * 1; // Assuming 1 hour runtime
    return energyKwh * (maxPrice - minPrice) / 100; // Convert cents to euros
  }

  /// Returns the optimal window to display for a scheduled load.
  /// Finds the best time to run within the operating window based on price data.
  static DisplayWindow windowForLoad(ScheduledLoad load) {
    final now = DateTime.now();
    final startTime = now.add(load.minTimeLeft);
    final endTime = now.add(load.maxTimeLeft);

    // Get price data
    final priceData = PriceDataService.generatePriceData();

    // Find optimal 1-hour window within the operating window
    final optimalHour = _findOptimalHour(startTime, endTime, priceData);

    if (optimalHour == null) {
      // Fallback to original window if no optimal hour found
      return DisplayWindow(
        minTimeLeft: load.minTimeLeft,
        maxTimeLeft: load.maxTimeLeft,
      );
    }

    // Discretize to 15-minute intervals (since tariffs change every 15 min)
    final optimalMinutes = optimalHour * 60;

    // Round to nearest 15-minute interval
    final roundedOptimalMinutes = ((optimalMinutes / 15).round() * 15);
    final discretizedOptimalTime = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: roundedOptimalMinutes));

    // Calculate tight window around optimal time (±15 minutes for display)
    final displayStart = discretizedOptimalTime.subtract(
      const Duration(minutes: 15),
    );
    final displayEnd = discretizedOptimalTime.add(const Duration(minutes: 45));

    // Ensure display window is within operating window
    var clampedStart = displayStart.isBefore(startTime)
        ? startTime
        : displayStart;
    var clampedEnd = displayEnd.isAfter(endTime) ? endTime : displayEnd;

    // Ensure window doesn't start in the past
    if (clampedStart.isBefore(now)) {
      clampedStart = now;
    }

    // Ensure start is before end (safety check)
    final finalStart = clampedStart.isBefore(clampedEnd)
        ? clampedStart
        : clampedEnd;
    final finalEnd = clampedStart.isBefore(clampedEnd)
        ? clampedEnd
        : clampedStart;

    return DisplayWindow(
      minTimeLeft: finalStart.difference(now),
      maxTimeLeft: finalEnd.difference(now),
    );
  }

  /// Finds the hour with the lowest price within the given time range
  static int? _findOptimalHour(
    DateTime startTime,
    DateTime endTime,
    List<dynamic> priceData,
  ) {
    double? lowestPrice;
    int? bestHour;

    for (var spot in priceData) {
      final hour = spot.x.toInt();
      final price = spot.y as double;

      // Check if this hour is within the operating window
      final hourTime = DateTime(
        startTime.year,
        startTime.month,
        startTime.day,
        hour,
      );

      if (hourTime.isAfter(startTime.subtract(const Duration(hours: 1))) &&
          hourTime.isBefore(endTime.add(const Duration(hours: 1)))) {
        if (lowestPrice == null || price < lowestPrice) {
          lowestPrice = price;
          bestHour = hour;
        }
      }
    }

    return bestHour;
  }
}

class DisplayWindow {
  final Duration minTimeLeft;
  final Duration maxTimeLeft;

  DisplayWindow({required this.minTimeLeft, required this.maxTimeLeft});
}
