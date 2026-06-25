/// ACTA Frontend — Parameter Control Panel Widget
/// =================================================
/// Left-hand panel containing simulation parameter inputs:
///   - Wind Speed (kph) input field
///   - 24-hour Accumulated Rainfall (mm) input field
///   - Time-to-Impact preparation window slider (T)
///   - Run Simulation action button
///
/// Target Branch : feature/frontend-dashboard
/// Commit        : feat(frontend): build responsive layout controls and map visualization canvas stubs
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/simulation_models.dart';
import '../dashboard_screen.dart';

class ControlPanel extends ConsumerStatefulWidget {
  final VoidCallback onRunSimulation;
  final bool isLoading;

  const ControlPanel({
    super.key,
    required this.onRunSimulation,
    required this.isLoading,
  });

  @override
  ConsumerState<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends ConsumerState<ControlPanel> {
  late TextEditingController _windController;
  late TextEditingController _rainController;
  double _prepWindow = 36;

  @override
  void initState() {
    super.initState();
    final params = ref.read(simulationParamsProvider);
    _windController =
        TextEditingController(text: params.windSpeedKph.toStringAsFixed(1));
    _rainController =
        TextEditingController(text: params.precipitation24hMm.toStringAsFixed(1));
    _prepWindow = params.preparationWindowHours.toDouble();
  }

  @override
  void dispose() {
    _windController.dispose();
    _rainController.dispose();
    super.dispose();
  }

  /// Update the shared simulation parameters state.
  void _updateParams() {
    final wind = double.tryParse(_windController.text) ?? 80.0;
    final rain = double.tryParse(_rainController.text) ?? 200.0;

    ref.read(simulationParamsProvider.notifier).state = SimulationInput(
      windSpeedKph: wind.clamp(0, 400),
      precipitation24hMm: rain.clamp(0, 2000),
      preparationWindowHours: _prepWindow.round(),
      stormTrackPoints: const [
        [120.98, 14.60],
        [120.95, 14.55],
        [120.90, 14.50],
      ],
    );
  }

  /// Determine urgency label for the preparation window.
  String get _urgencyLabel {
    if (_prepWindow >= 48) return 'STRUCTURAL';
    if (_prepWindow >= 24) return 'TRANSITIONAL';
    return 'IMMEDIATE';
  }

  Color get _urgencyColor {
    if (_prepWindow >= 48) return const Color(0xFF66BB6A);
    if (_prepWindow >= 24) return const Color(0xFFFFB74D);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                'Simulation Parameters',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Configure meteorological inputs and preparation window.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 24),

          // Wind Speed Input
          _buildSectionLabel('Wind Speed', 'kph', Icons.air),
          const SizedBox(height: 8),
          TextField(
            controller: _windController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: const InputDecoration(
              hintText: 'e.g., 120.5',
              suffixText: 'kph',
            ),
            onChanged: (_) => _updateParams(),
          ),

          const SizedBox(height: 20),

          // Precipitation Input
          _buildSectionLabel('24h Precipitation', 'mm', Icons.water_drop_outlined),
          const SizedBox(height: 8),
          TextField(
            controller: _rainController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: const InputDecoration(
              hintText: 'e.g., 350.0',
              suffixText: 'mm',
            ),
            onChanged: (_) => _updateParams(),
          ),

          const SizedBox(height: 28),

          // Time-to-Impact Slider
          _buildSectionLabel(
            'Preparation Window (T)',
            '${_prepWindow.round()}h',
            Icons.timer_outlined,
          ),
          const SizedBox(height: 4),

          // Urgency badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _urgencyColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _urgencyLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _urgencyColor,
                letterSpacing: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Interactive slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _prepWindow,
              min: 1,
              max: 96,
              divisions: 95,
              label: '${_prepWindow.round()} hours',
              onChanged: (value) {
                setState(() => _prepWindow = value);
                _updateParams();
              },
            ),
          ),

          // Slider labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1h', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text('24h', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text('48h', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text('96h', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Phase boundary markers
          _buildPhaseIndicator(),

          const SizedBox(height: 32),

          // Run Simulation Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : widget.onRunSimulation,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(widget.isLoading ? 'Running...' : 'Run Simulation'),
            ),
          ),

          const SizedBox(height: 16),

          // Parameter summary
          _buildParamSummary(),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title, String suffix, IconData icon) {
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

  Widget _buildPhaseIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DECAY PHASE BOUNDARIES',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _phaseRow('≥ 48h', 'Structural Readiness', const Color(0xFF66BB6A)),
          const SizedBox(height: 4),
          _phaseRow('24-47h', 'Logistical Transition', const Color(0xFFFFB74D)),
          const SizedBox(height: 4),
          _phaseRow('< 24h', 'Immediate Response', const Color(0xFFEF5350)),
        ],
      ),
    );
  }

  Widget _phaseRow(String range, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          range,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildParamSummary() {
    final wind = double.tryParse(_windController.text) ?? 0;
    final rain = double.tryParse(_rainController.text) ?? 0;
    final threat = (wind * 0.6) + (rain * 0.15);

    String severity;
    Color sevColor;
    if (threat >= 100) {
      severity = 'CRITICAL';
      sevColor = const Color(0xFFEF5350);
    } else if (threat >= 60) {
      severity = 'HIGH';
      sevColor = const Color(0xFFFF7043);
    } else if (threat >= 30) {
      severity = 'MODERATE';
      sevColor = const Color(0xFFFFB74D);
    } else {
      severity = 'LOW';
      sevColor = const Color(0xFF66BB6A);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sevColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sevColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.assessment_outlined, size: 16, color: sevColor),
          const SizedBox(width: 8),
          Text(
            'Projected: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          Text(
            severity,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: sevColor,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
