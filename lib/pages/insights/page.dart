import 'package:flutter/material.dart';
import '../../services/bill_service.dart';
import '../../core/bill_models.dart';
import '../../core/utils.dart';
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
    final bill = BillService.getLatestBill();
    if (bill == null) {
      return const Center(child: Text('No bills available'));
    }

    final consumptionData = BillService.getMonthlyConsumption();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        BillBreakdownCard(bill: bill),
        ConsumptionChart(data: consumptionData),
        NationalComparisonCard(bill: bill),
      ],
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

                final bill = Bill(
                  id: 'bill_${DateTime(year, month).millisecondsSinceEpoch}',
                  month: DateTime(year, month),
                  totalAmount: amount,
                  breakdown: BillUtils.createDefaultBillBreakdown(amount),
                );

                // Capture navigator and messenger before async gap
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

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
