import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/utils.dart';
import '../../core/constants.dart';
// import '../../core/models.dart' as models;
// import '../../core/utils.dart' as utils;

class ScheduleLoadPage extends StatefulWidget {
  const ScheduleLoadPage({super.key});

  @override
  State createState() => _ScheduleLoadPageState();
}

class _ScheduleLoadPageState extends State<ScheduleLoadPage> {
  final appliances = ApplianceUtils.getDefaultAppliances();

  ApplianceOption? selectedAppliance;
  ScheduleMode scheduleMode = ScheduleMode.relative;
  double relativeDelay = 60;
  late RangeValues absoluteWindow;
  bool isPinned = false;

  @override
  void initState() {
    super.initState();
    // Initialize window to 07:00-22:00 range
    var minTime = TimeFormatter.minutesToHour(7);
    var maxTime = TimeFormatter.minutesToHour(22);

    // Ensure both times are on the same day (if min > max, both should be tomorrow)
    if (minTime > maxTime) {
      maxTime += 1440; // Add 24 hours to maxTime to make it tomorrow
    }

    absoluteWindow = RangeValues(
      minTime.toDouble(),
      (minTime + 120).toDouble().clamp(minTime.toDouble(), maxTime.toDouble()),
    );

    // Add listeners for validation
    customNameController.addListener(_validateInputs);
    customWattsController.addListener(_validateInputs);
  }

  void _validateInputs() {
    setState(() {
      nameValid = customNameController.text.isNotEmpty;
      wattsValid = customWattsController.text.isNotEmpty &&
          int.tryParse(customWattsController.text) != null;
    });
  }

  final TextEditingController customNameController = TextEditingController();
  final TextEditingController customWattsController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode wattsFocusNode = FocusNode();
  bool showCustomInputs = false;
  bool nameValid = true;
  bool wattsValid = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Load')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              'Select appliance',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: showCustomInputs ? 2 : 3,
            child: ApplianceSelector(
              appliances: appliances,
              selectedAppliance: selectedAppliance,
              onSelect: (appliance) {
                setState(() {
                  selectedAppliance = appliance;
                  showCustomInputs = appliance.name == 'Custom Load';
                });
                if (showCustomInputs) {
                  // Auto-focus name field when Custom Load is selected
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    nameFocusNode.requestFocus();
                  });
                }
              },
            ),
          ),
          if (showCustomInputs)
            CustomApplianceInputs(
              nameController: customNameController,
              wattsController: customWattsController,
              nameFocusNode: nameFocusNode,
              wattsFocusNode: wattsFocusNode,
              nameValid: nameValid,
              wattsValid: wattsValid,
            ),
          const Divider(height: 1),
          ScheduleSettings(
            scheduleMode: scheduleMode,
            relativeDelay: relativeDelay,
            absoluteWindow: absoluteWindow,
            isPinned: isPinned,
            selectedAppliance: selectedAppliance,
            showCustomInputs: showCustomInputs,
            onScheduleModeChanged: (mode) =>
                setState(() => scheduleMode = mode),
            onRelativeDelayChanged: (delay) =>
                setState(() => relativeDelay = delay),
            onAbsoluteWindowChanged: (window) =>
                setState(() => absoluteWindow = window),
            onPinnedChanged: (pinned) => setState(() => isPinned = pinned),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _canSchedule() ? _handleSchedule : null,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Schedule', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canSchedule() {
    if (selectedAppliance == null) return false;
    if (showCustomInputs) {
      return customNameController.text.isNotEmpty &&
          customWattsController.text.isNotEmpty &&
          int.tryParse(customWattsController.text) != null;
    }
    return true;
  }

  void _handleSchedule() {
    final appliance = showCustomInputs
        ? customNameController.text
        : selectedAppliance!.name;
    final watts = showCustomInputs
        ? int.tryParse(customWattsController.text) ?? 0
        : selectedAppliance!.watts;
    final icon = showCustomInputs
        ? Icons.power_outlined
        : selectedAppliance!.icon;

    Duration minTime;
    Duration maxTime;

    if (scheduleMode == ScheduleMode.relative) {
      minTime = Duration.zero;
      maxTime = Duration(minutes: relativeDelay.round());
    } else {
      minTime = Duration(minutes: absoluteWindow.start.round());
      maxTime = Duration(minutes: absoluteWindow.end.round());
    }

    Navigator.pop(
      context,
      ScheduledLoad(
        appliance: appliance,
        icon: icon,
        loadWatts: watts,
        minTimeLeft: minTime,
        maxTimeLeft: maxTime,
        isPinned: isPinned,
      ),
    );
  }

  @override
  void dispose() {
    customNameController.dispose();
    customWattsController.dispose();
    nameFocusNode.dispose();
    wattsFocusNode.dispose();
    super.dispose();
  }
}

// -----------------------------
// Schedule page components
// -----------------------------

class ApplianceSelector extends StatelessWidget {
  final List<ApplianceOption> appliances;
  final ApplianceOption? selectedAppliance;
  final Function(ApplianceOption) onSelect;

  const ApplianceSelector({
    super.key,
    required this.appliances,
    required this.selectedAppliance,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: appliances.length,
      itemBuilder: (context, index) {
        final appliance = appliances[index];
        final isCustom = appliance.name == 'Custom Load';
        final isSelected = selectedAppliance == appliance;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => onSelect(appliance),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    appliance.icon,
                    size: 24,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appliance.name,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        if (!isCustom)
                          Text(
                            '${(appliance.watts / 1000).toStringAsFixed(1)} kW',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isSelected
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withValues(alpha: 0.8)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CustomApplianceInputs extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController wattsController;
  final FocusNode nameFocusNode;
  final FocusNode wattsFocusNode;
  final bool nameValid;
  final bool wattsValid;

  const CustomApplianceInputs({
    super.key,
    required this.nameController,
    required this.wattsController,
    required this.nameFocusNode,
    required this.wattsFocusNode,
    required this.nameValid,
    required this.wattsValid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            focusNode: nameFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => wattsFocusNode.requestFocus(),
            decoration: InputDecoration(
              labelText: 'Appliance name',
              errorText: !nameValid && nameController.text.isNotEmpty
                  ? 'Name is required'
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: !nameValid && nameController.text.isNotEmpty
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: wattsController,
            focusNode: wattsFocusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Power (Watts)',
              errorText: !wattsValid && wattsController.text.isNotEmpty
                  ? 'Enter a valid number'
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: !wattsValid && wattsController.text.isNotEmpty
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleSettings extends StatelessWidget {
  final ScheduleMode scheduleMode;
  final double relativeDelay;
  final RangeValues absoluteWindow;
  final bool isPinned;
  final ApplianceOption? selectedAppliance;
  final bool showCustomInputs;
  final Function(ScheduleMode) onScheduleModeChanged;
  final Function(double) onRelativeDelayChanged;
  final Function(RangeValues) onAbsoluteWindowChanged;
  final Function(bool) onPinnedChanged;

  const ScheduleSettings({
    super.key,
    required this.scheduleMode,
    required this.relativeDelay,
    required this.absoluteWindow,
    required this.isPinned,
    required this.selectedAppliance,
    required this.showCustomInputs,
    required this.onScheduleModeChanged,
    required this.onRelativeDelayChanged,
    required this.onAbsoluteWindowChanged,
    required this.onPinnedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Operating window',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Recurring'),
                  avatar: const Icon(Icons.repeat, size: 18),
                  selected: isPinned,
                  onSelected: onPinnedChanged,
                  showCheckmark: false,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton(
              segments: const [
                ButtonSegment(
                  value: ScheduleMode.relative,
                  label: Text('Relative'),
                  icon: Icon(Icons.schedule),
                ),
                ButtonSegment(
                  value: ScheduleMode.absolute,
                  label: Text('Absolute'),
                  icon: Icon(Icons.access_time),
                ),
              ],
              selected: {scheduleMode},
              onSelectionChanged: (Set newSelection) {
                onScheduleModeChanged(newSelection.first);
              },
            ),
            const SizedBox(height: 20),
            if (scheduleMode == ScheduleMode.relative)
              RelativeModeSettings(
                delay: relativeDelay,
                onDelayChanged: onRelativeDelayChanged,
              )
            else
              AbsoluteModeSettings(
                window: absoluteWindow,
                onWindowChanged: onAbsoluteWindowChanged,
              ),
            if (selectedAppliance != null && !showCustomInputs)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: SavingsEstimate(
                  watts: selectedAppliance!.watts,
                  scheduleMode: scheduleMode,
                  relativeDelay: relativeDelay,
                  absoluteWindow: absoluteWindow,
                ),
              ),
          ],
        ),
      );
  }
}

class RelativeModeSettings extends StatelessWidget {
  final double delay;
  final Function(double) onDelayChanged;

  const RelativeModeSettings({
    super.key,
    required this.delay,
    required this.onDelayChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Run in',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                TimeFormatter.formatRelativeTime(delay.round()),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: delay,
          min: 0,
          max: AppConstants.maxRelativeDelayMinutes,
          divisions: 32,
          label: TimeFormatter.formatRelativeTime(delay.round()),
          onChanged: onDelayChanged,
        ),
      ],
    );
  }
}

class AbsoluteModeSettings extends StatelessWidget {
  final RangeValues window;
  final Function(RangeValues) onWindowChanged;

  const AbsoluteModeSettings({
    super.key,
    required this.window,
    required this.onWindowChanged,
  });

  @override
  Widget build(BuildContext context) {
    var minTime = TimeFormatter.minutesToHour(7); // 07:00
    var maxTime = TimeFormatter.minutesToHour(22); // 22:00

    // Ensure both times are on the same day (if min > max, both should be tomorrow)
    if (minTime > maxTime) {
      maxTime += 1440; // Add 24 hours to maxTime to make it tomorrow
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeFormatter.formatTimeFromMinutes(window.start.round()),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '—',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'End',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeFormatter.formatTimeFromMinutes(window.end.round()),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        RangeSlider(
          values: RangeValues(
            window.start.clamp(minTime.toDouble(), maxTime.toDouble()),
            window.end.clamp(minTime.toDouble(), maxTime.toDouble()),
          ),
          min: minTime.toDouble(),
          max: maxTime.toDouble(),
          divisions: ((maxTime - minTime) / 15).round(),
          labels: RangeLabels(
            TimeFormatter.formatTimeFromMinutes(window.start.round()),
            TimeFormatter.formatTimeFromMinutes(window.end.round()),
          ),
          onChanged: onWindowChanged,
        ),
      ],
    );
  }
}

class SavingsEstimate extends StatelessWidget {
  final int watts;
  final ScheduleMode scheduleMode;
  final double relativeDelay;
  final RangeValues absoluteWindow;

  const SavingsEstimate({
    super.key,
    required this.watts,
    required this.scheduleMode,
    required this.relativeDelay,
    required this.absoluteWindow,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startTime = scheduleMode == ScheduleMode.relative
        ? now
        : now.add(Duration(minutes: absoluteWindow.start.round()));
    final endTime = scheduleMode == ScheduleMode.relative
        ? now.add(Duration(minutes: relativeDelay.round()))
        : now.add(Duration(minutes: absoluteWindow.end.round()));

    final potentialSavings = ApplianceUtils.potentialSavings(
      watts,
      startTime: startTime,
      endTime: endTime,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.savings_outlined,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Potential savings',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Up to ${potentialSavings.toStringAsFixed(2)}€ per run',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
