import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../../core/bill_models.dart';
import '../../core/utils.dart';

/// Widget for displaying bill breakdown with pie chart and list
class BillBreakdownCard extends StatelessWidget {
  final Bill bill;

  const BillBreakdownCard({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final billMonth = BillUtils.formatMonth(bill.month);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill Breakdown',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Based on your last bill ($billMonth)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '€${bill.totalAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final totalKwh = bill.breakdown.values.fold<double>(
                  0,
                  (sum, item) => sum + item.kwh,
                );
                final daysInMonth = DateTime(bill.month.year, bill.month.month + 1, 0).day;
                final avgWatts = (totalKwh * 1000) / (daysInMonth * 24);
                return Text(
                  '${totalKwh.toStringAsFixed(0)} kWh • ${avgWatts.toStringAsFixed(0)} W avg',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final hasEnoughSpace = constraints.maxWidth > 600;
                if (hasEnoughSpace) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildStackChart(context)),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _buildBreakdownList(context)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildStackChart(context),
                      const SizedBox(height: 16),
                      _buildBreakdownList(context),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackChart(BuildContext context) {
    final sortedBreakdown = bill.breakdown.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Row(
          children: sortedBreakdown.map((consumption) {
            final fraction = consumption.amount / bill.totalAmount;
            return Expanded(
              flex: (fraction * 100).round(),
              child: Container(color: consumption.color),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBreakdownList(BuildContext context) {
    final sortedBreakdown = bill.breakdown.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Calculate average watts per appliance (kWh over ~30 days)
    final daysInMonth = DateTime(bill.month.year, bill.month.month + 1, 0).day;

    final items = <Widget>[];

    // Add appliance consumption items
    for (final consumption in sortedBreakdown) {
      // Convert kWh to average Watts: kWh * 1000 / (days * 24 hours)
      final avgWatts = (consumption.kwh * 1000) / (daysInMonth * 24);

      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: consumption.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    consumption.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${avgWatts.toStringAsFixed(0)} W avg',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '€${consumption.amount.toStringAsFixed(2)}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${consumption.kwh.toStringAsFixed(0)} kWh',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ));
    }

    // Add divider before taxes and fees if they exist
    if ((bill.taxes != null && bill.taxes! > 0) ||
        (bill.fees != null && bill.fees! > 0)) {
      items.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(),
      ));
    }

    // Add distribution/network fees if present
    if (bill.fees != null && bill.fees! > 0) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Distribution fees',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              '€${bill.fees!.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ));
    }

    // Add taxes if present
    if (bill.taxes != null && bill.taxes! > 0) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'VAT (21%)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              '€${bill.taxes!.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ));
    }

    return Column(children: items);
  }
}

/// Widget for displaying monthly consumption graph
class ConsumptionChart extends StatelessWidget {
  final List<MonthlyConsumption> data;

  const ConsumptionChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consumption',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Historical data and model predictions for the next months',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildLegendItem(context, 'Increased', Colors.red),
                    _buildLegendItem(context, 'Decreased', Colors.green),
                    _buildLegendItem(
                      context,
                      'Predicted',
                      Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 200,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()} kWh',
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < data.length) {
                                final month = data[index].month;
                                return Text(
                                  BillUtils.formatMonthShort(month),
                                  style: Theme.of(context).textTheme.bodySmall,
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarGroups(),
                      minY: 0,
                      maxY: 800,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) =>
                              Theme.of(context).colorScheme.inverseSurface,
                          tooltipBorder: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          tooltipBorderRadius: BorderRadius.circular(8),
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final consumption = data[group.x.toInt()];
                            final monthName = BillUtils.formatMonth(
                              consumption.month,
                            );
                            return BarTooltipItem(
                              '${consumption.kwh.toStringAsFixed(0)} kWh\n$monthName',
                              TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onInverseSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final consumption = entry.value;

      // Determine bar color based on comparison with previous month
      Color barColor;
      if (index == 0) {
        barColor = Colors.green;
      } else {
        // Find the last valid month for comparison
        MonthlyConsumption? prevConsumption;
        for (int j = index - 1; j >= 0; j--) {
          if (data[j].kwh > 0) {
            prevConsumption = data[j];
            break;
          }
        }

        if (prevConsumption == null) {
          barColor = Colors.green;
        } else if (consumption.kwh > prevConsumption.kwh) {
          barColor = Colors.red;
        } else if (consumption.kwh < prevConsumption.kwh) {
          barColor = Colors.green;
        } else {
          barColor = Colors.green;
        }
      }

      // For predicted bars, use lower opacity
      final displayColor = consumption.isPredicted
          ? barColor.withValues(alpha: 0.4)
          : barColor;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: consumption.kwh,
            color: displayColor,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Widget for displaying efficiency recommendations
class EfficiencyRecommendationsCard extends StatelessWidget {
  final Bill bill;

  const EfficiencyRecommendationsCard({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final recommendation = _getBestRecommendation();

    // Hide card if savings are below threshold
    if (recommendation == null || recommendation.threeMonthSavings < 15.0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Efficiency Tip',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recommendation.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3-month savings',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '€${recommendation.threeMonthSavings.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Est. upgrade cost',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '€${recommendation.upgradeCost.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (recommendation.threeMonthSavings / recommendation.upgradeCost).clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: Colors.green,
            ),
            const SizedBox(height: 4),
            Text(
              'Payback in ~${(recommendation.upgradeCost / (recommendation.threeMonthSavings / 3)).ceil()} months',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _EfficiencyRecommendation? _getBestRecommendation() {
    final recommendations = <_EfficiencyRecommendation>[];

    // Check heating efficiency
    final heatingConsumption = bill.breakdown['Heating'];
    if (heatingConsumption != null && heatingConsumption.kwh > 200) {
      final monthlySavings = heatingConsumption.amount * 0.35; // 35% improvement
      recommendations.add(_EfficiencyRecommendation(
        title: 'Upgrade to Heat Pump',
        description: 'Your heating costs are high. A heat pump could reduce consumption by up to 35%.',
        threeMonthSavings: monthlySavings * 3,
        upgradeCost: 3500,
        applianceName: 'Heating',
      ));
    }

    // Check water heater efficiency
    final waterHeaterConsumption = bill.breakdown['Water Heater'];
    if (waterHeaterConsumption != null && waterHeaterConsumption.kwh > 100) {
      final monthlySavings = waterHeaterConsumption.amount * 0.25; // 25% improvement
      recommendations.add(_EfficiencyRecommendation(
        title: 'Install Solar Water Heater',
        description: 'A solar water heater could reduce water heating costs by 25%.',
        threeMonthSavings: monthlySavings * 3,
        upgradeCost: 1200,
        applianceName: 'Water Heater',
      ));
    }

    // Check refrigerator efficiency
    final refrigeratorConsumption = bill.breakdown['Refrigerator'];
    if (refrigeratorConsumption != null && refrigeratorConsumption.kwh > 60) {
      final monthlySavings = refrigeratorConsumption.amount * 0.40; // 40% improvement
      recommendations.add(_EfficiencyRecommendation(
        title: 'Upgrade to A+++ Refrigerator',
        description: 'Your refrigerator is consuming a lot. A modern A+++ model could save 40%.',
        threeMonthSavings: monthlySavings * 3,
        upgradeCost: 600,
        applianceName: 'Refrigerator',
      ));
    }

    // Return best recommendation based on ROI (savings / cost)
    if (recommendations.isEmpty) return null;
    recommendations.sort((a, b) {
      final roiA = a.threeMonthSavings / a.upgradeCost;
      final roiB = b.threeMonthSavings / b.upgradeCost;
      return roiB.compareTo(roiA);
    });

    return recommendations.first;
  }
}

class _EfficiencyRecommendation {
  final String title;
  final String description;
  final double threeMonthSavings;
  final double upgradeCost;
  final String applianceName;

  _EfficiencyRecommendation({
    required this.title,
    required this.description,
    required this.threeMonthSavings,
    required this.upgradeCost,
    required this.applianceName,
  });
}

/// Widget for displaying national consumption comparison
class NationalComparisonCard extends StatelessWidget {
  final Bill bill;

  const NationalComparisonCard({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final userKwh = BillUtils.getTotalKwh(bill);

    // Simulated Lithuanian national distribution (mean = 450 kWh, stdDev = 150)
    const mean = 450.0;
    const stdDev = 150.0;

    // Calculate user's percentile
    final userPercentile = StatsUtils.normalCdf(userKwh, mean, stdDev);

    final dataPoints = List.generate(100, (i) {
      final x = 100.0 + i * 10.0; // from 100 to 1100 kWh
      return FlSpot(x, StatsUtils.normalPdf(x, mean, stdDev));
    });

    // Normalize PDF values to fit the chart visually
    final maxY = dataPoints.map((e) => e.y).reduce(max);
    final normalizedPoints = dataPoints
        .map((e) => FlSpot(e.x, e.y / maxY * 100))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'National Comparison',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Your household vs. Lithuania\'s national electricity consumption distribution',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                Row(
                  children: [
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'Relative Frequency',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 25,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.3),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            lineTouchData: LineTouchData(
                              enabled: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => Theme.of(
                                  context,
                                ).colorScheme.inverseSurface,
                                tooltipBorder: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                                tooltipBorderRadius: BorderRadius.circular(8),
                                tooltipPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    // Skip the user marker line (second line)
                                    if (spot.barIndex == 1) return null;

                                    return LineTooltipItem(
                                      '${spot.x.toStringAsFixed(0)} kWh',
                                      TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onInverseSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 35,
                                  interval: 25,
                                  getTitlesWidget: (value, meta) {
                                    // Only show labels at 0, 50, 100
                                    if (value == 0 ||
                                        value == 50 ||
                                        value == 100) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: Text(
                                          '${value.toInt()}%',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                                fontSize: 10,
                                              ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  interval: 200,
                                  getTitlesWidget: (value, _) => Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '${value.toInt()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            extraLinesData: ExtraLinesData(
                              verticalLines: [
                                VerticalLine(
                                  x: userKwh,
                                  color: Colors.deepOrange.shade700,
                                  strokeWidth: 2.5,
                                  dashArray: [6, 4],
                                  label: VerticalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 4,
                                    ),
                                    style: TextStyle(
                                      color: Colors.deepOrange.shade700,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow
                                          .withValues(alpha: 0.9),
                                    ),
                                    labelResolver: (line) =>
                                        ' ${userPercentile.toStringAsFixed(0)}th percentile',
                                  ),
                                ),
                              ],
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: normalizedPoints,
                                isCurved: true,
                                color: Colors.blueAccent,
                                barWidth: 3,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blueAccent.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                            minX: 100,
                            maxX: 1100,
                            minY: 0,
                            maxY: 120,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Monthly Consumption (kWh)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Low consumption',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'High consumption',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildLegendItem(
                      context,
                      'National average distribution',
                      Colors.blueAccent,
                    ),
                    _buildLegendItem(
                      context,
                      'Your household (${userKwh.toStringAsFixed(0)} kWh)',
                      Colors.deepOrange.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
