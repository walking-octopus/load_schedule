import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/geocoding_service.dart';
import '../../services/storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  bool _fetchingLocation = false;
  Timer? _debounce;
  List<AddressSuggestion> _addressSuggestions = [];

  // Your Home
  String _address = '';
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _area = 100.0;
  int _occupants = 2;
  String _buildingType = 'Apartment';
  int _constructionYear = 2000;

  // Appliance efficiency ratings (A-F scale)
  final Map<String, String> _applianceEfficiency = {
    'Microwave': 'C',
    'Oven': 'C',
    'Refrigerator': 'C',
    'Dishwasher': 'C',
    'Washing Machine': 'C',
    'Dryer': 'C',
    'Water Heater': 'C',
    'Air Conditioner': 'C',
    'Heating System': 'C',
  };

  String _heatingType = 'Electric';

  // Electric vehicles
  bool _hasEV = false;
  double _dailyKm = 50.0;
  double _batteryCapacity = 60.0;

  @override
  void initState() {
    super.initState();
    _addressController.text = _address;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    if (settings != null && mounted) {
      setState(() {
        _latitude = settings.latitude;
        _longitude = settings.longitude;
        _area = settings.area;
        _occupants = settings.occupants;
        _buildingType = settings.buildingType;
        _constructionYear = settings.constructionYear;
        _heatingType = settings.heatingType;
        _hasEV = settings.evBatteryCapacity > 0;
        _dailyKm = settings.evDailyKm;
        _batteryCapacity = settings.evBatteryCapacity;
      });

      // Reverse geocode coordinates to get address for display
      if (settings.latitude != 0.0 && settings.longitude != 0.0) {
        final address = await GeocodingService.reverseGeocode(
          settings.latitude,
          settings.longitude,
        );
        if (address != null && mounted) {
          // Update address state first
          _address = address;
          // Defer controller update to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _addressController.text = address;
              });
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() => _addressSuggestions = []);
      return;
    }

    final suggestions = await GeocodingService.searchAddress(query);
    if (mounted) {
      setState(() => _addressSuggestions = suggestions);
    }
  }

  void _onAddressChanged(String value) {
    // Cancel previous timer
    _debounce?.cancel();

    // Set new timer for debouncing (wait 500ms after user stops typing)
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchAddress(value);
    });
  }

  void _showResetConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'This will permanently delete all your settings and bills. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              // Capture navigator and messenger before async gap
              final navigator = Navigator.of(dialogContext);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Clear all storage
              await StorageService.clearAllData();

              // Close dialog and show confirmation
              navigator.pop();
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('All data has been reset')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchGPSLocation() async {
    setState(() => _fetchingLocation = true);

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          setState(() => _fetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently denied'),
            ),
          );
        }
        setState(() => _fetchingLocation = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();

      // Reverse geocode
      final address = await GeocodingService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (address != null && mounted) {
        setState(() {
          _address = address;
          _latitude = position.latitude;
          _longitude = position.longitude;
          _addressController.text = address;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine address')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to get location')));
      }
    } finally {
      if (mounted) {
        setState(() => _fetchingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Household Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Reset all data',
            onPressed: () => _showResetConfirmDialog(context),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Your Home'),
            const SizedBox(height: 16),
            _buildAddressField(),
            const SizedBox(height: 16),
            _buildAreaField(),
            const SizedBox(height: 16),
            _buildOccupantsField(),
            const SizedBox(height: 16),
            _buildBuildingTypeSelector(),
            const SizedBox(height: 16),
            _buildConstructionYearField(),
            const SizedBox(height: 32),

            _buildSectionHeader('Appliance Efficiency'),
            const SizedBox(height: 16),
            _buildHeatingTypeSelector(),
            const SizedBox(height: 16),
            _buildApplianceEfficiencyList(),
            const SizedBox(height: 32),

            _buildSectionHeader('Electric Vehicles'),
            const SizedBox(height: 16),
            _buildEVSelector(),
            if (_hasEV) ...[
              const SizedBox(height: 16),
              _buildDailyKmField(),
              const SizedBox(height: 16),
              _buildBatteryCapacityField(),
            ],
            const SizedBox(height: 32),

            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildAddressField() {
    return Autocomplete<AddressSuggestion>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<AddressSuggestion>.empty();
        }
        return _addressSuggestions;
      },
      displayStringForOption: (AddressSuggestion option) => option.displayName,
      onSelected: (AddressSuggestion selection) {
        setState(() {
          _address = selection.displayName;
          _latitude = selection.latitude;
          _longitude = selection.longitude;
          _addressController.text = selection.displayName;
        });
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Sync our controller with the autocomplete controller
            if (controller.text != _addressController.text) {
              controller.text = _addressController.text;
            }

            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Address',
                border: const OutlineInputBorder(),
                suffixIcon: _fetchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _fetchGPSLocation,
                        tooltip: 'Use GPS location',
                      ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Address is required';
                }
                return null;
              },
              onChanged: (value) {
                _address = value;
                _addressController.text = value;
                // Defer state updates to avoid setState during build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _onAddressChanged(value);
                  }
                });
              },
            );
          },
    );
  }

  Widget _buildAreaField() {
    return TextFormField(
      initialValue: _area.toString(),
      decoration: const InputDecoration(
        labelText: 'Area (m²)',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Area is required';
        }
        final parsed = double.tryParse(value);
        if (parsed == null || parsed <= 0) {
          return 'Please enter a valid area';
        }
        return null;
      },
      onChanged: (value) {
        final parsed = double.tryParse(value);
        if (parsed != null) setState(() => _area = parsed);
      },
    );
  }

  Widget _buildOccupantsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Occupants',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _occupants > 1
                  ? () => setState(() => _occupants--)
                  : null,
            ),
            Expanded(
              child: Text(
                '$_occupants',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _occupants++),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBuildingTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Building type',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Apartment', label: Text('Apartment')),
            ButtonSegment(value: 'Detached', label: Text('Detached')),
          ],
          selected: {_buildingType},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() => _buildingType = newSelection.first);
          },
        ),
      ],
    );
  }

  Widget _buildConstructionYearField() {
    return TextFormField(
      initialValue: _constructionYear.toString(),
      decoration: const InputDecoration(
        labelText: 'Construction Year',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Construction year is required';
        }
        final parsed = int.tryParse(value);
        if (parsed == null || parsed < 1800 || parsed > DateTime.now().year) {
          return 'Please enter a valid year';
        }
        return null;
      },
      onChanged: (value) {
        final parsed = int.tryParse(value);
        if (parsed != null) setState(() => _constructionYear = parsed);
      },
    );
  }

  Widget _buildHeatingTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Heating Type',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['Electric', 'Gas', 'Oil', 'Heat Pump', 'Other']
              .map(
                (type) => ChoiceChip(
                  label: Text(type),
                  selected: _heatingType == type,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _heatingType = type);
                    }
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildApplianceEfficiencyList() {
    return Column(
      children: _applianceEfficiency.keys.map((appliance) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildApplianceEfficiencyItem(appliance),
        );
      }).toList(),
    );
  }

  Widget _buildApplianceEfficiencyItem(String appliance) {
    final efficiency = _applianceEfficiency[appliance]!;
    const efficiencyLevels = ['None', 'F', 'E', 'D', 'C', 'B', 'A'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appliance,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            segments: efficiencyLevels
                .map((level) => ButtonSegment(value: level, label: Text(level)))
                .toList(),
            selected: {efficiency},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _applianceEfficiency[appliance] = newSelection.first;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEVSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Do you have an electric vehicle?',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Yes')),
            ButtonSegment(value: false, label: Text('No')),
          ],
          selected: {_hasEV},
          onSelectionChanged: (Set<bool> newSelection) {
            setState(() => _hasEV = newSelection.first);
          },
        ),
      ],
    );
  }

  Widget _buildDailyKmField() {
    return TextFormField(
      initialValue: _dailyKm.toString(),
      decoration: const InputDecoration(
        labelText: 'Daily km',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (_hasEV) {
          if (value == null || value.isEmpty) {
            return 'Daily km is required for EV';
          }
          final parsed = double.tryParse(value);
          if (parsed == null || parsed < 0) {
            return 'Please enter a valid distance';
          }
        }
        return null;
      },
      onChanged: (value) {
        final parsed = double.tryParse(value);
        if (parsed != null) setState(() => _dailyKm = parsed);
      },
    );
  }

  Widget _buildBatteryCapacityField() {
    return TextFormField(
      initialValue: _batteryCapacity.toString(),
      decoration: const InputDecoration(
        labelText: 'Battery Capacity (kWh)',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (_hasEV) {
          if (value == null || value.isEmpty) {
            return 'Battery capacity is required for EV';
          }
          final parsed = double.tryParse(value);
          if (parsed == null || parsed <= 0) {
            return 'Please enter a valid capacity';
          }
        }
        return null;
      },
      onChanged: (value) {
        final parsed = double.tryParse(value);
        if (parsed != null) setState(() => _batteryCapacity = parsed);
      },
    );
  }

  Widget _buildSaveButton() {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontSize: 16),
      ),
      onPressed: () async {
        if (_formKey.currentState!.validate()) {
          // Additional check for address
          if (_address.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Address is required')),
            );
            return;
          }

          try {
            // If user typed an address but didn't select from suggestions,
            // geocode it to get coordinates
            if (_address.isNotEmpty && _latitude == 0.0 && _longitude == 0.0) {
              final suggestions = await GeocodingService.searchAddress(
                _address,
              );
              if (suggestions.isNotEmpty) {
                _latitude = suggestions.first.latitude;
                _longitude = suggestions.first.longitude;
              } else {
                // Address couldn't be geocoded
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not find coordinates for this address. Please select from suggestions.'),
                    ),
                  );
                }
                return;
              }
            }

            // Verify address was successfully geocoded
            if (_latitude == 0.0 && _longitude == 0.0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select an address from the suggestions'),
                  ),
                );
              }
              return;
            }

            // Create household settings
            final settings = HouseholdSettings(
              address: _address,
              latitude: _latitude,
              longitude: _longitude,
              area: _area,
              occupants: _occupants,
              buildingType: _buildingType,
              constructionYear: _constructionYear,
              heatingType: _heatingType,
              insulationRating: 7.0, // Default value
              applianceUsage: {
                'Refrigerator': 24.0,
                'Washing Machine': 1.5,
                'Dishwasher': 1.0,
                'Microwave': 0.5,
                'Oven': 1.0,
                'Water Heater': 2.0,
              },
              evDailyKm: _hasEV ? _dailyKm : 0.0,
              evBatteryCapacity: _hasEV ? _batteryCapacity : 0.0,
            );

            // Save settings
            await StorageService.saveSettings(settings);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved successfully')),
              );
              Navigator.pop(context);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error saving settings: $e')),
              );
            }
          }
        }
      },
      child: const Text('Save Settings'),
    );
  }
}
