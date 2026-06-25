/// ACTA Frontend — Simulation Setup Screen
/// ==========================================
/// Dedicated page for configuring and launching disaster
/// simulations. Extends the existing ControlPanel with
/// additional storm-track editor, scenario presets, and
/// simulation history/comparison tools.
///
/// Target Branch : feature/frontend-dashboard
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// -----------------------------------------------------------
// State Providers
// -----------------------------------------------------------

/// Selected scenario preset name (null = custom).
final selectedPresetProvider = StateProvider<String?>((ref) => null);

/// Storm track points for the editor.
final stormTrackProvider = StateProvider<List<List<double>>>((ref) => [
      [120.98, 14.60],
      [120.95, 14.55],
      [120.90, 14.50],
    ]);

/// History of previously-run simulations.
final simulationHistoryProvider =
    StateProvider<List<Map<String, dynamic>>>((ref) => []);

// -----------------------------------------------------------
// Scenario Presets
// -----------------------------------------------------------

const _scenarioPresets = <String, Map<String, dynamic>>{
  'Tropical Depression': {
    'wind_kph': 55.0,
    'rain_mm': 100.0,
    'prep_hours': 48,
  },
  'Tropical Storm': {
    'wind_kph': 90.0,
    'rain_mm': 200.0,
    'prep_hours': 36,
  },
  'Severe Typhoon': {
    'wind_kph': 150.0,
    'rain_mm': 350.0,
    'prep_hours': 24,
  },
  'Super Typhoon': {
    'wind_kph': 220.0,
    'rain_mm': 500.0,
    'prep_hours': 12,
  },
};

// -----------------------------------------------------------
// Simulation Setup Screen
// -----------------------------------------------------------

class SimulationSetupScreen extends ConsumerStatefulWidget {
  const SimulationSetupScreen({super.key});

  @override
  ConsumerState<SimulationSetupScreen> createState() =>
      _SimulationSetupScreenState();
}

class _SimulationSetupScreenState
    extends ConsumerState<SimulationSetupScreen> {
  final _windController = TextEditingController(text: '80.0');
  final _rainController = TextEditingController(text: '200.0');
  double _prepWindow = 36;

  @override
  void dispose() {
    _windController.dispose();
    _rainController.dispose();
    super.dispose();
  }

  /// Apply a scenario preset to the input fields.
  void _applyPreset(String name) {
    final preset = _scenarioPresets[name];
    if (preset == null) return;

    setState(() {
      _windController.text = (preset['wind_kph'] as double).toStringAsFixed(1);
      _rainController.text = (preset['rain_mm'] as double).toStringAsFixed(1);
      _prepWindow = (preset['prep_hours'] as int).toDouble();
    });
    ref.read(selectedPresetProvider.notifier).state = name;
  }

  /// Clear preset and reset to defaults.
  void _clearPreset() {
    ref.read(selectedPresetProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1200;

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: isWide
          ? _buildWideLayout(theme)
          : _buildNarrowLayout(theme),
    );
  }

  // ---------------------------------------------------------
  // App Bar
  // ---------------------------------------------------------

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.science_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Simulation Setup'),
          const SizedBox(width: 8),
          Text(
            '— Configure & Launch',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Wide Layout (Desktop)
  // ---------------------------------------------------------

  Widget _buildWideLayout(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Scenario Presets
        SizedBox(
          width: 300,
          child: _buildPresetsPanel(theme),
        ),

        // Center: Parameter Configuration
        Expanded(
          flex: 2,
          child: _buildParameterPanel(theme),
        ),

        // Right: Storm Track Editor & History
        SizedBox(
          width: 400,
          child: _buildStormTrackPanel(theme),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // Narrow Layout (Mobile / Tablet)
  // ---------------------------------------------------------

  Widget _buildNarrowLayout(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPresetsPanel(theme),
          _buildParameterPanel(theme),
          _buildStormTrackPanel(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Scenario Presets Panel
  // ---------------------------------------------------------

  Widget _buildPresetsPanel(ThemeData theme) {
    final selected = ref.watch(selectedPresetProvider);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.folder_special_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Scenario Presets',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select a pre-configured scenario or create a custom simulation.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 20),

          // Preset cards
          ..._scenarioPresets.entries.map((entry) {
            final isSelected = selected == entry.key;
            final preset = entry.value;
            final wind = preset['wind_kph'] as double;
            final Color intensityColor;
            if (wind >= 200) {
              intensityColor = const Color(0xFFEF5350);
            } else if (wind >= 120) {
              intensityColor = const Color(0xFFFF7043);
            } else if (wind >= 70) {
              intensityColor = const Color(0xFFFFB74D);
            } else {
              intensityColor = const Color(0xFF66BB6A);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _applyPreset(entry.key),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : const Color(0xFF1A1D23),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.5)
                          : const Color(0xFF2A2E36),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: intensityColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${wind.toStringAsFixed(0)} kph · ${(preset['rain_mm'] as double).toStringAsFixed(0)} mm · T-${preset['prep_hours']}h',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle,
                            size: 18, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 12),

          // Custom mode
          OutlinedButton.icon(
            onPressed: _clearPreset,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF3A3F4B)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Custom Configuration'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Parameter Configuration Panel
  // ---------------------------------------------------------

  Widget _buildParameterPanel(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.tune, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Meteorological Parameters',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Fine-tune weather inputs for the simulation engine.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 24),

          // Wind Speed
          _buildFieldLabel('Wind Speed', 'kph', Icons.air),
          const SizedBox(height: 8),
          TextField(
            controller: _windController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: const InputDecoration(
              hintText: 'e.g., 120.5',
              suffixText: 'kph',
            ),
            onChanged: (_) => _clearPreset(),
          ),

          const SizedBox(height: 20),

          // Precipitation
          _buildFieldLabel(
              '24h Precipitation', 'mm', Icons.water_drop_outlined),
          const SizedBox(height: 8),
          TextField(
            controller: _rainController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: const InputDecoration(
              hintText: 'e.g., 350.0',
              suffixText: 'mm',
            ),
            onChanged: (_) => _clearPreset(),
          ),

          const SizedBox(height: 28),

          // Preparation Window Slider
          _buildFieldLabel(
            'Preparation Window',
            '${_prepWindow.round()}h',
            Icons.timer_outlined,
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _prepWindow,
              min: 1,
              max: 96,
              divisions: 95,
              label: '${_prepWindow.round()} hours',
              onChanged: (value) {
                setState(() => _prepWindow = value);
                _clearPreset();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1h',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text('24h',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text('48h',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text('96h',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Launch Simulation
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Execute simulation via backend API
              },
              icon: const Icon(Icons.rocket_launch_outlined, size: 22),
              label: const Text('Launch Simulation'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Storm Track & History Panel
  // ---------------------------------------------------------

  Widget _buildStormTrackPanel(ThemeData theme) {
    final trackPoints = ref.watch(stormTrackProvider);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E36), width: 1),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Storm Track Header
          Row(
            children: [
              Icon(Icons.route_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Storm Track',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${trackPoints.length} waypoints',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Define projected storm trajectory waypoints.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 16),

          // Waypoint list
          ...trackPoints.asMap().entries.map((entry) {
            final idx = entry.key;
            final pt = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D23),
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  left: BorderSide(color: Color(0xFF00BFA6), width: 3),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'WP ${idx + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${pt[0].toStringAsFixed(4)}°E, ${pt[1].toStringAsFixed(4)}°N',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 16, color: Colors.grey[600]),
                    onPressed: () {
                      // TODO: Remove waypoint
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: () {
              // TODO: Add waypoint via map tap or manual input
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Add Waypoint'),
          ),

          const SizedBox(height: 32),

          // Simulation History
          Row(
            children: [
              Icon(Icons.history, size: 15, color: Colors.grey[500]),
              const SizedBox(width: 8),
              const Text(
                'Recent Simulations',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Center(
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 32, color: Colors.grey[700]),
                const SizedBox(height: 8),
                Text(
                  'No simulation history yet',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Reusable Field Label
  // ---------------------------------------------------------

  Widget _buildFieldLabel(String title, String suffix, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          suffix,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
