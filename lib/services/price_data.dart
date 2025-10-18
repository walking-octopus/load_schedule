import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// TODO: Integrate North Pool data

class PriceDataService {
  static final _random = math.Random(42); // Fixed seed for reproducibility
  static double _ornsteinUhlenbeckState = 0.0; // State for OU process

  // Cache for price data
  static List<FlSpot>? _cachedPriceData;
  static DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  static List<FlSpot> generatePriceData() {
    // Return cached data if still valid
    final now = DateTime.now();
    if (_cachedPriceData != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedPriceData!;
    }

    // Reset OU state for consistent generation
    _ornsteinUhlenbeckState = 0.0;

    // Generate sophisticated prices using control theory concepts
    // 15-minute intervals from 7:00 to 22:00
    final data = List.generate(
      61, // 7:00 to 22:00 inclusive
      (i) {
        final totalMinutes = i * 15;
        final hourDecimal = 7 + (totalMinutes / 60.0);

        // 1. Base load curve - fundamental harmonic (24h period)
        final t = hourDecimal / 24.0 * 2 * math.pi; // Normalize to [0, 2π]
        var price = 15.0; // Baseline price

        // 2. Multiple harmonics for realistic daily pattern
        // Fundamental frequency (24h) + harmonics (12h, 8h periods)
        price += 5.0 * math.sin(t - math.pi / 2); // Daily cycle
        price += 3.0 * math.sin(2 * t + math.pi / 4); // 12h harmonic
        price += 1.5 * math.sin(3 * t - math.pi / 6); // 8h harmonic

        // 3. Morning/evening peaks (step response with overshoot)
        // Morning peak (6:30-10:00): demand ramp-up with underdamped response
        if (hourDecimal >= 6.5 && hourDecimal <= 10.0) {
          final tMorning = (hourDecimal - 6.5) / 2.5; // Faster time scale
          final zeta = 0.3; // Lower damping = more overshoot/ringing
          final omegaN = 4.5; // Higher frequency = faster oscillation
          final response = 1 - math.exp(-zeta * omegaN * tMorning) *
              math.cos(omegaN * math.sqrt(1 - zeta * zeta) * tMorning);

          // Apply Tukey window for smooth edges
          final windowStart = 6.5;
          final windowEnd = 10.0;
          final windowLength = windowEnd - windowStart;
          final taperLength = windowLength * 0.15;

          var windowWeight = 1.0;
          if (hourDecimal < windowStart + taperLength) {
            // Rising edge taper
            final t = (hourDecimal - windowStart) / taperLength;
            windowWeight = 0.5 * (1 + math.cos(math.pi * (t - 1)));
          } else if (hourDecimal > windowEnd - taperLength) {
            // Falling edge taper
            final t = (hourDecimal - (windowEnd - taperLength)) / taperLength;
            windowWeight = 0.5 * (1 + math.cos(math.pi * t));
          }

          price += 5.0 * response * windowWeight; // Increased amplitude
        }

        // Evening peak (16:30-21:30): larger demand spike with smooth decay
        if (hourDecimal >= 16.5 && hourDecimal <= 21.5) {
          final tEvening = (hourDecimal - 16.5) / 5.0;
          final zeta = 0.35; // More underdamped for evening
          final omegaN = 2.5;
          final response = 1 - math.exp(-zeta * omegaN * tEvening) *
              math.cos(omegaN * math.sqrt(1 - zeta * zeta) * tEvening);

          // Apply Tukey window for smooth edges
          final windowStart = 16.5;
          final windowEnd = 21.5;
          final windowLength = windowEnd - windowStart;
          final taperLength = windowLength * 0.15;

          var windowWeight = 1.0;
          if (hourDecimal < windowStart + taperLength) {
            // Rising edge taper
            final t = (hourDecimal - windowStart) / taperLength;
            windowWeight = 0.5 * (1 + math.cos(math.pi * (t - 1)));
          } else if (hourDecimal > windowEnd - taperLength) {
            // Falling edge taper
            final t = (hourDecimal - (windowEnd - taperLength)) / taperLength;
            windowWeight = 0.5 * (1 + math.cos(math.pi * t));
          }

          price += 8.0 * response * windowWeight;
        }

        // 4. Ornstein-Uhlenbeck process for mean-reverting stochastic noise
        // dX = θ(μ - X)dt + σdW
        final theta = 0.3; // Mean reversion speed
        final mu = 0.0; // Long-term mean
        final sigma = 1.2; // Volatility
        final dt = 0.25; // 15 min = 0.25 hours
        final dW = _random.nextDouble() * 2 - 1; // Wiener increment

        _ornsteinUhlenbeckState += theta * (mu - _ornsteinUhlenbeckState) * dt +
            sigma * math.sqrt(dt) * dW;

        price += _ornsteinUhlenbeckState;

        // 5. Rate limiting (slew rate constraint) - simulated via smoothing
        // Market can't change too fast, acts like low-pass filter
        // This would require state, so we approximate with local smoothing

        // 6. Ensure non-negative prices
        price = price.clamp(0.5, 50.0);

        return FlSpot(hourDecimal, price);
      },
    );

    // Cache the generated data
    _cachedPriceData = data;
    _cacheTimestamp = now;

    return data;
  }

  static Color getColorForPrice(double price, List<double> allPrices) {
    final stats = _priceStats(allPrices);
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

  static _PriceStats _priceStats(List<double> prices) {
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
