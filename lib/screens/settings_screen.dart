import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/services/session_service.dart';
import '../data/auth_repository.dart';
import '../core/services/local_db_service.dart';
import '../core/services/notification_service.dart';
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
  final _authRepo = AuthRepository();
  bool _loading = true;
  String? _statusMsg;
  Map<String, dynamic>? _profilePreset;
  int? _prefStabilitas;
  int? _prefPertumbuhan;
  int? _prefDividen;
  int? _prefRisiko;

  final TextEditingController _alertThresholdController =
      TextEditingController();
  final TextEditingController _alertSearchController = TextEditingController();
  bool _alertEnabled = false;
  String _alertTicker = '';
  double _alertThreshold = 5.0;
  List<String> _alertCandidates = [];
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

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
    _loadAlertPrefs();
    _loadReminderPrefs();
    _loadProfilePreset();
  }
  
  Future<void> _loadProfilePreset() async {
    var prefStabilitas = await SessionService.getPrefStabilitas();
    var prefPertumbuhan = await SessionService.getPrefPertumbuhan();
    var prefDividen = await SessionService.getPrefDividen();
    var prefRisiko = await SessionService.getPrefRisiko();

    if (prefStabilitas == null && prefPertumbuhan == null && prefDividen == null && prefRisiko == null) {
      try {
        final token = await SessionService.getToken();
        if (token != null) {
          final profile = await _authRepo.getProfile(token);
          prefStabilitas = profile.prefStabilitas;
          prefPertumbuhan = profile.prefPertumbuhan;
          prefDividen = profile.prefDividen;
          prefRisiko = profile.prefRisiko;
          await SessionService.saveSession(
            token: token,
            username: profile.username,
            email: profile.email,
            profilePic: profile.profilePic,
            prefStabilitas: prefStabilitas,
            prefPertumbuhan: prefPertumbuhan,
            prefDividen: prefDividen,
            prefRisiko: prefRisiko,
          );
        }
      } catch (_) {
        // ignore profile fetch errors
      }
    }

    if (prefStabilitas != null || prefPertumbuhan != null || prefDividen != null || prefRisiko != null) {
      setState(() {
        _prefStabilitas = prefStabilitas;
        _prefPertumbuhan = prefPertumbuhan;
        _prefDividen = prefDividen;
        _prefRisiko = prefRisiko;
      });
      try {
        final preset = await _authRepo.getHybridPreset(
          _prefStabilitas ?? 3,
          _prefPertumbuhan ?? 3,
          _prefDividen ?? 3,
          _prefRisiko ?? 3,
        );
        setState(() {
          _profilePreset = preset;
        });
      } catch (e) {
        setState(() => _statusMsg = 'Preset error: $e');
      }
    }
  }

  void _applyProfilePreset() {
    if (_profilePreset == null) return;
    final useCagr = _profilePreset!['use_cagr'];
    final noCagr = _profilePreset!['no_cagr'];
    
    _useCagrWeights.setAll(0, List<double>.from(useCagr['weights'].map((x) => x.toDouble())));
    _useCagrRec = useCagr['recommended'].toDouble();
    _useCagrBuy = useCagr['buy'].toDouble();
    _useCagrRisk = useCagr['risk'].toDouble();
    
    _noCagrWeights.setAll(0, List<double>.from(noCagr['weights'].map((x) => x.toDouble())));
    _noCagrRec = noCagr['recommended'].toDouble();
    _noCagrBuy = noCagr['buy'].toDouble();
    _noCagrRisk = noCagr['risk'].toDouble();
    
    setState(() => _statusMsg = 'Profile Preset applied');
  }

  @override
  void dispose() {
    _alertThresholdController.dispose();
    _alertSearchController.dispose();
    super.dispose();
  }

  void _loadAlertPrefs() {
    final saved = LocalDbService.getSavedTickers();
    _alertCandidates = saved;
    _alertEnabled =
        LocalDbService.getPreference<bool>('alert_enabled') ?? false;
    final thresholdRaw =
        LocalDbService.getPreference<num>('alert_threshold') ?? 5.0;
    _alertThreshold = thresholdRaw.toDouble();
    _alertTicker =
        LocalDbService.getPreference<String>('alert_ticker') ??
            (saved.isNotEmpty ? saved.first : '');
    _alertThresholdController.text =
        _alertThreshold.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  void _loadReminderPrefs() {
    _reminderEnabled =
        LocalDbService.getPreference<bool>('reminder_enabled') ?? false;
    final hourRaw = LocalDbService.getPreference<num>('reminder_hour') ?? 9;
    final minuteRaw =
        LocalDbService.getPreference<num>('reminder_minute') ?? 0;
    final hour = hourRaw.toInt().clamp(0, 23).toInt();
    final minute = minuteRaw.toInt().clamp(0, 59).toInt();
    _reminderTime = TimeOfDay(hour: hour, minute: minute);
    if (_reminderEnabled) {
      NotificationService.scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
    }
  }

  void _saveAlertPrefs() {
    final parsed = double.tryParse(_alertThresholdController.text);
    if (parsed == null || parsed <= 0) {
      setState(() => _statusMsg = 'Threshold alert tidak valid');
      return;
    }
    _alertThreshold = parsed;
    LocalDbService.savePreference('alert_enabled', _alertEnabled);
    LocalDbService.savePreference('alert_ticker', _alertTicker);
    LocalDbService.savePreference('alert_threshold', _alertThreshold);
    setState(() => _statusMsg = 'Alert harga tersimpan ✓');
  }

  Future<void> _saveReminderPrefs() async {
    await LocalDbService.savePreference('reminder_enabled', _reminderEnabled);
    await LocalDbService.savePreference('reminder_hour', _reminderTime.hour);
    await LocalDbService.savePreference(
        'reminder_minute', _reminderTime.minute);

    if (_reminderEnabled) {
      await NotificationService.scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
      setState(() =>
          _statusMsg = 'Pengingat diatur ${_reminderTime.format(context)} ✓');
    } else {
      await NotificationService.cancelDailyReminder();
      setState(() => _statusMsg = 'Pengingat dimatikan');
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;
    setState(() => _reminderTime = picked);
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
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final query = _alertSearchController.text.trim().toUpperCase();
    final filteredTickers = _alertCandidates
        .where((t) => t.toUpperCase().contains(query))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
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

            // Alert Settings — Premium
            GlassmorphicCard(
              borderColor: _alertEnabled
                  ? AppColors.buyGreen.withValues(alpha: 0.4)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with animated status
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _alertEnabled
                                ? [
                                    AppColors.buyGreen.withValues(alpha: 0.3),
                                    AppColors.buyGreen.withValues(alpha: 0.1),
                                  ]
                                : [
                                    AppColors.textMuted.withValues(alpha: 0.15),
                                    AppColors.textMuted.withValues(alpha: 0.05),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _alertEnabled
                                ? AppColors.buyGreen.withValues(alpha: 0.4)
                                : AppColors.cardBorder,
                          ),
                        ),
                        child: Icon(
                          _alertEnabled
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          size: 16,
                          color: _alertEnabled
                              ? AppColors.buyGreen
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alert Harga',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _alertEnabled
                                        ? AppColors.buyGreen
                                        : AppColors.textMuted,
                                    boxShadow: _alertEnabled
                                        ? [
                                            BoxShadow(
                                              color: AppColors.buyGreen
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _alertEnabled ? 'AKTIF' : 'NONAKTIF',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _alertEnabled
                                        ? AppColors.buyGreen
                                        : AppColors.textMuted,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _alertEnabled,
                        onChanged: (v) => setState(() => _alertEnabled = v),
                        activeTrackColor: AppColors.buyGreen,
                        thumbColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Notifikasi real-time saat ticker naik melebihi threshold.',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),

                  // Animated expansion content
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: _alertEnabled
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 14),
                              // Ticker selection header
                              Row(
                                children: [
                                  Icon(Icons.track_changes_rounded,
                                      size: 12,
                                      color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PILIH TICKER',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _alertSearchController,
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Cari ticker tersimpan...',
                                  hintStyle:
                                      TextStyle(color: AppColors.textMuted),
                                  prefixIcon: const Icon(Icons.search_rounded,
                                      size: 18, color: AppColors.textMuted),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: AppColors.cardBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: AppColors.cardBorder),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 10),
                              if (filteredTickers.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          size: 14,
                                          color: AppColors.textTertiary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Belum ada ticker. Tambahkan dari Dashboard.',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textTertiary),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: filteredTickers.map((ticker) {
                                    final selected = ticker == _alertTicker;
                                    return AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: ChoiceChip(
                                        label: Text(ticker),
                                        selected: selected,
                                        onSelected: (_) => setState(
                                            () => _alertTicker = ticker),
                                        selectedColor: AppColors.primary
                                            .withValues(alpha: 0.2),
                                        backgroundColor: AppColors.surface,
                                        labelStyle: TextStyle(
                                          color: selected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                        side: BorderSide(
                                          color: selected
                                              ? AppColors.primary
                                                  .withValues(alpha: 0.5)
                                              : AppColors.cardBorder,
                                        ),
                                        avatar: selected
                                            ? Icon(Icons.check_circle_rounded,
                                                size: 14,
                                                color: AppColors.primary)
                                            : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 14),
                              // Threshold section
                              Row(
                                children: [
                                  Icon(Icons.tune_rounded,
                                      size: 12,
                                      color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'THRESHOLD',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isNarrow = constraints.maxWidth < 360;
                                  final thresholdField = TextField(
                                    controller: _alertThresholdController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 5',
                                      hintStyle:
                                          TextStyle(color: AppColors.textMuted),
                                      suffixText: '%',
                                      suffixStyle: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700),
                                      filled: true,
                                      fillColor: AppColors.surface,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: AppColors.cardBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: AppColors.cardBorder),
                                      ),
                                    ),
                                  );

                                  final saveButton = SizedBox(
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      onPressed: _saveAlertPrefs,
                                      icon: const Icon(Icons.save_rounded,
                                          size: 16),
                                      label: const Text('Simpan'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  );

                                  if (isNarrow) {
                                    return Column(
                                      children: [
                                        thresholdField,
                                        const SizedBox(height: 10),
                                        SizedBox(
                                            width: double.infinity,
                                            child: saveButton),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: thresholdField),
                                      const SizedBox(width: 10),
                                      saveButton,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              // Test button
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await NotificationService
                                        .showTestNotification();
                                    setState(() => _statusMsg =
                                        'Test notifikasi terkirim ✓');
                                  },
                                  icon: const Icon(
                                      Icons.cell_tower_rounded,
                                      size: 16),
                                  label:
                                      const Text('Test Notifikasi'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: BorderSide(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.4),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              // Summary badge
                              if (_alertTicker.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.buyGreen
                                            .withValues(alpha: 0.08),
                                        AppColors.surface,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.buyGreen
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.radar_rounded,
                                          size: 14,
                                          color: AppColors.buyGreen),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: 'Monitoring ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textTertiary,
                                                ),
                                              ),
                                              TextSpan(
                                                text: _alertTicker,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    ' — alert jika ≥${_alertThresholdController.text}%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textTertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily Reminder Settings — Premium
            GlassmorphicCard(
              borderColor: _reminderEnabled
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _reminderEnabled
                                ? [
                                    AppColors.primary.withValues(alpha: 0.3),
                                    AppColors.primary.withValues(alpha: 0.1),
                                  ]
                                : [
                                    AppColors.textMuted.withValues(alpha: 0.15),
                                    AppColors.textMuted.withValues(alpha: 0.05),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _reminderEnabled
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : AppColors.cardBorder,
                          ),
                        ),
                        child: Icon(
                          _reminderEnabled
                              ? Icons.alarm_on_rounded
                              : Icons.alarm_off_rounded,
                          size: 16,
                          color: _reminderEnabled
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pengingat Harian',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _reminderEnabled
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    boxShadow: _reminderEnabled
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _reminderEnabled
                                      ? 'AKTIF — ${_reminderTime.format(context)}'
                                      : 'NONAKTIF',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _reminderEnabled
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _reminderEnabled,
                        onChanged: (v) async {
                          setState(() => _reminderEnabled = v);
                          await _saveReminderPrefs();
                        },
                        activeTrackColor: AppColors.primary,
                        thumbColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pengingat harian untuk cek watchlist dan peluang baru.',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: _reminderEnabled
                        ? Column(
                            children: [
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isNarrow = constraints.maxWidth < 360;

                                  final timePicker = GestureDetector(
                                    onTap: _pickReminderTime,
                                    child: Container(
                                      height: 52,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.schedule_rounded,
                                              size: 18,
                                              color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Text(
                                            _reminderTime.format(context),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(Icons.edit_rounded,
                                              size: 14,
                                              color: AppColors.textMuted),
                                        ],
                                      ),
                                    ),
                                  );

                                  final saveButton = SizedBox(
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      onPressed: _saveReminderPrefs,
                                      icon: const Icon(Icons.save_rounded,
                                          size: 16),
                                      label: const Text('Simpan'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  );

                                  if (isNarrow) {
                                    return Column(
                                      children: [
                                        timePicker,
                                        const SizedBox(height: 10),
                                        SizedBox(
                                            width: double.infinity,
                                            child: saveButton),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: timePicker),
                                      const SizedBox(width: 10),
                                      saveButton,
                                    ],
                                  );
                                },
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),


            _WeightColumn(
              title: 'Mode: use_cagr',
              weights: _useCagrWeights,
              rec: _useCagrRec,
              buy: _useCagrBuy,
              risk: _useCagrRisk,
              onWeightChanged: (i, v) =>
                  setState(() => _useCagrWeights[i] = v),
              onRecChanged: (v) => setState(() => _useCagrRec = v),
              onBuyChanged: (v) => setState(() => _useCagrBuy = v),
              onRiskChanged: (v) => setState(() => _useCagrRisk = v),
              totalWeight: _totalWeight(_useCagrWeights),
            ),
            const SizedBox(height: 12),
            _WeightColumn(
              title: 'Mode: no_cagr',
              weights: _noCagrWeights,
              rec: _noCagrRec,
              buy: _noCagrBuy,
              risk: _noCagrRisk,
              onWeightChanged: (i, v) =>
                  setState(() => _noCagrWeights[i] = v),
              onRecChanged: (v) => setState(() => _noCagrRec = v),
              onBuyChanged: (v) => setState(() => _noCagrBuy = v),
              onRiskChanged: (v) => setState(() => _noCagrRisk = v),
              totalWeight: _totalWeight(_noCagrWeights),
            ),
            const SizedBox(height: 16),

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
                if (_profilePreset != null)
                  _PresetChip(
                    label: '✨ Profile Preset',
                    color: AppColors.primary,
                    onTap: _applyProfilePreset,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Simpan Config'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
                if (_statusMsg != null)
                  Text(
                    _statusMsg!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.buyGreen,
                    ),
                  ),
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
          _NumberField(
            value: value,
            decimals: 2,
            step: 0.01,
            onChanged: onChanged,
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
        _NumberField(
          value: value,
          decimals: 3,
          step: 0.01,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _NumberField extends StatefulWidget {
  final double value;
  final int decimals;
  final double step;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.value,
    required this.decimals,
    required this.step,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value.toStringAsFixed(widget.decimals),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) return;
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value.toStringAsFixed(widget.decimals);
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitValue();
    }
  }

  void _commitValue() {
    final parsed = double.tryParse(_controller.text);
    if (parsed == null) {
      _controller.text = widget.value.toStringAsFixed(widget.decimals);
      return;
    }
    final next = parsed;
    _controller.text = next.toStringAsFixed(widget.decimals);
    widget.onChanged(next);
  }

  void _stepValue(double delta) {
    final parsed = double.tryParse(_controller.text) ?? widget.value;
    final next = parsed + delta;
    _controller.text = next.toStringAsFixed(widget.decimals);
    widget.onChanged(next);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 32,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}')),
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                if (parsed != null) widget.onChanged(parsed);
              },
              onEditingComplete: _commitValue,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 16,
            height: 32,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepButton(
                  icon: Icons.keyboard_arrow_up_rounded,
                  onTap: () => _stepValue(widget.step),
                ),
                _StepButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onTap: () => _stepValue(-widget.step),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      width: 16,
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, size: 12, color: AppColors.textSecondary),
      ),
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
