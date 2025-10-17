import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/models.dart';
import '../../core/utils.dart';
import '../../services/price_data.dart';

class PriceChartCard extends StatelessWidget {
  const PriceChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Energy Price Forecast',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Next 24 hours',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 280, child: PriceChart()),
          ],
        ),
      ),
    );
  }
}

class PriceChart extends StatelessWidget {
  const PriceChart({super.key});

  @override
  Widget build(BuildContext context) {
    final priceData = PriceDataService.generatePriceData();
    final prices = priceData.map((spot) => spot.y).toList().cast<double>();

    return LineChart(
      LineChartData(
        gridData: _buildGridData(context),
        titlesData: _buildTitlesData(context),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 24,
        lineTouchData: _buildTouchData(context),
        lineBarsData: [_buildLineBarData(context, priceData, prices)],
      ),
    );
  }

  FlGridData _buildGridData(BuildContext context) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 10,
      getDrawingHorizontalLine: (value) => FlLine(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        strokeWidth: 1,
      ),
    );
  }

  FlTitlesData _buildTitlesData(BuildContext context) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 10,
          getTitlesWidget: (value, meta) =>
              _buildLeftTitle(context, value, meta),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 4,
          getTitlesWidget: (value, meta) => _buildBottomTitle(context, value),
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _buildLeftTitle(BuildContext context, double value, TitleMeta meta) {
    if (value == meta.max || value == meta.min) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        '${value.toInt()}¢',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildBottomTitle(BuildContext context, double value) {
    if (value == 24) return const SizedBox.shrink();
    final now = DateTime.now();
    final targetTime = now.add(Duration(hours: value.toInt()));
    final hour = targetTime.hour;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${hour.toString().padLeft(2, '0')}:00',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: value == 0
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: value == 0 ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  LineTouchData _buildTouchData(BuildContext context) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
          final now = DateTime.now();
          final targetTime = now.add(Duration(hours: spot.x.toInt()));
          final hour = targetTime.hour.toString().padLeft(2, '0');
          final minute = targetTime.minute.toString().padLeft(2, '0');
          return LineTooltipItem(
            '${spot.y.toStringAsFixed(1)}¢/kWh\n$hour:$minute',
            TextStyle(
              color: Theme.of(context).colorScheme.onInverseSurface,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          );
        }).toList(),
      ),
      getTouchedSpotIndicator: (barData, spotIndexes) {
        return spotIndexes.map((index) {
          return TouchedSpotIndicatorData(
            FlLine(
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 2,
            ),
            FlDotData(
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).colorScheme.surface,
                );
              },
            ),
          );
        }).toList();
      },
    );
  }

  LineChartBarData _buildLineBarData(
    BuildContext context,
    List<FlSpot> priceData,
    List<double> prices,
  ) {
    return LineChartBarData(
      spots: priceData,
      isCurved: true,
      curveSmoothness: 0.35,
      preventCurveOverShooting: true,
      color: Theme.of(context).colorScheme.primary,
      barWidth: 4,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
          ],
        ),
      ),
      gradient: LinearGradient(
        colors: priceData.map((spot) {
          return PriceDataService.getColorForPrice(spot.y, prices);
        }).toList(),
      ),
    );
  }
}

class LoadsList extends StatelessWidget {
  final List loads;
  final Function(int) onRemove;
  final Function(int, ScheduledLoad) onUndo;

  const LoadsList({
    super.key,
    required this.loads,
    required this.onRemove,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: loads.length,
      itemBuilder: (context, index) => LoadListItem(
        load: loads[index],
        index: index,
        onRemove: () => onRemove(index),
        onUndo: () => onUndo(index, loads[index]),
      ),
    );
  }
}

class LoadListItem extends StatelessWidget {
  final ScheduledLoad load;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onUndo;

  const LoadListItem({
    super.key,
    required this.load,
    required this.index,
    required this.onRemove,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('${load.appliance}_$index'),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(context),
      onDismissed: (direction) {
        onRemove();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${load.appliance} removed'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: 'Undo', onPressed: onUndo),
          ),
        );
      },
      child: _buildCard(context),
    );
  }

  Widget _buildDismissBackground(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.onErrorContainer,
        size: 24,
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildIcon(context),
            const SizedBox(width: 16),
            Expanded(child: _buildInfo(context)),
            const SizedBox(width: 8),
            Text(
              TimeFormatter.formatScheduleTime(load),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        ApplianceUtils.getIcon(load.appliance),
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        size: 20,
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          load.appliance,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${(load.loadWatts / 1000).toStringAsFixed(1)} kW',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (load.isPinned) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Icon(
                Icons.repeat,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Daily',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No scheduled loads',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Schedule appliances to run during off-peak hours and save on energy costs.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
