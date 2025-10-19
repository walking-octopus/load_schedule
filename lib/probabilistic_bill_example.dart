import 'package:powertime/uncertain.dart';

import 'models/probabilistic_bill_model.dart';
import 'services/storage.dart';

/// Demonstration of the probabilistic bill model
void main() {
  print('=== Probabilistic Bill Model Demo ===\n');

  // Create example household settings
  final settings = HouseholdSettings(
    address: 'Vilnius, Lithuania',
    latitude: 54.6872,
    longitude: 25.2797,
    area: 75.0, // 75 m² apartment
    occupants: 2,
    buildingType: 'Apartment',
    constructionYear: 2015,
    heatingType: 'Electric',
    insulationRating: 7.0,
    applianceUsage: {
      'Refrigerator': 24.0,
      'Washing Machine': 1.5,
      'Dishwasher': 1.0,
      'Air Conditioner': 3.0,
    },
    evDailyKm: 40.0,
    evBatteryCapacity: 60.0,
  );

  print('Household Profile:');
  print('  Location: ${settings.address}');
  print('  Area: ${settings.area} m²');
  print('  Occupants: ${settings.occupants}');
  print('  Building: ${settings.buildingType} (${settings.constructionYear})');
  print('  Heating: ${settings.heatingType}');
  print(
    '  EV: ${settings.evDailyKm} km/day (${settings.evBatteryCapacity} kWh battery)',
  );
  print(
    '  Efficiency Factor: ${settings.efficiencyFactor.toStringAsFixed(2)}x\n',
  );

  // Generate bills for different months
  final months = [
    DateTime(2025, 1), // Winter - high heating
    DateTime(2025, 4), // Spring - moderate
    DateTime(2025, 7), // Summer - possible cooling
    DateTime(2025, 10), // Fall - moderate heating
  ];

  for (final month in months) {
    final weatherProfile = WeatherProfile.typical(month);
    final model = ProbabilisticBillModel(
      settings: settings,
      month: month,
      weatherProfile: weatherProfile,
    );

    final bill = model.generateBill(sampleCount: 3000);

    print('=== ${_monthName(month.month)} ${month.year} ===');
    print(
      'Weather: Heating×${weatherProfile.heatingDegreeMultiplier.toStringAsFixed(2)}, '
      'Cooling×${weatherProfile.coolingDegreeMultiplier.toStringAsFixed(2)}',
    );
    print('');
    print(bill.getSummary());
    print('');

    // Show breakdown with confidence intervals
    print('Consumption Breakdown:');
    final sortedBreakdown = bill.breakdown.entries.toList()
      ..sort((a, b) => b.value.kwh.compareTo(a.value.kwh));

    for (final entry in sortedBreakdown) {
      final item = entry.value;
      if (item.kwh > 0.5) {
        // Only show significant consumers
        final percent = (item.kwh / bill.totalKwh * 100).toStringAsFixed(1);
        final uncertainty = item.uncertaintyPercent.toStringAsFixed(1);

        print(
          '  ${item.name.padRight(18)} ${item.kwh.toStringAsFixed(1).padLeft(6)} kWh '
          '(${percent.padLeft(5)}%) '
          '±$uncertainty% '
          '[${item.kwhLower90.toStringAsFixed(1)}-${item.kwhUpper90.toStringAsFixed(1)}]',
        );
      }
    }
    print('');

    // Risk analysis
    final budgetKwh = 800.0;
    final exceedProb = bill.confidenceThatExceeds(budgetKwh);
    print('Budget Analysis:');
    print('  Budget: $budgetKwh kWh');
    print(
      '  Probability of exceeding: ${(exceedProb * 100).toStringAsFixed(1)}%',
    );

    if (exceedProb > 0.5) {
      final safebudget = bill.totalUncertainKwh.quantile(
        quantile: 0.90,
        sampleCount: 2000,
      );
      print(
        '  Recommended budget (90% confidence): ${safebudget.toStringAsFixed(1)} kWh',
      );
    }

    print('');
    print('-' * 70);
    print('');
  }

  // Year-over-year comparison
  print('=== Annual Analysis ===\n');

  var annualTotal = 0.0;
  var annualTotalLower = 0.0;
  var annualTotalUpper = 0.0;
  var annualCost = 0.0;

  for (var m = 1; m <= 12; m++) {
    final month = DateTime(2025, m);
    final weatherProfile = WeatherProfile.typical(month);
    final model = ProbabilisticBillModel(
      settings: settings,
      month: month,
      weatherProfile: weatherProfile,
    );
    final bill = model.generateBill(sampleCount: 2000);

    annualTotal += bill.totalKwh;
    annualTotalLower += bill.totalKwhLower90;
    annualTotalUpper += bill.totalKwhUpper90;
    annualCost += bill.totalAmount;
  }

  print('Annual Consumption:');
  print('  Expected: ${annualTotal.toStringAsFixed(0)} kWh');
  print(
    '  90% CI: [${annualTotalLower.toStringAsFixed(0)}, ${annualTotalUpper.toStringAsFixed(0)}] kWh',
  );
  print('  Expected Cost: €${annualCost.toStringAsFixed(2)}');
  print(
    '  Cost Range: €${(annualTotalLower * 0.20).toStringAsFixed(2)} - '
    '€${(annualTotalUpper * 0.20).toStringAsFixed(2)}',
  );

  final uncertainty = annualTotalUpper - annualTotalLower;
  final uncertaintyPercent = (uncertainty / annualTotal * 100).toStringAsFixed(
    1,
  );
  print('  Annual Uncertainty: ±$uncertaintyPercent%');

  print('');

  // Scenario analysis
  print('=== Scenario Analysis: January 2025 ===\n');

  final januarySettings = [
    ('Typical Winter', WeatherProfile.typical(DateTime(2025, 1))),
    (
      'Mild Winter',
      WeatherProfile(
        month: DateTime(2025, 1),
        heatingDegreeMultiplier: 1.3, // 35% less heating needed
        coolingDegreeMultiplier: 0.0,
      ),
    ),
    (
      'Harsh Winter',
      WeatherProfile(
        month: DateTime(2025, 1),
        heatingDegreeMultiplier: 2.5, // 25% more heating needed
        coolingDegreeMultiplier: 0.0,
      ),
    ),
  ];

  for (final scenario in januarySettings) {
    final model = ProbabilisticBillModel(
      settings: settings,
      month: DateTime(2025, 1),
      weatherProfile: scenario.$2,
    );
    final bill = model.generateBill(sampleCount: 2000);

    print('${scenario.$1}:');
    print(
      '  Consumption: ${bill.totalKwh.toStringAsFixed(1)} kWh '
      '[${bill.totalKwhLower90.toStringAsFixed(1)}-${bill.totalKwhUpper90.toStringAsFixed(1)}]',
    );
    print('  Cost: €${bill.totalAmount.toStringAsFixed(2)}');
    print('');
  }

  // Heating type comparison
  print('=== Heating System Comparison: January ===\n');

  final heatingTypes = [
    ('Electric Heating', 'Electric'),
    ('Heat Pump', 'Heat Pump'),
    ('Gas Heating', 'Gas'),
  ];

  for (final heatingType in heatingTypes) {
    final testSettings = HouseholdSettings(
      address: settings.address,
      latitude: settings.latitude,
      longitude: settings.longitude,
      area: settings.area,
      occupants: settings.occupants,
      buildingType: settings.buildingType,
      constructionYear: settings.constructionYear,
      heatingType: heatingType.$2,
      insulationRating: settings.insulationRating,
      applianceUsage: settings.applianceUsage,
      evDailyKm: settings.evDailyKm,
      evBatteryCapacity: settings.evBatteryCapacity,
    );

    final model = ProbabilisticBillModel(
      settings: testSettings,
      month: DateTime(2025, 1),
      weatherProfile: WeatherProfile.typical(DateTime(2025, 1)),
    );
    final bill = model.generateBill(sampleCount: 2000);

    final heatingConsumption = bill.breakdown['Heating']?.kwh ?? 0.0;

    print('${heatingType.$1}:');
    print('  Heating: ${heatingConsumption.toStringAsFixed(1)} kWh');
    print('  Total: ${bill.totalKwh.toStringAsFixed(1)} kWh');
    print('  Cost: €${bill.totalAmount.toStringAsFixed(2)}');
    print('');
  }

  // Confidence analysis
  print('=== Confidence Analysis: January Bill ===\n');

  final januaryModel = ProbabilisticBillModel(
    settings: settings,
    month: DateTime(2025, 1),
    weatherProfile: WeatherProfile.typical(DateTime(2025, 1)),
  );
  final januaryBill = januaryModel.generateBill(sampleCount: 3000);

  final thresholds = [700.0, 800.0, 900.0, 1000.0];
  print('Probability of exceeding threshold:');
  for (final threshold in thresholds) {
    final prob = januaryBill.confidenceThatExceeds(threshold);
    final bar = '█' * (prob * 50).round();
    print(
      '  ${threshold.toStringAsFixed(0).padLeft(6)} kWh: '
      '${(prob * 100).toStringAsFixed(1).padLeft(5)}% $bar',
    );
  }

  print('');
  print('=== End of Demo ===');
}

String _monthName(int month) {
  const months = [
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
  return months[month - 1];
}
