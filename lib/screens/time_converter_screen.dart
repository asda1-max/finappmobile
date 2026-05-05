import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../core/theme/app_colors.dart';
import '../widgets/glassmorphic_card.dart';

class TimeConverterScreen extends StatefulWidget {
  const TimeConverterScreen({super.key});

  @override
  State<TimeConverterScreen> createState() => _TimeConverterScreenState();
}

class _TimeConverterScreenState extends State<TimeConverterScreen> {
  bool _initialized = false;
  
  String _baseZone = 'Asia/Jakarta';
  TimeOfDay _baseTime = TimeOfDay.now();
  Timer? _timer;
  bool _isManualTime = false;

  final List<String> _targetZones = [
    'America/New_York',
    'Europe/London',
    'Asia/Tokyo',
    'Australia/Sydney',
  ];

  @override
  void initState() {
    super.initState();
    _initTimezones();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isManualTime && _initialized) {
        final now = TimeOfDay.now();
        if (now.hour != _baseTime.hour || now.minute != _baseTime.minute) {
          setState(() => _baseTime = now);
        }
      }
    });
  }

  Future<void> _initTimezones() async {
    tz_data.initializeTimeZones();
    setState(() {
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  Future<void> _pickZone({required bool isBase, int? replaceIndex}) async {
    final locations = tz.timeZoneDatabase.locations.keys.toList()..sort();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TimezonePickerSheet(locations: locations),
    );

    if (selected != null) {
      setState(() {
        if (isBase) {
          _baseZone = selected;
        } else {
          if (replaceIndex != null) {
            _targetZones[replaceIndex] = selected;
          } else {
            if (!_targetZones.contains(selected) && selected != _baseZone) {
              _targetZones.add(selected);
            }
          }
        }
      });
    }
  }

  List<_ZoneTime> _buildConversionsFor(List<String> zones, {List<String>? customLabels}) {
    if (!_initialized) return [];

    final now = DateTime.now();
    final baseLoc = tz.getLocation(_baseZone);
    // Construct base time using today's date
    final baseDt = tz.TZDateTime(
      baseLoc, now.year, now.month, now.day, _baseTime.hour, _baseTime.minute,
    );

    return zones.asMap().entries.map((entry) {
      final idx = entry.key;
      final zoneName = entry.value;
      try {
        final loc = tz.getLocation(zoneName);
        final targetDt = tz.TZDateTime.from(baseDt, loc);
        
        final diffHours = targetDt.timeZoneOffset.inHours - baseDt.timeZoneOffset.inHours;
        final sign = diffHours >= 0 ? '+' : '';
        
        return _ZoneTime(
          label: customLabels != null ? customLabels[idx] : _formatZoneName(zoneName),
          rawZoneName: zoneName,
          timeLabel: '${targetDt.hour.toString().padLeft(2, '0')}:${targetDt.minute.toString().padLeft(2, '0')}',
          offsetLabel: 'UTC$sign$diffHours',
          isTomorrow: targetDt.day > baseDt.day,
          isYesterday: targetDt.day < baseDt.day,
        );
      } catch (_) {
        return _ZoneTime(label: zoneName, rawZoneName: zoneName, timeLabel: '--:--', offsetLabel: '');
      }
    }).toList();
  }

  String _formatZoneName(String name) {
    return name.replaceAll('_', ' ').split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: !_initialized
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        child: const Text(
                          'Time Converter',
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
                    'Konversi waktu akurat untuk 400+ zona waktu global.',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 16),

                  // Base Time Configurator
                  GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📍 Waktu Asal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pickZone(isBase: true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Zona Asal',
                                              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                                            ),
                                            Text(
                                              _formatZoneName(_baseZone),
                                              style: const TextStyle(
                                                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _pickTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Text('Pukul', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                    Text(
                                      '${_baseTime.hour.toString().padLeft(2, '0')}:${_baseTime.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isManualTime)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isManualTime = false;
                                  _baseTime = TimeOfDay.now();
                                });
                              },
                              child: Text('Reset ke waktu sekarang', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick View (Hardcoded Local & London)
                  GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚡ Konversi Cepat',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: _buildConversionsFor(
                            ['Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura', 'Europe/London'],
                            customLabels: ['WIB (UTC+7)', 'WITA (UTC+8)', 'WIT (UTC+9)', 'London (UTC+0)'],
                          ).map((zone) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    Row(
                                      children: [
                                        if (zone.isTomorrow || zone.isYesterday)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              zone.isTomorrow ? 'Besok' : 'Kemarin',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: zone.isTomorrow ? AppColors.buyGreen : AppColors.sellRed,
                                              ),
                                            ),
                                          ),
                                        Text(zone.timeLabel,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                            )),
                                      ],
                                    ),
                                  ],
                                ),
                              )).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Target Zones
                  GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '🌍 Zona Tujuan',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _pickZone(isBase: false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                                    SizedBox(width: 4),
                                    Text('Tambah', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._buildConversionsFor(_targetZones).asMap().entries.map((entry) {
                          final idx = entry.key;
                          final zone = entry.value;
                          return Dismissible(
                            key: ValueKey(zone.rawZoneName),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              setState(() => _targetZones.removeAt(idx));
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: AppColors.sellRed.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_rounded, color: AppColors.sellRed),
                            ),
                            child: GestureDetector(
                              onTap: () => _pickZone(isBase: false, replaceIndex: idx),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(zone.label,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            )),
                                        const SizedBox(height: 2),
                                        Text('${zone.rawZoneName} • ${zone.offsetLabel}',
                                            style: TextStyle(
                                              color: AppColors.textTertiary,
                                              fontSize: 10,
                                            )),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(zone.timeLabel,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            )),
                                        if (zone.isTomorrow || zone.isYesterday)
                                          Text(
                                            zone.isTomorrow ? 'Besok' : 'Kemarin',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: zone.isTomorrow ? AppColors.buyGreen : AppColors.sellRed,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        if (_targetZones.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('Belum ada zona tujuan.\nKlik "Tambah" untuk menambahkan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            ),
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

class _ZoneTime {
  final String label;
  final String rawZoneName;
  final String timeLabel;
  final String offsetLabel;
  final bool isTomorrow;
  final bool isYesterday;

  const _ZoneTime({
    required this.label,
    required this.rawZoneName,
    required this.timeLabel,
    this.offsetLabel = '',
    this.isTomorrow = false,
    this.isYesterday = false,
  });
}

// ── Timezone Picker Bottom Sheet ──

class _TimezonePickerSheet extends StatefulWidget {
  final List<String> locations;
  const _TimezonePickerSheet({required this.locations});

  @override
  State<_TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<_TimezonePickerSheet> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.locations;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = widget.locations.where((l) => l.toLowerCase().contains(lower)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 12),
            const Text('Pilih Zona Waktu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari zona waktu... (contoh: Jakarta, New_York)',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  filled: true, fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: _filter,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_filtered.length} zona waktu tersedia',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _filtered.length,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemBuilder: (_, i) {
                  final loc = _filtered[i];
                  final parts = loc.split('/');
                  final city = parts.last.replaceAll('_', ' ');
                  final region = parts.length > 1 ? parts.first : '';
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    title: Text(city,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: Text(region.isNotEmpty ? '$region • $loc' : loc,
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    onTap: () => Navigator.pop(context, loc),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
