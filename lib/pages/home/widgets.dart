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
            Row(
              children: [
                Text(
                  'Energy Price Forecast',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Icon(
                  Icons.bolt,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Next 24 hours',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 200, child: PriceChart()),
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
    final currentHour = DateTime.now().hour.toDouble();

    return LineChart(
      LineChartData(
        gridData: _buildGridData(context),
        titlesData: _buildTitlesData(context),
        borderData: FlBorderData(show: false),
        minX: 7,
        maxX: 22,
        lineTouchData: _buildTouchData(context, priceData, prices),
        lineBarsData: [_buildLineBarData(context, priceData, prices)],
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (currentHour >= 7 && currentHour <= 22)
              VerticalLine(
                x: currentHour,
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 2,
                dashArray: [4, 4],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  labelResolver: (line) => 'Now',
                ),
              ),
          ],
        ),
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
          interval: 3,
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
    if (value == 22) return const SizedBox.shrink();
    final hour = value.toInt();
    final currentHour = DateTime.now().hour;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${hour.toString().padLeft(2, '0')}:00',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: hour == currentHour
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: hour == currentHour ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  LineTouchData _buildTouchData(
    BuildContext context,
    List<FlSpot> priceData,
    List<double> prices,
  ) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) =>
            Theme.of(context).colorScheme.inverseSurface,
        tooltipBorder: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        tooltipBorderRadius: BorderRadius.circular(8),
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
          final hour = spot.x.floor();
          final minuteFraction = spot.x - hour;
          final minute = (minuteFraction * 60).round();
          final timeStr =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          return LineTooltipItem(
            '${spot.y.toStringAsFixed(1)} ¢/kWh\n$timeStr',
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
          final spot = barData.spots[index];
          final priceColor = PriceDataService.getColorForPrice(spot.y, prices);

          return TouchedSpotIndicatorData(
            FlLine(color: priceColor, strokeWidth: 2, dashArray: [4, 4]),
            FlDotData(
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: priceColor,
                  strokeWidth: 2,
                  strokeColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
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
      // isCurved: true,
      // curveSmoothness: 0.35,
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
  final Function(String) onRemove;
  final Function(ScheduledLoad) onUndo;
  final Function(String) onTogglePin;

  const LoadsList({
    super.key,
    required this.loads,
    required this.onRemove,
    required this.onUndo,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: loads.length,
      itemBuilder: (context, index) {
        final load = loads[index];
        return LoadListItem(
          load: load,
          index: index,
          onRemove: () => onRemove(load.id),
          onUndo: () => onUndo(load),
          onTogglePin: () => onTogglePin(load.id),
        );
      },
    );
  }
}

class LoadListItem extends StatefulWidget {
  final ScheduledLoad load;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onUndo;
  final VoidCallback onTogglePin;

  const LoadListItem({
    super.key,
    required this.load,
    required this.index,
    required this.onRemove,
    required this.onUndo,
    required this.onTogglePin,
  });

  @override
  State<LoadListItem> createState() => _LoadListItemState();
}

class _LoadListItemState extends State<LoadListItem> {
  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.load.id),
      direction: DismissDirection.horizontal,
      background: _buildPinBackground(context),
      secondaryBackground: _buildDeleteBackground(context),
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.4,
        DismissDirection.endToStart: 0.4,
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Pin action
          widget.onTogglePin();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.load.isPinned
                      ? '${widget.load.appliance} unpinned'
                      : '${widget.load.appliance} pinned as recurring',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(milliseconds: 1500),
              ),
            );
          }
          return false; // Don't dismiss for pin
        }
        // For delete - allow it but don't show snackbar here
        return true;
      },
      onDismissed: (direction) {
        // Only called for delete (endToStart)
        widget.onRemove();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.load.appliance} removed'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(label: 'Undo', onPressed: widget.onUndo),
            ),
          );
        }
      },
      child: _buildCard(context),
    );
  }

  Widget _buildPinBackground(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        widget.load.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
        color: Theme.of(context).colorScheme.onTertiaryContainer,
        size: 24,
      ),
    );
  }

  Widget _buildDeleteBackground(BuildContext context) {
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
            const SizedBox(width: 16),
            Text(
              TimeFormatter.formatArrivalTimes(widget.load),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.2,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Icon(
        widget.load.icon,
        color: Theme.of(context).colorScheme.onSurface,
        size: 24,
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.load.appliance,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${(widget.load.loadWatts / 1000).toStringAsFixed(1)} kW',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.load.isPinned) ...[
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
                'Recurring',
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
