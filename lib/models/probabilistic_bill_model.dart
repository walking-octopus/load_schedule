import 'package:flutter/material.dart';
import '../uncertain.dart';
import '../services/storage.dart';
import '../core/utils.dart';
import '../core/bill_models.dart';

// ignore: unintended_html_in_doc_comment
/// A sophisticated probabilistic bill model using Uncertain<T>
///
/// This model captures the inherent uncertainty in:
/// - Weather variations affecting heating/cooling
/// - Occupancy patterns and behavioral changes
/// - Appliance usage variability
/// - Seasonal trends and anomalies
/// - Measurement errors in smart meters
class ProbabilisticBillModel {
  final HouseholdSettings settings;
  final DateTime month;
  final WeatherProfile weatherProfile;

  // Appliance efficiency multipliers (from settings or defaults)
  final Map<String, double> applianceEfficiency;

  ProbabilisticBillModel({
    required this.settings,
    required this.month,
    required this.weatherProfile,
    this.applianceEfficiency = const {},
  });

  /// Generate uncertain consumption for each appliance category
  Map<String, Uncertain<double>> getUncertainConsumption() {
    return {
      'Heating': _heatingConsumption(),
      'Cooling': _coolingConsumption(),
      'Water Heater': _waterHeaterConsumption(),
      'Refrigerator': _refrigeratorConsumption(),
      'Washing Machine': _washingMachineConsumption(),
      'Dishwasher': _dishwasherConsumption(),
      'Lighting': _lightingConsumption(),
      'Electronics': _electronicsConsumption(),
      if (settings.evBatteryCapacity > 0)
        'EV Charging': _evChargingConsumption(),
      'Other': _otherConsumption(),
    };
  }

  /// Generate a full probabilistic bill with confidence intervals
  ProbabilisticBill generateBill({int sampleCount = 2000}) {
    final uncertainConsumption = getUncertainConsumption();

    // Sum all uncertain consumptions
    final totalUncertainKwh = uncertainConsumption.values.reduce(
      (a, b) => a + b,
    );

    // Generate realized values
    final realizedConsumption = <String, ApplianceConsumptionUncertain>{};

    uncertainConsumption.forEach((name, uncertainKwh) {
      final kwh = uncertainKwh.expectedValue(sampleCount: sampleCount);
      final ci = uncertainKwh.confidenceInterval(
        confidence: 0.90,
        sampleCount: sampleCount,
      );

      realizedConsumption[name] = ApplianceConsumptionUncertain(
        name: name,
        kwh: kwh,
        kwhLower90: ci.lower.toDouble(),
        kwhUpper90: ci.upper.toDouble(),
        amount: kwh * BillUtils.averageElectricityPricePerKwh,
        color: _getColorForAppliance(name),
        uncertainKwh: uncertainKwh,
      );
    });

    final totalKwh = totalUncertainKwh.expectedValue(sampleCount: sampleCount);
    final totalCI = totalUncertainKwh.confidenceInterval(
      confidence: 0.90,
      sampleCount: sampleCount,
    );

    return ProbabilisticBill(
      id: 'bill_${month.millisecondsSinceEpoch}',
      month: month,
      totalKwh: totalKwh,
      totalKwhLower90: totalCI.lower.toDouble(),
      totalKwhUpper90: totalCI.upper.toDouble(),
      totalAmount: totalKwh * BillUtils.averageElectricityPricePerKwh,
      breakdown: realizedConsumption,
      totalUncertainKwh: totalUncertainKwh,
      weatherProfile: weatherProfile,
    );
  }

  // === Heating Consumption Model ===
  Uncertain<double> _heatingConsumption() {
    if (settings.heatingType == 'Gas' || settings.heatingType == 'Oil') {
      return UncertainDistributions.point(0.0); // Non-electric heating
    }

    // Base consumption depends on area and insulation
    final baseKwhPerM2 = settings.heatingType == 'Heat Pump' ? 15.0 : 35.0;
    final baseConsumption =
        settings.area * baseKwhPerM2 * settings.efficiencyFactor;

    // Weather impact: colder = more heating
    final weatherMultiplier = weatherProfile.heatingDegreeMultiplier;

    // Occupancy variability (people home more = more heating)
    final occupancyVariability = UncertainDouble.normal(
      mean: 1.0,
      standardDeviation: 0.15, // ±15% variation
    );

    // Behavioral uncertainty (thermostat settings vary)
    final behavioralNoise = UncertainDouble.normal(
      mean: 1.0,
      standardDeviation: 0.20, // ±20% behavioral variation
    );

    // Combine all factors
    final monthlyHeating =
        UncertainDistributions.point(baseConsumption * weatherMultiplier) *
        occupancyVariability *
        behavioralNoise;

    // Ensure non-negative
    return monthlyHeating.filter((x) => x >= 0);
  }

  // === Cooling Consumption Model ===
  Uncertain<double> _coolingConsumption() {
    // Only for summer months
    if (month.month < 5 || month.month > 9) {
      return UncertainDistributions.point(0.0);
    }

    final hasAC = settings.applianceUsage['Air Conditioner'] != null;
    if (!hasAC) {
      return UncertainDistributions.point(0.0);
    }

    // Base consumption depends on area
    final baseKwhPerM2 = 8.0;
    final baseConsumption =
        settings.area * baseKwhPerM2 * settings.efficiencyFactor;

    // Weather impact: hotter = more cooling
    final weatherMultiplier = weatherProfile.coolingDegreeMultiplier;

    // Usage variability (not all rooms cooled equally)
    final usageVariability = UncertainDouble.normal(
      mean: 0.7, // Only cool ~70% of space
      standardDeviation: 0.15,
    );

    final monthlyCooling =
        UncertainDistributions.point(baseConsumption * weatherMultiplier) *
        usageVariability;

    return monthlyCooling.filter((x) => x >= 0);
  }

  // === Water Heater Consumption Model ===
  Uncertain<double> _waterHeaterConsumption() {
    // Base: 40-50 kWh per person per month
    final basePerPerson = UncertainDouble.normal(
      mean: 45.0,
      standardDeviation: 5.0,
    );

    final occupants = UncertainDistributions.point(
      settings.occupants.toDouble(),
    );

    // Weather factor: colder water in winter needs more heating
    final winterBoost = month.month >= 11 || month.month <= 3 ? 1.2 : 1.0;

    // Efficiency factor based on heater type
    final efficiencyMultiplier = settings.heatingType == 'Heat Pump'
        ? 0.4
        : 1.0;

    return basePerPerson * occupants * winterBoost * efficiencyMultiplier;
  }

  // === Refrigerator Consumption Model ===
  Uncertain<double> _refrigeratorConsumption() {
    // Modern refrigerators: 30-50 kWh/month
    // Older ones: 80-120 kWh/month
    final age = DateTime.now().year - settings.constructionYear;

    final meanConsumption = age > 15 ? 95.0 : 40.0;
    final stdDeviation = age > 15 ? 15.0 : 5.0;

    // Ambient temperature affects efficiency
    final summerPenalty = month.month >= 6 && month.month <= 8 ? 1.15 : 1.0;

    return UncertainDouble.normal(
      mean: meanConsumption * summerPenalty,
      standardDeviation: stdDeviation,
    );
  }

  // === Washing Machine Consumption Model ===
  Uncertain<double> _washingMachineConsumption() {
    // ~1 kWh per load, more occupants = more loads
    final loadsPerWeek = UncertainDouble.normal(
      mean: settings.occupants * 1.5,
      standardDeviation: settings.occupants * 0.3,
    );

    final kwhPerLoad = UncertainDouble.normal(
      mean: 1.0,
      standardDeviation: 0.2,
    );
    final weeksPerMonth = 4.3;

    return loadsPerWeek * kwhPerLoad * weeksPerMonth;
  }

  // === Dishwasher Consumption Model ===
  Uncertain<double> _dishwasherConsumption() {
    final hasDishwasher = settings.applianceUsage['Dishwasher'] != null;
    if (!hasDishwasher) {
      return UncertainDistributions.point(0.0);
    }

    // ~1.5 kWh per load
    final loadsPerWeek = UncertainDouble.normal(
      mean: settings.occupants * 1.0,
      standardDeviation: settings.occupants * 0.25,
    );

    final kwhPerLoad = UncertainDouble.normal(
      mean: 1.5,
      standardDeviation: 0.3,
    );
    final weeksPerMonth = 4.3;

    return loadsPerWeek * kwhPerLoad * weeksPerMonth;
  }

  // === Lighting Consumption Model ===
  Uncertain<double> _lightingConsumption() {
    // LED era: ~5-10 kWh per person per month
    // Varies by season (longer nights in winter)
    final winterBoost = month.month >= 11 || month.month <= 3 ? 1.4 : 0.8;

    final basePerPerson = UncertainDouble.normal(
      mean: 7.5 * winterBoost,
      standardDeviation: 1.5,
    );

    return basePerPerson * settings.occupants;
  }

  // === Electronics Consumption Model ===
  Uncertain<double> _electronicsConsumption() {
    // TVs, computers, chargers, etc.
    // ~20-30 kWh per person per month
    final basePerPerson = UncertainDouble.normal(
      mean: 25.0,
      standardDeviation: 5.0,
    );

    // Work-from-home effect (more usage during certain months)
    final wfhBoost = UncertainDouble.uniform(min: 1.0, max: 1.3);

    return basePerPerson * settings.occupants * wfhBoost;
  }

  // === EV Charging Consumption Model ===
  Uncertain<double> _evChargingConsumption() {
    if (settings.evBatteryCapacity == 0 || settings.evDailyKm == 0) {
      return UncertainDistributions.point(0.0);
    }

    // Typical EV efficiency: 15-20 kWh per 100km
    final kwhPer100Km = UncertainDouble.normal(
      mean: 17.5,
      standardDeviation: 1.5,
    );

    // Daily km with variability
    final dailyKm = UncertainDouble.normal(
      mean: settings.evDailyKm,
      standardDeviation: settings.evDailyKm * 0.3, // ±30% daily variation
    );

    // Weather impact: cold reduces efficiency
    final winterPenalty = month.month >= 11 || month.month <= 3 ? 1.25 : 1.0;

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    return (dailyKm * kwhPer100Km / 100.0 * daysInMonth * winterPenalty).filter(
      (x) => x >= 0,
    );
  }

  // === Other/Miscellaneous Consumption Model ===
  Uncertain<double> _otherConsumption() {
    // Vacuum, hair dryer, microwave, oven, etc.
    // ~5-15 kWh per person per month
    final basePerPerson = UncertainDouble.normal(
      mean: 10.0,
      standardDeviation: 3.0,
    );

    return basePerPerson * settings.occupants;
  }

  Color _getColorForAppliance(String name) {
    switch (name.toLowerCase()) {
      case 'heating':
        return BillUtils.heatingColor;
      case 'cooling':
        return Colors.lightBlue;
      case 'water heater':
        return BillUtils.waterHeaterColor;
      case 'refrigerator':
        return BillUtils.refrigeratorColor;
      case 'washing machine':
        return BillUtils.washingMachineColor;
      case 'dishwasher':
        return BillUtils.dishwasherColor;
      case 'lighting':
        return Colors.yellow;
      case 'electronics':
        return Colors.purple;
      case 'ev charging':
        return Colors.green;
      case 'other':
        return BillUtils.otherColor;
      default:
        return BillUtils.otherColor;
    }
  }
}

/// Weather profile for a given month affecting energy consumption
class WeatherProfile {
  final DateTime month;
  final double heatingDegreeMultiplier; // 0.5 (mild) to 2.0 (very cold)
  final double coolingDegreeMultiplier; // 0.5 (mild) to 2.0 (very hot)

  const WeatherProfile({
    required this.month,
    required this.heatingDegreeMultiplier,
    required this.coolingDegreeMultiplier,
  });

  /// Generate a typical weather profile for Lithuania
  factory WeatherProfile.typical(DateTime month) {
    // Heating degree multipliers by month (Lithuania climate)
    final heatingMultipliers = {
      1: 2.0, // January - very cold
      2: 1.9, // February - very cold
      3: 1.5, // March - cold
      4: 1.0, // April - mild
      5: 0.5, // May - mild
      6: 0.0, // June - warm
      7: 0.0, // July - warm
      8: 0.0, // August - warm
      9: 0.3, // September - mild
      10: 0.8, // October - cool
      11: 1.3, // November - cold
      12: 1.8, // December - very cold
    };

    // Cooling degree multipliers by month
    final coolingMultipliers = {
      1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0,
      5: 0.2, // May - occasional warm days
      6: 0.8, // June - warm
      7: 1.5, // July - hot
      8: 1.3, // August - hot
      9: 0.4, // September - warm days
      10: 0.0, 11: 0.0, 12: 0.0,
    };

    return WeatherProfile(
      month: month,
      heatingDegreeMultiplier: heatingMultipliers[month.month] ?? 0.5,
      coolingDegreeMultiplier: coolingMultipliers[month.month] ?? 0.0,
    );
  }

  /// Generate uncertain weather profile (for prediction)
  factory WeatherProfile.uncertain(DateTime month) {
    final typical = WeatherProfile.typical(month);

    // Add weather uncertainty (±20% from typical)
    final heatingVariation =
        1.0 + (0.4 * (0.5 - (month.millisecondsSinceEpoch % 100) / 100.0));
    final coolingVariation =
        1.0 +
        (0.4 * (0.5 - ((month.millisecondsSinceEpoch + 50) % 100) / 100.0));

    return WeatherProfile(
      month: month,
      heatingDegreeMultiplier:
          typical.heatingDegreeMultiplier * heatingVariation,
      coolingDegreeMultiplier:
          typical.coolingDegreeMultiplier * coolingVariation,
    );
  }
}

/// Probabilistic bill with confidence intervals
class ProbabilisticBill {
  final String id;
  final DateTime month;
  final double totalKwh;
  final double totalKwhLower90; // 90% confidence interval lower bound
  final double totalKwhUpper90; // 90% confidence interval upper bound
  final double totalAmount;
  final Map<String, ApplianceConsumptionUncertain> breakdown;
  final Uncertain<double> totalUncertainKwh;
  final WeatherProfile weatherProfile;

  ProbabilisticBill({
    required this.id,
    required this.month,
    required this.totalKwh,
    required this.totalKwhLower90,
    required this.totalKwhUpper90,
    required this.totalAmount,
    required this.breakdown,
    required this.totalUncertainKwh,
    required this.weatherProfile,
  });

  /// Get confidence level that consumption will exceed a threshold
  double confidenceThatExceeds(double thresholdKwh, {int sampleCount = 1000}) {
    final samples = totalUncertainKwh.take(sampleCount);
    final exceedCount = samples.where((x) => x > thresholdKwh).length;
    return exceedCount / sampleCount;
  }

  /// Get percentile of this bill compared to uncertain distribution
  double getPercentile({int sampleCount = 1000}) {
    return totalUncertainKwh.cdf(value: totalKwh, sampleCount: sampleCount);
  }

  /// Get summary statistics
  String getSummary() {
    final uncertainty = totalKwhUpper90 - totalKwhLower90;
    final uncertaintyPercent = (uncertainty / totalKwh * 100).toStringAsFixed(
      1,
    );

    return 'Expected: ${totalKwh.toStringAsFixed(1)} kWh\n'
        '90% CI: [${totalKwhLower90.toStringAsFixed(1)}, ${totalKwhUpper90.toStringAsFixed(1)}] kWh\n'
        'Uncertainty: ±$uncertaintyPercent%\n'
        'Cost: €${totalAmount.toStringAsFixed(2)}';
  }

  /// Convert probabilistic bill to regular Bill for display
  /// Uses expected values (mean of 90% CI) for display
  Bill toRegularBill() {
    // Import needed for ApplianceConsumption
    final breakdown = <String, ApplianceConsumption>{};

    this.breakdown.forEach((key, value) {
      breakdown[key] = ApplianceConsumption(
        name: value.name,
        kwh: value.kwh,
        amount: value.amount,
        color: value.color,
      );
    });

    return Bill(
      id: id,
      month: month,
      totalAmount: totalAmount,
      breakdown: breakdown,
    );
  }
}

/// Appliance consumption with uncertainty bounds
class ApplianceConsumptionUncertain {
  final String name;
  final double kwh; // Expected value
  final double kwhLower90; // 90% CI lower
  final double kwhUpper90; // 90% CI upper
  final double amount; // EUR
  final Color color;
  final Uncertain<double> uncertainKwh; // Full distribution

  ApplianceConsumptionUncertain({
    required this.name,
    required this.kwh,
    required this.kwhLower90,
    required this.kwhUpper90,
    required this.amount,
    required this.color,
    required this.uncertainKwh,
  });

  /// Get the uncertainty range
  double get uncertaintyRange => kwhUpper90 - kwhLower90;

  /// Get the uncertainty as a percentage of expected value
  double get uncertaintyPercent => (uncertaintyRange / kwh) * 100;
}
