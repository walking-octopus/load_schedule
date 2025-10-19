import 'package:flutter/material.dart';
import '../../services/bill_service.dart';
import '../../core/bill_models.dart';
import '../settings/page.dart';
import 'widgets.dart';

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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
              // Reload data after returning from settings
              if (mounted) {
                await _loadData();
              }
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
    final bill = BillService.getLatestBill();
    if (bill == null) {
      return _buildPredictedOrEmptyState();
    }

    final consumptionData = BillService.getMonthlyConsumption();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        BillBreakdownCard(bill: bill),
        ConsumptionChart(data: consumptionData),
        EfficiencyRecommendationsCard(bill: bill),
        NationalComparisonCard(bill: bill),
      ],
    );
  }

  Widget _buildPredictedOrEmptyState() {
    return FutureBuilder<Bill?>(
      future: BillService.getLatestBillOrPrediction(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final predictedBill = snapshot.data;
        if (predictedBill == null) {
          return _buildEmptyState();
        }

        // Show predicted bill with a banner indicating it's a prediction
        final consumptionData = BillService.getMonthlyConsumption();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            _buildPredictionBanner(),
            BillBreakdownCard(bill: predictedBill),
            if (consumptionData.isNotEmpty) ConsumptionChart(data: consumptionData),
            EfficiencyRecommendationsCard(bill: predictedBill),
            NationalComparisonCard(bill: predictedBill),
          ],
        );
      },
    );
  }

  Widget _buildPredictionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Predicted Bill',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on your household settings. Add actual bills for more accurate insights.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined,
              size: 120,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No Energy Data Yet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first bill to start tracking your energy consumption and get personalized insights.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _showAddBillDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Bill'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
                // Reload data after returning from settings
                if (mounted) {
                  await _loadData();
                }
              },
              icon: const Icon(Icons.settings),
              label: const Text('Configure Household'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Once configured, we can predict your bills automatically',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showAddBillDialog() {
    final formKey = GlobalKey<FormState>();
    final monthController = TextEditingController();
    final yearController = TextEditingController();
    final amountController = TextEditingController();

    final monthFocusNode = FocusNode();
    final yearFocusNode = FocusNode();
    final amountFocusNode = FocusNode();

    // Autofocus the month field after dialog is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      monthFocusNode.requestFocus();
    });

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
                        focusNode: monthFocusNode,
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
                final billMonth = DateTime(year, month);

                // Capture navigator and messenger before async gap
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                // Create breakdown using probabilistic model
                final breakdown = await BillService.createBillBreakdown(
                  amount,
                  billMonth,
                );

                final bill = Bill(
                  id: 'bill_${billMonth.millisecondsSinceEpoch}',
                  month: billMonth,
                  totalAmount: amount,
                  breakdown: breakdown,
                );

                await BillService.saveBill(bill);
                await _loadData();

                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
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

}
