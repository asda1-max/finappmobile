import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../data/stock_repository.dart';
import '../widgets/glassmorphic_card.dart';

/// Settings screen with hybrid weight configuration.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _repo = StockRepository();
  bool _loading = true;
  String? _statusMsg;

  // use_cagr weights
  final _useCagrWeights = List<double>.filled(8, 0.0);
  double _useCagrRec = 0.52;
  double _useCagrBuy = 0.44;
  double _useCagrRisk = 0.34;

  // no_cagr weights
  final _noCagrWeights = List<double>.filled(8, 0.0);
  double _noCagrRec = 0.655;
  double _noCagrBuy = 0.555;
  double _noCagrRisk = 0.455;


  static const _defaultUseCagr = [0.18, 0.06, 0.12, 0.20, 0.15, 0.15, 0.08, 0.12];
  static const _defaultNoCagr = [0.20, 0.00, 0.10, 0.30, 0.20, 0.20, 0.00, 0.00];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final data = await _repo.fetchHybridConfig();
      _applyConfig(data);
    } catch (e) {
      _resetToDefaults();
    }
    setState(() => _loading = false);
  }

  void _applyConfig(Map<String, dynamic> data) {
    final useCagr = data['use_cagr'] as Map<String, dynamic>? ?? {};
    final noCagr = data['no_cagr'] as Map<String, dynamic>? ?? {};

    final ucWeights = useCagr['weights'] as List<dynamic>?;
    final ncWeights = noCagr['weights'] as List<dynamic>?;

    if (ucWeights != null && ucWeights.length == 8) {
      for (var i = 0; i < 8; i++) {
        _useCagrWeights[i] = (ucWeights[i] as num).toDouble();
      }
    } else {
      for (var i = 0; i < 8; i++) _useCagrWeights[i] = _defaultUseCagr[i];
    }

    if (ncWeights != null && ncWeights.length == 8) {
      for (var i = 0; i < 8; i++) {
        _noCagrWeights[i] = (ncWeights[i] as num).toDouble();
      }
    } else {
      for (var i = 0; i < 8; i++) _noCagrWeights[i] = _defaultNoCagr[i];
    }

    _useCagrRec = (useCagr['recommended'] as num?)?.toDouble() ?? 0.52;
    _useCagrBuy = (useCagr['buy'] as num?)?.toDouble() ?? 0.44;
    _useCagrRisk = (useCagr['risk'] as num?)?.toDouble() ?? 0.34;

    _noCagrRec = (noCagr['recommended'] as num?)?.toDouble() ?? 0.655;
    _noCagrBuy = (noCagr['buy'] as num?)?.toDouble() ?? 0.555;
    _noCagrRisk = (noCagr['risk'] as num?)?.toDouble() ?? 0.455;
  }

  void _resetToDefaults() {
    for (var i = 0; i < 8; i++) {
      _useCagrWeights[i] = _defaultUseCagr[i];
      _noCagrWeights[i] = _defaultNoCagr[i];
    }
    _useCagrRec = 0.52; _useCagrBuy = 0.44; _useCagrRisk = 0.34;
    _noCagrRec = 0.655; _noCagrBuy = 0.555; _noCagrRisk = 0.455;
    setState(() => _statusMsg = 'Reset to defaults');
  }

  void _applyPreset(String preset) {
    switch (preset) {
      case 'dividend':
        _useCagrWeights.setAll(0, [0.10, 0.04, 0.30, 0.15, 0.10, 0.10, 0.06, 0.15]);
        _noCagrWeights.setAll(0, [0.10, 0.00, 0.35, 0.20, 0.15, 0.20, 0.00, 0.00]);
      case 'value':
        _useCagrWeights.setAll(0, [0.15, 0.05, 0.10, 0.30, 0.20, 0.10, 0.05, 0.05]);
        _noCagrWeights.setAll(0, [0.15, 0.00, 0.10, 0.35, 0.25, 0.15, 0.00, 0.00]);
      case 'growth':
        _useCagrWeights.setAll(0, [0.20, 0.10, 0.05, 0.10, 0.10, 0.10, 0.15, 0.20]);
        _noCagrWeights.setAll(0, [0.25, 0.00, 0.05, 0.15, 0.15, 0.15, 0.00, 0.25]);
    }
    setState(() => _statusMsg = 'Preset applied');
  }

  Future<void> _saveConfig() async {
    try {
      await _repo.saveHybridConfig(
        useCagrWeights: _useCagrWeights,
        useCagrRec: _useCagrRec,
        useCagrBuy: _useCagrBuy,
        useCagrRisk: _useCagrRisk,
        noCagrWeights: _noCagrWeights,
        noCagrRec: _noCagrRec,
        noCagrBuy: _noCagrBuy,
        noCagrRisk: _noCagrRisk,
      );
      setState(() => _statusMsg = 'Config saved successfully ✓');
    } catch (e) {
      setState(() => _statusMsg = 'Error saving: $e');
    }
  }

  double _totalWeight(List<double> weights) =>
      weights.fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Header
            Row(
              children: [
                const Text('⚙️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Hybrid Weight Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Adjust criteria weights for with-CAGR and no-CAGR modes.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),

            // Two columns
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _WeightColumn(
                    title: 'Mode: use_cagr',
                    weights: _useCagrWeights,
                    rec: _useCagrRec,
                    buy: _useCagrBuy,
                    risk: _useCagrRisk,
                    onWeightChanged: (i, v) =>
                        setState(() => _useCagrWeights[i] = v),
                    onRecChanged: (v) =>
                        setState(() => _useCagrRec = v),
                    onBuyChanged: (v) =>
                        setState(() => _useCagrBuy = v),
                    onRiskChanged: (v) =>
                        setState(() => _useCagrRisk = v),
                    totalWeight: _totalWeight(_useCagrWeights),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WeightColumn(
                    title: 'Mode: no_cagr',
                    weights: _noCagrWeights,
                    rec: _noCagrRec,
                    buy: _noCagrBuy,
                    risk: _noCagrRisk,
                    onWeightChanged: (i, v) =>
                        setState(() => _noCagrWeights[i] = v),
                    onRecChanged: (v) =>
                        setState(() => _noCagrRec = v),
                    onBuyChanged: (v) =>
                        setState(() => _noCagrBuy = v),
                    onRiskChanged: (v) =>
                        setState(() => _noCagrRisk = v),
                    totalWeight: _totalWeight(_noCagrWeights),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Presets
            Text(
              'Quick Presets:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetChip(
                  label: '💰 Dividend Chaser',
                  color: AppColors.holdAmber,
                  onTap: () => _applyPreset('dividend'),
                ),
                _PresetChip(
                  label: '💎 Value Champion',
                  color: AppColors.buyGreen,
                  onTap: () => _applyPreset('value'),
                ),
                _PresetChip(
                  label: '🚀 Growth Aggressive',
                  color: AppColors.sellRed,
                  onTap: () => _applyPreset('growth'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset ke Default'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Simpan Config'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
                if (_statusMsg != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    _statusMsg!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.buyGreen,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightColumn extends StatelessWidget {
  final String title;
  final List<double> weights;
  final double rec, buy, risk;
  final void Function(int, double) onWeightChanged;
  final ValueChanged<double> onRecChanged;
  final ValueChanged<double> onBuyChanged;
  final ValueChanged<double> onRiskChanged;
  final double totalWeight;

  const _WeightColumn({
    required this.title,
    required this.weights,
    required this.rec,
    required this.buy,
    required this.risk,
    required this.onWeightChanged,
    required this.onRecChanged,
    required this.onBuyChanged,
    required this.onRiskChanged,
    required this.totalWeight,
  });

  static const _labels = [
    'ROE', 'Net Income CAGR', 'Dividend Yield', 'MOS',
    'PBV Score', 'PER Score', 'Revenue CAGR', 'EPS CAGR',
  ];

  @override
  Widget build(BuildContext context) {
    final isBalanced = (totalWeight - 1.0).abs() < 0.01;

    return GlassmorphicCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '● $title',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 8; i++) ...[
            _WeightRow(
              label: '${i + 1}. ${_labels[i]}',
              value: weights[i],
              onChanged: (v) => onWeightChanged(i, v),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Total bobot: ${totalWeight.toStringAsFixed(4)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isBalanced ? AppColors.buyGreen : AppColors.sellRed,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ThresholdField(
                  label: 'Recommended',
                  value: rec,
                  onChanged: onRecChanged,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ThresholdField(
                  label: 'Buy',
                  value: buy,
                  onChanged: onBuyChanged,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ThresholdField(
                  label: 'Risk',
                  value: risk,
                  onChanged: onRiskChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _WeightRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
            ),
          ),
          SizedBox(
            width: 56,
            height: 28,
            child: TextField(
              controller: TextEditingController(text: value.toStringAsFixed(2)),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) onChanged(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _ThresholdField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        SizedBox(
          height: 28,
          child: TextField(
            controller:
                TextEditingController(text: value.toStringAsFixed(3)),
            style: const TextStyle(
                fontSize: 11, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.cardBorder),
              ),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PresetChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
