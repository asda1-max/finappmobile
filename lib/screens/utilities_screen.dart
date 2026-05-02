import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glassmorphic_card.dart';

class UtilitiesScreen extends StatefulWidget {
  const UtilitiesScreen({super.key});

  @override
  State<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends State<UtilitiesScreen> {
  final TextEditingController _amountController =
      TextEditingController(text: '100000');

  Map<String, double> _rates = {
    'IDR': 17334.0,
    'USD': 1.0,
    'EUR': 0.93,
    'JPY': 150.0,
    'GBP': 0.79,
    'SGD': 1.34,
    'AUD': 1.53,
  };
  bool _isLoadingRates = false;
  String _lastUpdate = '';

  String _fromCurrency = 'IDR';
  String _toCurrency = 'USD';
  double? _converted;

  final Map<String, int> _timeZones = const {
    'WIB (UTC+7)': 7,
    'WITA (UTC+8)': 8,
    'WIT (UTC+9)': 9,
    'London (UTC+0)': 0,
  };

  String _baseZone = 'WIB (UTC+7)';
  TimeOfDay _baseTime = TimeOfDay.now();
  Timer? _timer;
  bool _isManualTime = false;

  @override
  void initState() {
    super.initState();
    _fetchRates();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isManualTime) {
        final now = TimeOfDay.now();
        if (now.hour != _baseTime.hour || now.minute != _baseTime.minute) {
          setState(() => _baseTime = now);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchRates() async {
    if (!mounted) return;
    setState(() => _isLoadingRates = true);
    try {
      final response = await Dio().get('https://open.er-api.com/v6/latest/USD');
      final data = response.data['rates'] as Map<String, dynamic>;
      
      if (mounted) {
        setState(() {
          _rates = {
            'IDR': (data['IDR'] as num?)?.toDouble() ?? 17334.0,
            'USD': 1.0,
            'EUR': (data['EUR'] as num?)?.toDouble() ?? 0.93,
            'JPY': (data['JPY'] as num?)?.toDouble() ?? 150.0,
            'GBP': (data['GBP'] as num?)?.toDouble() ?? 0.79,
            'SGD': (data['SGD'] as num?)?.toDouble() ?? 1.34,
            'AUD': (data['AUD'] as num?)?.toDouble() ?? 1.53,
          };
          
          final updateUnix = response.data['time_last_update_unix'] as int?;
          if (updateUnix != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(updateUnix * 1000);
            _lastUpdate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          }
        });
      }
    } catch (_) {
      // Fallback to static defaults
    } finally {
      if (mounted) {
        setState(() => _isLoadingRates = false);
        _recalculate();
      }
    }
  }

  void _recalculate() {
    final raw = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null) {
      setState(() => _converted = null);
      return;
    }
    final fromRate = _rates[_fromCurrency] ?? 1.0;
    final toRate = _rates[_toCurrency] ?? 1.0;
    final usd = amount / fromRate;
    setState(() => _converted = usd * toRate);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _baseTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: AppColors.surface,
              hourMinuteColor: AppColors.card,
              dialBackgroundColor: AppColors.card,
              entryModeIconColor: AppColors.primary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (selected != null) {
      setState(() {
        _baseTime = selected;
        _isManualTime = true;
      });
    }
  }

  List<_ZoneTime> _buildTimeConversions() {
    final baseOffset = _timeZones[_baseZone] ?? 0;
    final baseMinutes = _baseTime.hour * 60 + _baseTime.minute;

    return _timeZones.entries.map((entry) {
      final diff = (entry.value - baseOffset) * 60;
      var minutes = baseMinutes + diff;
      minutes = ((minutes % 1440) + 1440) % 1440;
      final hour = minutes ~/ 60;
      final minute = minutes % 60;
      return _ZoneTime(
        label: entry.key,
        timeLabel: '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final timeConversions = _buildTimeConversions();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Financial Utilities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Konversi yang mendukung analisis dan monitoring pasar global.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),

            // Currency converter
            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '💱 Konversi Mata Uang',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_isLoadingRates)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      else if (_lastUpdate.isNotEmpty)
                        Text(
                          'Update: $_lastUpdate',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Simulasi FX dengan nilai tukar real-time.',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Jumlah',
                      labelStyle: TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                    onChanged: (_) => _recalculate(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _CurrencyDropdown(
                          label: 'Dari',
                          value: _fromCurrency,
                          items: _rates.keys.toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _fromCurrency = v);
                            _recalculate();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CurrencyDropdown(
                          label: 'Ke',
                          value: _toCurrency,
                          items: _rates.keys.toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _toCurrency = v);
                            _recalculate();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hasil',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _converted == null
                              ? '-'
                              : '${_converted!.toStringAsFixed(2)} $_toCurrency',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Time converter
            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🕒 Konversi Waktu Pasar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sesuaikan jadwal trading antar zona waktu.',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _baseZone,
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          decoration: InputDecoration(
                            labelText: 'Zona asal',
                            labelStyle:
                                TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: AppColors.cardBorder),
                            ),
                          ),
                          items: _timeZones.keys
                              .map((zone) => DropdownMenuItem(
                                    value: zone,
                                    child: Text(
                                      zone,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _baseZone = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        width: 92,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: FittedBox(
                            child: Text(_baseTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: timeConversions
                        .map(
                          (zone) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(zone.label,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    )),
                                Text(zone.timeLabel,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sensors
            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📡 Sensor Market Motion',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sensor perangkat untuk ilustrasi volatilitas dan stabilitas.',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 12),
                  _SensorCard(
                    title: 'Accelerometer',
                    subtitle: 'Stabilitas gerakan perangkat',
                    icon: Icons.speed_rounded,
                    stream: accelerometerEvents,
                  ),
                  const SizedBox(height: 10),
                  _SensorCard(
                    title: 'Gyroscope',
                    subtitle: 'Rotasi & arah perangkat',
                    icon: Icons.explore_rounded,
                    stream: gyroscopeEvents,
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _CurrencyDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppColors.surface,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      items: items
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _SensorCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Stream<dynamic> stream;

  const _SensorCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final x = (data?.x ?? 0).toDouble();
        final y = (data?.y ?? 0).toDouble();
        final z = (data?.z ?? 0).toDouble();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        )),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('x: ${x.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      )),
                  Text('y: ${y.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      )),
                  Text('z: ${z.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ZoneTime {
  final String label;
  final String timeLabel;

  const _ZoneTime({required this.label, required this.timeLabel});
}
