/// ACTA Frontend — Simulation Setup Screen
/// ==========================================
/// Configure scenario profiles and parameters, then launch a
/// simulation against the FastAPI backend.
/// Renders as content inside AppShell (no Scaffold).
///
/// Wind Condition (TCWS) and 24-Hour Rainfall are independent
/// selector controls, reflecting how PAGASA issues wind and
/// rainfall forecasts separately.
///
/// Target Branch : feat/dashboard
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/wind_presets.dart';
import '../config/rainfall_presets.dart';
import '../models/simulation_state.dart';
import 'app_shell.dart';

// -----------------------------------------------------------
// Local providers
// -----------------------------------------------------------

final _prepWindowProvider = StateProvider<String>((ref) => '24 Hours');

// -----------------------------------------------------------
// Simulation Setup Content
// -----------------------------------------------------------

class SimulationSetupContent extends ConsumerStatefulWidget {
  final GlobalKey? classificationKey;
  final GlobalKey? runSimulationButtonKey;

  const SimulationSetupContent({
    super.key,
    this.classificationKey,
    this.runSimulationButtonKey,
  });

  @override
  ConsumerState<SimulationSetupContent> createState() =>
      _SimulationSetupContentState();
}

class _SimulationSetupContentState
    extends ConsumerState<SimulationSetupContent> {
  Future<void> _runSimulation() async {
    final profile = ref.read(simProfileProvider);
    final wind = ref.read(windPresetProvider);
    final rainfall = ref.read(rainfallPresetProvider);
    final prepWindowStr = ref.read(_prepWindowProvider);
    int prepWindow = 24;
    if (prepWindowStr == '1 Week')
      prepWindow = 168;
    else if (prepWindowStr == '2 Weeks')
      prepWindow = 336;
    else if (prepWindowStr == '1 Month')
      prepWindow = 720;
    else if (prepWindowStr == '3 Months')
      prepWindow = 2160;
    else if (prepWindowStr == '6 Months')
      prepWindow = 4320;
    else
      prepWindow = int.tryParse(prepWindowStr.split(' ').first) ?? 24;

    // Save snapshot for display in run screen
    ref.read(simulationInputSnapshotProvider.notifier).state = {
      'profile': profile.label,
      'wind_signal': wind.label,
      'wind_kph': wind.windSpeedKph,
      'rainfall_label': rainfall.label,
      'rainfall_mm': rainfall.rainfallMm,
      'prep_hours': prepWindow,
    };

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://acta-production.up.railway.app',
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      final response = await dio.post(
        '/api/v1/simulation/run',
        data: {
          'wind_speed_kph': wind.windSpeedKph,
          'precipitation_24h_mm': rainfall.rainfallMm,
          'preparation_window_hours': prepWindow,
          'storm_track_points': [
            [120.98, 14.60],
            [120.95, 14.55],
            [120.90, 14.50],
          ],
        },
      );

      // Backend returns 202 with { run_id, status, message }
      if ((response.statusCode == 200 || response.statusCode == 202) &&
          response.data != null) {
        final runId = response.data['run_id'] as String;
        if (!mounted) return;

        // Safely set all states now that we have runId
        ref.read(simulationRunIdProvider.notifier).state = runId;
        ref.read(simulationProgressProvider.notifier).state = 0;
        ref.read(simulationResultProvider.notifier).state = null;
        ref.read(simulationRunStateProvider.notifier).state =
            SimulationRunState.running;

        // Switch tabs
        ref.read(runSimulationActiveProvider.notifier).state = true;
        ref.read(shellIndexProvider.notifier).state = 1;
      } else {
        throw Exception('Unexpected response: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ref.read(simulationErrorProvider.notifier).state =
          e.response?.data?['detail']?.toString() ??
          'Connection error: ${e.message}';
      ref.read(simulationRunStateProvider.notifier).state =
          SimulationRunState.error;
    } catch (e) {
      if (!mounted) return;
      ref.read(simulationErrorProvider.notifier).state = e.toString();
      ref.read(simulationRunStateProvider.notifier).state =
          SimulationRunState.error;
    }
  }

  void _resetParameters() {
    ref.read(simProfileProvider.notifier).state = SimProfile.hydrologicFlood;
    ref.read(windPresetProvider.notifier).state = defaultWindPreset;
    ref.read(rainfallPresetProvider.notifier).state = defaultRainfallPreset;
    ref.read(_prepWindowProvider.notifier).state = '24 Hours';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(
      children: [
        PageHeader(
          title: 'Simulation Setup',
          subtitle:
              'Configure scenario parameters and run predictive models and assess resource readiness.',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Profile Selection
                const Text(
                  '1. Select Simulation Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: widget.classificationKey,
                  child: const _ProfileSelector(),
                ),
                const SizedBox(height: 28),

                // 2. Wind Condition (TCWS)
                const Text(
                  '2. Wind Condition (TCWS)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select the Tropical Cyclone Wind Signal. This only affects wind speed.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 14),
                const _WindSignalSelector(),
                const SizedBox(height: 28),

                // 3. Rainfall Intensity
                const Text(
                  '3. 24-Hour Rainfall',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select rainfall intensity based on the Heavy Rainfall Outlook. Independent of wind signal.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 14),
                const _RainfallSelector(),
                const SizedBox(height: 28),

                // 4. Additional Parameters
                const Text(
                  '4. Additional Parameters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 14),
                const _AdditionalParametersForm(),
                const SizedBox(height: 32),

                // Footer buttons
                if (isMobile) ...[
                  SizedBox(
                    width: double.infinity,
                    child: KeyedSubtree(
                      key: widget.runSimulationButtonKey,
                      child: ElevatedButton.icon(
                        onPressed: _runSimulation,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Run Simulation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _resetParameters,
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Reset Parameters'),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _resetParameters,
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const Text('Reset Parameters'),
                      ),
                      const Spacer(),
                      KeyedSubtree(
                        key: widget.runSimulationButtonKey,
                        child: ElevatedButton.icon(
                          onPressed: _runSimulation,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Run Simulation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------
// Profile Selector (unchanged)
// -----------------------------------------------------------

class _ProfileSelector extends ConsumerWidget {
  const _ProfileSelector();

  static const _profiles = [
    _Profile(
      SimProfile.hydrologicFlood,
      'Hydrologic Flood',
      Icons.flood_outlined,
      Color(0xFF0EA5E9),
      'Rainfall-induced flooding, river overflow, and drainage inundation.',
      true,
    ),
    _Profile(
      SimProfile.earthquake,
      'Earthquake',
      Icons.foundation_outlined,
      Color(0xFF374151),
      'Earthquake-induced structural damage, infrastructure disruption, and emergency response simulation.',
      false,
    ),
    _Profile(
      SimProfile.virusOutbreak,
      'Virus Outbreak',
      Icons.coronavirus_outlined,
      Color(0xFF374151),
      'Disease outbreak spread simulation and response planning.',
      false,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(simProfileProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Column(
        children: _profiles.map((p) {
          final isSelected = selected == p.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProfileCard(
              profile: p,
              isSelected: isSelected,
              onTap: p.isEnabled
                  ? () => ref.read(simProfileProvider.notifier).state = p.value
                  : null,
            ),
          );
        }).toList(),
      );
    }

    return Row(
      children: _profiles.map((p) {
        final isSelected = selected == p.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: p == _profiles.last ? 0 : 12),
            child: _ProfileCard(
              profile: p,
              isSelected: isSelected,
              onTap: p.isEnabled
                  ? () => ref.read(simProfileProvider.notifier).state = p.value
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Profile {
  final SimProfile value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final String description;
  final bool isEnabled;

  const _Profile(
    this.value,
    this.label,
    this.icon,
    this.iconColor,
    this.description,
    this.isEnabled,
  );
}

class _ProfileCard extends StatelessWidget {
  final _Profile profile;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ProfileCard({
    required this.profile,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = profile.isEnabled;
    final iconColor = isEnabled ? profile.iconColor : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected && isEnabled
                ? const Color(0xFF0EA5E9)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isEnabled ? 0.1 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(profile.icon, size: 24, color: iconColor),
                ),
                const Spacer(),
                Radio<SimProfile>(
                  value: profile.value,
                  groupValue: isSelected && isEnabled ? profile.value : null,
                  onChanged: isEnabled ? (_) => onTap?.call() : null,
                  activeColor: const Color(0xFF0EA5E9),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              profile.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isEnabled
                    ? const Color(0xFF111827)
                    : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.description,
              style: TextStyle(
                fontSize: 12,
                color: isEnabled
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Wind Signal Selector (TCWS)
// -----------------------------------------------------------

class _WindSignalSelector extends ConsumerWidget {
  const _WindSignalSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(windPresetProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      // Mobile: 2-column grid + last item full width if odd
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: windPresets.map((preset) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 48 - 10) / 2,
            child: _WindChip(
              preset: preset,
              isSelected: selected == preset,
              onTap: () => ref.read(windPresetProvider.notifier).state = preset,
            ),
          );
        }).toList(),
      );
    }

    return Row(
      children: windPresets.map((preset) {
        final isLast = preset == windPresets.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: _WindChip(
              preset: preset,
              isSelected: selected == preset,
              onTap: () => ref.read(windPresetProvider.notifier).state = preset,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WindChip extends StatelessWidget {
  final WindPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _WindChip({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? const Color(0xFF0EA5E9)
        : const Color(0xFFE5E7EB);
    final bgColor = isSelected ? const Color(0xFFEFF6FF) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  preset.icon,
                  size: 18,
                  color: isSelected
                      ? const Color(0xFF0EA5E9)
                      : const Color(0xFF6B7280),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0EA5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 11,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preset.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF0EA5E9)
                    : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${preset.windSpeedKph.toInt()} km/h',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? const Color(0xFF0369A1)
                    : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.description,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9CA3AF),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Rainfall Selector
// -----------------------------------------------------------

class _RainfallSelector extends ConsumerWidget {
  const _RainfallSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(rainfallPresetProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: rainfallPresets.map((preset) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 48 - 10) / 2,
            child: _RainfallChip(
              preset: preset,
              isSelected: selected == preset,
              onTap: () =>
                  ref.read(rainfallPresetProvider.notifier).state = preset,
            ),
          );
        }).toList(),
      );
    }

    return Row(
      children: rainfallPresets.map((preset) {
        final isLast = preset == rainfallPresets.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: _RainfallChip(
              preset: preset,
              isSelected: selected == preset,
              onTap: () =>
                  ref.read(rainfallPresetProvider.notifier).state = preset,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RainfallChip extends StatelessWidget {
  final RainfallPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _RainfallChip({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? const Color(0xFF0EA5E9)
        : const Color(0xFFE5E7EB);
    final bgColor = isSelected ? const Color(0xFFEFF6FF) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  preset.icon,
                  size: 18,
                  color: isSelected
                      ? const Color(0xFF0EA5E9)
                      : const Color(0xFF6B7280),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0EA5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 11,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preset.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF0EA5E9)
                    : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${preset.rainfallMm.toInt()} mm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? const Color(0xFF0369A1)
                    : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.description,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9CA3AF),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Additional Parameters Form (Preparation Window only)
// -----------------------------------------------------------

class _AdditionalParametersForm extends ConsumerWidget {
  const _AdditionalParametersForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prepWindow = ref.watch(_prepWindowProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _paramDropdown(
            label: 'Preparation Window',
            helper: 'Time available before impact',
            value: prepWindow,
            items: const [
              '6 Hours',
              '12 Hours',
              '24 Hours',
              '48 Hours',
              '1 Week',
              '2 Weeks',
              '1 Month',
              '3 Months',
              '6 Months',
            ],
            onChanged: (v) => ref.read(_prepWindowProvider.notifier).state = v!,
          ),
        ],
      ),
    );
  }

  Widget _paramDropdown({
    required String label,
    required String helper,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: const InputDecoration(),
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF6B7280),
            size: 18,
          ),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
        ),
        const SizedBox(height: 4),
        Text(
          helper,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }
}
