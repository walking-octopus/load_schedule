import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/bill_service.dart';
import '../../core/bill_models.dart';
import '../settings/page.dart';
import 'dart:math';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State createState() => _InsightsPageState();
}

class _InsightsPageState extends State {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await BillService.loadBills();

      // Use mock bill if no real data exists
      if (BillService.getAllBills().isEmpty) {
        final mockBill = BillService.getMockBill();
        if (mockBill != null) {
          await BillService.saveBill(mockBill);
        }
      }
    } catch (e) {
      debugPrint('Error loading bills: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBillDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add bill'),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBillBreakdown(),
        const SizedBox(height: 32),
        _buildConsumptionGraph(),
        const SizedBox(height: 32),
        _buildNationalComparisonCard(), // 👈 Add this line
      ],
    );
  }

  Widget _buildBillBreakdown() {
    final bill = BillService.getLatestBill();
    if (bill == null) {
      return const Center(child: Text('No bills available'));
    }

    final monthNames = [
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
    final billMonth = '${monthNames[bill.month.month - 1]} ${bill.month.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bill Breakdown',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Based on your last bill ($billMonth)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasEnoughSpace = constraints.maxWidth > 600;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '€${bill.totalAmount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (hasEnoughSpace)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildStackChart(bill)),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: _buildBreakdownList(bill)),
                        ],
                      )
                    else ...[
                      _buildStackChart(bill),
                      const SizedBox(height: 16),
                      _buildBreakdownList(bill),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStackChart(Bill bill) {
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

  Widget _buildBreakdownList(Bill bill) {
    final sortedBreakdown = bill.breakdown.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return Column(
      children: sortedBreakdown.map((consumption) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: consumption.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  consumption.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '€${consumption.amount.toStringAsFixed(2)}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Text(
                '• ${consumption.kwh.toStringAsFixed(0)} kWh',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConsumptionGraph() {
    final data = BillService.getMonthlyConsumption();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consumption',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Historical data and model predictions for the next months',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildLegendItem('Increased', Colors.red),
                    _buildLegendItem('Decreased', Colors.green),
                    _buildLegendItem('Predicted', Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 200,
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
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()} kWh',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                                    final monthNames = [
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
                                    return Text(
                                      monthNames[month.month - 1],
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
                          barGroups: data.asMap().entries.map((entry) {
                            final index = entry.key;
                            final consumption = entry.value;

                            // Determine bar color based on comparison with previous month
                            Color barColor;
                            if (index == 0) {
                              // First month - assume green
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
                              } else if (consumption.kwh >
                                  prevConsumption.kwh) {
                                // Increased consumption
                                barColor = Colors.red;
                              } else if (consumption.kwh <
                                  prevConsumption.kwh) {
                                // Decreased consumption
                                barColor = Colors.green;
                              } else {
                                // Same consumption
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
                          }).toList(),
                          minY: 0,
                          maxY: 800,
                          barTouchData: BarTouchData(enabled: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
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

  void _showAddBillDialog() {
    final formKey = GlobalKey<FormState>();
    final monthController = TextEditingController();
    final yearController = TextEditingController();
    final amountController = TextEditingController();

    final yearFocusNode = FocusNode();
    final amountFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a new bill'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: monthController,
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          hintText: 'MM',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        validator: (value) {
                          final month = int.tryParse(value ?? '');
                          if (month == null || month < 1 || month > 12) {
                            return 'Invalid';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (value.length == 2) {
                            yearFocusNode.requestFocus();
                          }
                        },
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: yearController,
                        focusNode: yearFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          hintText: 'YYYY',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        validator: (value) {
                          final year = int.tryParse(value ?? '');
                          final currentYear = DateTime.now().year;
                          if (year == null ||
                              year < 2000 ||
                              year > currentYear + 1) {
                            return 'Invalid';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (value.length == 4) {
                            amountFocusNode.requestFocus();
                          }
                        },
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                focusNode: amountFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Bill paid (EUR)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Invalid amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              monthController.dispose();
              yearController.dispose();
              amountController.dispose();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final month = int.parse(monthController.text);
                final year = int.parse(yearController.text);
                final amount = double.parse(amountController.text);

                final bill = Bill(
                  id: 'bill_${DateTime(year, month).millisecondsSinceEpoch}',
                  month: DateTime(year, month),
                  totalAmount: amount,
                  breakdown: _createBillBreakdown(amount),
                );

                await BillService.saveBill(bill);
                await _loadData();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill added successfully')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Map<String, ApplianceConsumption> _createBillBreakdown(double totalAmount) {
    return {
      'Heating': ApplianceConsumption(
        name: 'Heating',
        amount: totalAmount * 0.45,
        kwh: totalAmount * 0.45 * 2.5,
        color: const Color(0xFFFF6B6B),
      ),
      'Water Heater': ApplianceConsumption(
        name: 'Water Heater',
        amount: totalAmount * 0.20,
        kwh: totalAmount * 0.20 * 2.5,
        color: const Color(0xFF4ECDC4),
      ),
      'Refrigerator': ApplianceConsumption(
        name: 'Refrigerator',
        amount: totalAmount * 0.12,
        kwh: totalAmount * 0.12 * 2.5,
        color: const Color(0xFF45B7D1),
      ),
      'Washing Machine': ApplianceConsumption(
        name: 'Washing Machine',
        amount: totalAmount * 0.08,
        kwh: totalAmount * 0.08 * 2.5,
        color: const Color(0xFF96CEB4),
      ),
      'Dishwasher': ApplianceConsumption(
        name: 'Dishwasher',
        amount: totalAmount * 0.07,
        kwh: totalAmount * 0.07 * 2.5,
        color: const Color(0xFFFECEA8),
      ),
      'Other': ApplianceConsumption(
        name: 'Other',
        amount: totalAmount * 0.08,
        kwh: totalAmount * 0.08 * 2.5,
        color: const Color(0xFFDFE6E9),
      ),
    };
  }

  Widget _buildNationalComparisonCard() {
    final latestBill = BillService.getLatestBill();
    if (latestBill == null) {
      return const SizedBox.shrink();
    }

    // Assume the user's total monthly kWh consumption
    final userKwh = latestBill.breakdown.values.fold<double>(
      0,
      (sum, item) => sum + item.kwh,
    );

    // Simulated Lithuanian national distribution (mean = 450 kWh, stdDev = 150)
    final mean = 450.0;
    final stdDev = 150.0;

    double normalPdf(double x, double mean, double stdDev) {
      final exponent = -((x - mean) * (x - mean)) / (2 * stdDev * stdDev);
      return (1 / (stdDev * sqrt(2 * pi))) * exp(exponent);
    }

    final dataPoints = List.generate(100, (i) {
      final x = 100.0 + i * 10.0; // from 100 to 1100 kWh
      return FlSpot(x, normalPdf(x, mean, stdDev));
    });

    // Normalize PDF values to fit the chart visually
    final maxY = dataPoints.map((e) => e.y).reduce(max);
    final normalizedPoints = dataPoints
        .map((e) => FlSpot(e.x, e.y / maxY * 100))
        .toList();

    // User point
    final userPointY = normalPdf(userKwh, mean, stdDev) / maxY * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'National Comparison',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Your household vs. Lithuania’s national electricity consumption distribution',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
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
                            interval: 200,
                            getTitlesWidget: (value, _) => Text(
                              '${value.toInt()}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: normalizedPoints,
                          isCurved: true,
                          color: Colors.blueAccent,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blueAccent.withOpacity(0.2),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                        // User marker line
                        LineChartBarData(
                          spots: [
                            FlSpot(userKwh, 0),
                            FlSpot(userKwh, userPointY),
                          ],
                          isCurved: false,
                          color: Colors.orange,
                          barWidth: 2,
                          dashArray: [5, 5],
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Low consumption',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'High consumption',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    const Text('National average distribution'),
                    const SizedBox(width: 16),
                    Container(width: 12, height: 12, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('Your household (${userKwh.toStringAsFixed(0)} kWh)'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
