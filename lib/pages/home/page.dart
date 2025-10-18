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
      // appBar: AppBar(title: const Text('PowerTime')),
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
                    onTogglePin: _handleTogglePin,
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

  void _handleRemoveLoad(String id) {
    setState(() {
      pendingLoads.removeWhere((load) => load.id == id);
    });
  }

  void _handleUndoRemove(ScheduledLoad load) {
    setState(() {
      pendingLoads.add(load);
    });
  }

  void _handleTogglePin(String id) {
    setState(() {
      final index = pendingLoads.indexWhere((load) => load.id == id);
      if (index != -1) {
        final load = pendingLoads[index];
        pendingLoads[index] = ScheduledLoad(
          id: load.id, // Preserve the unique ID
          appliance: load.appliance,
          icon: load.icon,
          loadWatts: load.loadWatts,
          minTimeLeft: load.minTimeLeft,
          maxTimeLeft: load.maxTimeLeft,
          isPinned: !load.isPinned,
        );
      }
    });
  }
}
