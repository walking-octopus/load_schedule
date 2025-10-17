import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../schedule/page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<ScheduledLoad> pendingLoads = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('Energy Scheduler')),
      body: Column(
        children: [
          const PriceChartCard(),
          Expanded(
            child: pendingLoads.isEmpty
                ? const EmptyStateWidget()
                : LoadsList(
                    loads: pendingLoads,
                    onRemove: _handleRemoveLoad,
                    onUndo: _handleUndoRemove,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToSchedulePage,
        icon: const Icon(Icons.add),
        label: const Text('Schedule'),
      ),
    );
  }

  Future _navigateToSchedulePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScheduleLoadPage()),
    );
    if (result != null && result is ScheduledLoad) {
      setState(() => pendingLoads.add(result));
    }
  }

  void _handleRemoveLoad(int index) {
    setState(() => pendingLoads.removeAt(index));
  }

  void _handleUndoRemove(int index, ScheduledLoad load) {
    setState(() => pendingLoads.insert(index, load));
  }
}
