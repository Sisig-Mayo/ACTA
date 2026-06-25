/// ACTA Frontend — Simulation Setup Screen
/// ==========================================
/// Configure scenario profiles and parameters, then launch a
/// simulation against the FastAPI backend.
/// Renders as content inside AppShell (no Scaffold).
///
/// Target Branch : feat/dashboard
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/simulation_models.dart';
import '../models/simulation_state.dart';
import 'app_shell.dart';

// -----------------------------------------------------------
// Local providers
// -----------------------------------------------------------

final _rainfallProvider = StateProvider<String>((ref) => '120');
final _windSpeedProvider = StateProvider<String>((ref) => '65');
final _prepWindowProvider = StateProvider<String>((ref) => '24 Hours');
final _pumpingStatusProvider =
    StateProvider<String>((ref) => '3 Offline');
final _rescueAssetsProvider =
    StateProvider<String>((ref) => '12 Boats Available');
final _affectedDistrictProvider =
    StateProvider<String>((ref) => 'All Districts (NCR)');
final _notesProvider = StateProvider<String>((ref) => '');

// -----------------------------------------------------------
// Simulation Setup Content
// -----------------------------------------------------------

class SimulationSetupContent extends ConsumerStatefulWidget {
  const SimulationSetupContent({super.key});

  @override
  ConsumerState<SimulationSetupContent> createState() =>
      _SimulationSetupContentState();
}

class _SimulationSetupContentState
    extends ConsumerState<SimulationSetupContent> {
  late final TextEditingController _rainfallCtrl;
  late final TextEditingController _windCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _rainfallCtrl = TextEditingController(
        text: ref.read(_rainfallProvider));
    _windCtrl =
        TextEditingController(text: ref.read(_windSpeedProvider));
    _notesCtrl =
        TextEditingController(text: ref.read(_notesProvider));
  }

  @override
  void dispose() {
    _rainfallCtrl.dispose();
    _windCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSimulation() async {
    final profile = ref.read(simProfileProvider);
    final rainfall = double.tryParse(_rainfallCtrl.text) ?? 120.0;
    final wind = double.tryParse(_windCtrl.text) ?? 65.0;
    final prepWindow =
        int.tryParse(ref.read(_prepWindowProvider).split(' ').first) ?? 24;

    // Save snapshot for display in run screen
    ref.read(simulationInputSnapshotProvider.notifier).state = {
      'profile': profile.label,
      'rainfall_mm': rainfall,
      'wind_kph': wind,
      'prep_hours': prepWindow,
      'affected_districts': ref.read(_affectedDistrictProvider),
      'pumping_status': ref.read(_pumpingStatusProvider),
      'rescue_assets': ref.read(_rescueAssetsProvider),
    };

    ref.read(simulationRunStateProvider.notifier).state =
        SimulationRunState.running;
    ref.read(runSimulationActiveProvider.notifier).state = true;
    ref.read(shellIndexProvider.notifier).state = 1;

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://localhost:8000',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
      ));

      final response = await dio.post(
        '/api/v1/simulation/run',
        data: {
          'wind_speed_kph': wind,
          'precipitation_24h_mm': rainfall,
          'preparation_window_hours': prepWindow,
          'storm_track_points': [
            [120.98, 14.60],
            [120.95, 14.55],
            [120.90, 14.50],
          ],
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        ref.read(simulationResultProvider.notifier).state =
            SimulationOutput.fromJson(
                response.data as Map<String, dynamic>);
      }
      ref.read(simulationRunStateProvider.notifier).state =
          SimulationRunState.completed;
    } on DioException catch (e) {
      ref.read(simulationErrorProvider.notifier).state =
          e.response?.data?['detail']?.toString() ??
              'Connection error: ${e.message}';
      ref.read(simulationRunStateProvider.notifier).state =
          SimulationRunState.error;
    } catch (e) {
      ref.read(simulationErrorProvider.notifier).state = e.toString();
      ref.read(simulationRunStateProvider.notifier).state =
          SimulationRunState.error;
    }
  }

  void _resetParameters() {
    ref.read(simProfileProvider.notifier).state =
        SimProfile.hydrologicFlood;
    _rainfallCtrl.text = '120';
    _windCtrl.text = '65';
    _notesCtrl.text = '';
    ref.read(_rainfallProvider.notifier).state = '120';
    ref.read(_windSpeedProvider.notifier).state = '65';
    ref.read(_prepWindowProvider.notifier).state = '24 Hours';
    ref.read(_pumpingStatusProvider.notifier).state = '3 Offline';
    ref.read(_rescueAssetsProvider.notifier).state =
        '12 Boats Available';
    ref.read(_affectedDistrictProvider.notifier).state =
        'All Districts (NCR)';
  }

  @override
  Widget build(BuildContext context) {
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
                const Text('1. Select Simulation Profile',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                const SizedBox(height: 14),
                _ProfileSelector(),
                const SizedBox(height: 28),

                // 2. Parameters
                const Text('2. Set Scenario Parameters',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                const SizedBox(height: 14),
                _ParametersForm(
                  rainfallCtrl: _rainfallCtrl,
                  windCtrl: _windCtrl,
                  notesCtrl: _notesCtrl,
                ),
                const SizedBox(height: 32),

                // Footer buttons
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _resetParameters,
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Reset Parameters'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _runSimulation,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Run Simulation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
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
// Profile Selector
// -----------------------------------------------------------

class _ProfileSelector extends ConsumerWidget {
  static const _profiles = [
    _Profile(
      SimProfile.hydrologicFlood,
      'Hydrologic Flood',
      Icons.flood_outlined,
      Color(0xFF0EA5E9),
      'Rainfall-induced flooding, river overflow, and drainage inundation.',
    ),
    _Profile(
      SimProfile.earthquake,
      'Earthquake',
      Icons.foundation_outlined,
      Color(0xFF374151),
      'Earthquake-induced structural damage, infrastructure disruption, and emergency response simulation.',
    ),
    _Profile(
      SimProfile.virusOutbreak,
      'Virus Outbreak',
      Icons.coronavirus_outlined,
      Color(0xFF374151),
      'Disease outbreak spread simulation and response planning.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(simProfileProvider);

    return Row(
      children: _profiles.map((p) {
        final isSelected = selected == p.value;
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: p == _profiles.last ? 0 : 12),
            child: _ProfileCard(
              profile: p,
              isSelected: isSelected,
              onTap: () =>
                  ref.read(simProfileProvider.notifier).state = p.value,
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

  const _Profile(
      this.value, this.label, this.icon, this.iconColor, this.description);
}

class _ProfileCard extends StatelessWidget {
  final _Profile profile;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileCard(
      {required this.profile,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
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
                    color: profile.iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(profile.icon,
                      size: 24, color: profile.iconColor),
                ),
                const Spacer(),
                Radio<SimProfile>(
                  value: profile.value,
                  groupValue:
                      isSelected ? profile.value : null,
                  onChanged: (_) => onTap(),
                  activeColor: const Color(0xFF0EA5E9),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(profile.label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text(profile.description,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Parameters Form
// -----------------------------------------------------------

class _ParametersForm extends ConsumerWidget {
  final TextEditingController rainfallCtrl;
  final TextEditingController windCtrl;
  final TextEditingController notesCtrl;

  const _ParametersForm({
    required this.rainfallCtrl,
    required this.windCtrl,
    required this.notesCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prepWindow = ref.watch(_prepWindowProvider);
    final pumpingStatus = ref.watch(_pumpingStatusProvider);
    final rescueAssets = ref.watch(_rescueAssetsProvider);
    final affectedDistricts = ref.watch(_affectedDistrictProvider);
    var notesLength = ref.watch(_notesProvider).length;

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
          // Row 1: Rainfall | Wind | Districts
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _paramField(
                  label: 'Rainfall Volume (mm/hr)',
                  hint: '120',
                  helper: 'Typical range 20 - 300mm',
                  controller: rainfallCtrl,
                  suffix: 'mm',
                  isNumeric: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _paramField(
                  label: 'Wind Speed (km/h)',
                  hint: '65',
                  helper: 'Typical range 10 - 150 km/h',
                  controller: windCtrl,
                  suffix: 'km/h',
                  isNumeric: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _paramDropdown(
                  label: 'Affected District(s)',
                  helper: 'Select one or more districts',
                  value: affectedDistricts,
                  items: const [
                    'All Districts (NCR)',
                    'Tondo',
                    'Sampaloc',
                    'Pandacan',
                    'Paco',
                    'Malate',
                    'Ermita',
                    'Binondo',
                    'Santa Cruz',
                  ],
                  onChanged: (v) => ref
                      .read(_affectedDistrictProvider.notifier)
                      .state = v!,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Row 2: Prep Window | Pumping | Rescue
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _paramDropdown(
                  label: 'Preparation Window',
                  helper: 'Time available before impact',
                  value: prepWindow,
                  items: const [
                    '6 Hours',
                    '12 Hours',
                    '24 Hours',
                    '48 Hours',
                    '72 Hours',
                  ],
                  onChanged: (v) =>
                      ref.read(_prepWindowProvider.notifier).state = v!,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _paramDropdown(
                  label: 'Pumping Station Status',
                  helper: 'Select current operational status',
                  value: pumpingStatus,
                  items: const [
                    'All Online',
                    '1 Offline',
                    '2 Offline',
                    '3 Offline',
                    '4+ Offline',
                  ],
                  onChanged: (v) =>
                      ref.read(_pumpingStatusProvider.notifier).state = v!,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _paramDropdown(
                  label: 'Rescue Asset Availability',
                  helper: 'Select available rescue assets',
                  value: rescueAssets,
                  items: const [
                    '4 Boats Available',
                    '8 Boats Available',
                    '12 Boats Available',
                    '16+ Boats Available',
                  ],
                  onChanged: (v) =>
                      ref.read(_rescueAssetsProvider.notifier).state = v!,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Notes
          const Text('Additional Notes (Optional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            maxLines: 4,
            maxLength: 250,
            onChanged: (v) =>
                ref.read(_notesProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Add any scenario assumptions or notes...',
              counterText: '',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$notesLength / 250',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paramField({
    required String label,
    required String hint,
    required String helper,
    required TextEditingController controller,
    String? suffix,
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType:
              isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            suffixStyle: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 12),
          ),
        ),
        const SizedBox(height: 4),
        Text(helper,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
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
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: const InputDecoration(),
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF111827)),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFF6B7280), size: 18),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
        ),
        const SizedBox(height: 4),
        Text(helper,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}


