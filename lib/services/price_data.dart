import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// TODO: Integrate North Pool data

class PriceDataService {
  static List<FlSpot> generatePriceData() {
    return List.generate(
      25,
      (i) => FlSpot(
        i.toDouble(),
        10 + (i * 1.5) + (i % 4 * 8) + math.sin(i * 0.5) * 5,
      ),
    );
  }

  static Color getColorForPrice(double price, List<double> allPrices) {
    final stats = _calculatePriceStats(allPrices);
    final normalizedPrice = (price - stats.mean) / (stats.stdDev + 0.001);
    final t = ((normalizedPrice + 2) / 4).clamp(0.0, 1.0);

    if (t < 0.5) {
      return Color.lerp(
        const Color(0xFF4CAF50),
        const Color(0xFFFFC107),
        t * 2,
      )!;
    } else {
      return Color.lerp(
        const Color(0xFFFFC107),
        const Color(0xFFF44336),
        (t - 0.5) * 2,
      )!;
    }
  }

  static _PriceStats _calculatePriceStats(List<double> prices) {
    final mean = prices.reduce((a, b) => a + b) / prices.length;
    final variance =
        prices.map((p) => math.pow(p - mean, 2)).reduce((a, b) => a + b) /
        prices.length;
    final stdDev = math.sqrt(variance);
    return _PriceStats(mean, stdDev);
  }
}

class _PriceStats {
  final double mean;
  final double stdDev;
  _PriceStats(this.mean, this.stdDev);
}
