import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glassmorphic_card.dart';

// ── Currency metadata ──
class _CurrInfo {
  final String code;
  final String name;
  final String flag;
  const _CurrInfo(this.code, this.name, this.flag);
}

const _popularCodes = [
  'usd', 'eur', 'gbp', 'jpy', 'idr', 'sgd', 'aud', 'cny', 'krw',
  'thb', 'myr', 'btc', 'eth', 'usdt', 'bnb', 'xrp', 'sol', 'ada',
];

const _quickViewCodes = ['usd', 'eur', 'gbp', 'jpy', 'idr', 'sgd', 'btc'];

String _flagFor(String code) {
  const map = {
    'usd': '🇺🇸', 'eur': '🇪🇺', 'gbp': '🇬🇧', 'jpy': '🇯🇵', 'idr': '🇮🇩',
    'sgd': '🇸🇬', 'aud': '🇦🇺', 'cny': '🇨🇳', 'krw': '🇰🇷', 'thb': '🇹🇭',
    'myr': '🇲🇾', 'cad': '🇨🇦', 'chf': '🇨🇭', 'hkd': '🇭🇰', 'nzd': '🇳🇿',
    'sek': '🇸🇪', 'nok': '🇳🇴', 'dkk': '🇩🇰', 'inr': '🇮🇳', 'php': '🇵🇭',
    'twd': '🇹🇼', 'brl': '🇧🇷', 'mxn': '🇲🇽', 'zar': '🇿🇦', 'rub': '🇷🇺',
    'try': '🇹🇷', 'aed': '🇦🇪', 'sar': '🇸🇦', 'vnd': '🇻🇳', 'pkr': '🇵🇰',
    'btc': '₿', 'eth': 'Ξ', 'usdt': '₮', 'bnb': '◆', 'xrp': '✕',
    'sol': '◎', 'ada': '₳', 'doge': '🐕', 'dot': '●', 'shib': '🐶',
  };
  return map[code.toLowerCase()] ?? '💱';
}

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});
  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen>
    with SingleTickerProviderStateMixin {
  final _amountCtrl = TextEditingController(text: '1');
  final _dio = Dio();

  Map<String, String> _currencyNames = {};
  Map<String, double> _rates = {};
  bool _loading = true;
  String? _error;
  String _lastUpdate = '';

  String _fromCode = 'usd';
  String _toCode = 'idr';
  double? _result;

  late AnimationController _swapAnim;

  @override
  void initState() {
    super.initState();
    _swapAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );
    _loadData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _swapAnim.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Load currency names
      final namesResp = await _fetchWithFallback('v1/currencies.min.json');
      if (namesResp != null && namesResp is Map) {
        _currencyNames = Map<String, String>.from(
          namesResp.map((k, v) => MapEntry(k.toString().toLowerCase(), v.toString())),
        );
      }
      // Load rates (USD base)
      final ratesResp = await _fetchWithFallback('v1/currencies/usd.min.json');
      if (ratesResp != null && ratesResp is Map) {
        final ratesMap = ratesResp['usd'] as Map<String, dynamic>? ?? {};
        _rates = {};
        for (final e in ratesMap.entries) {
          final v = double.tryParse(e.value.toString());
          if (v != null && v > 0) _rates[e.key.toLowerCase()] = v;
        }
        _lastUpdate = ratesResp['date']?.toString() ?? '';
      }
      _recalc();
    } catch (e) {
      _error = 'Gagal memuat data kurs. Periksa koneksi.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<dynamic> _fetchWithFallback(String endpoint) async {
    const primary = 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/';
    const fallback = 'https://latest.currency-api.pages.dev/';
    try {
      final r = await _dio.get('$primary$endpoint',
        options: Options(receiveTimeout: const Duration(seconds: 8)));
      return r.data;
    } catch (_) {
      final r = await _dio.get('$fallback$endpoint',
        options: Options(receiveTimeout: const Duration(seconds: 8)));
      return r.data;
    }
  }

  void _recalc() {
    final raw = _amountCtrl.text.replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || _rates.isEmpty) {
      setState(() => _result = null);
      return;
    }
    final fromRate = _rates[_fromCode] ?? 1.0;
    final toRate = _rates[_toCode] ?? 1.0;
    setState(() => _result = amount * toRate / fromRate);
  }

  void _swap() {
    _swapAnim.forward(from: 0);
    setState(() {
      final tmp = _fromCode;
      _fromCode = _toCode;
      _toCode = tmp;
    });
    _recalc();
  }

  String _formatResult(double val) {
    if (val >= 1) return val.toStringAsFixed(2);
    final s = val.toStringAsFixed(10);
    // Trim trailing zeros but keep significant digits
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _nameFor(String code) =>
      _currencyNames[code] ?? code.toUpperCase();

  List<_CurrInfo> _allCurrencies() {
    final codes = _rates.keys.toList()..sort((a, b) {
      final ai = _popularCodes.indexOf(a);
      final bi = _popularCodes.indexOf(b);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return a.compareTo(b);
    });
    return codes.map((c) => _CurrInfo(c, _nameFor(c), _flagFor(c))).toList();
  }

  Future<void> _pickCurrency(bool isFrom) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CurrencyPickerSheet(
        currencies: _allCurrencies(),
        selected: isFrom ? _fromCode : _toCode,
      ),
    );
    if (selected != null) {
      setState(() {
        if (isFrom) {
          _fromCode = selected;
        } else {
          _toCode = selected;
        }
      });
      _recalc();
    }
  }

  double? _quickRate(String targetCode) {
    if (_rates.isEmpty) return null;
    final fromRate = _rates[_fromCode] ?? 1.0;
    final toRate = _rates[targetCode] ?? 1.0;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 1.0;
    return amount * toRate / fromRate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.sellRed),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final liveRate = (_rates.isNotEmpty)
        ? (_rates[_toCode] ?? 1) / (_rates[_fromCode] ?? 1)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.currency_exchange_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: ShaderMask(
                shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                child: const Text('Currency Converter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            if (_lastUpdate.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_lastUpdate,
                  style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('200+ mata uang fiat & kripto • Real-time rates',
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        const SizedBox(height: 16),

        // Main converter card
        GlassmorphicCard(
          child: Column(
            children: [
              // Amount input
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 24, fontWeight: FontWeight.w700),
                  filled: true, fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Text(_flagFor(_fromCode), style: const TextStyle(fontSize: 22)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                ),
                onChanged: (_) => _recalc(),
              ),
              const SizedBox(height: 12),

              // From / Swap / To
              Row(
                children: [
                  Expanded(child: _currencySelector(_fromCode, true)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.5).animate(
                        CurvedAnimation(parent: _swapAnim, curve: Curves.easeInOut),
                      ),
                      child: GestureDetector(
                        onTap: _swap,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _currencySelector(_toCode, false)),
                ],
              ),
              const SizedBox(height: 16),

              // Live rate
              if (liveRate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.show_chart_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '1 ${_fromCode.toUpperCase()} = ${_formatResult(liveRate)} ${_toCode.toUpperCase()}',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: _loadData,
                        child: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Result
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.accent.withValues(alpha: 0.08)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hasil Konversi',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_flagFor(_toCode), style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _result == null ? '-' : _formatResult(_result!),
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_toCode.toUpperCase(),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick view — other currencies
        GlassmorphicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⚡ Konversi Cepat',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Hasil konversi ke mata uang populer lainnya',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              const SizedBox(height: 12),
              ...(_quickViewCodes.where((c) => c != _fromCode).take(6).map((code) {
                final val = _quickRate(code);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Text(_flagFor(code), style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(code.toUpperCase(),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(_nameFor(code),
                              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                              overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text(val == null ? '-' : _formatResult(val),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                );
              })),
            ],
          ),
        ),
      ],
    );
  }

  Widget _currencySelector(String code, bool isFrom) {
    return GestureDetector(
      onTap: () => _pickCurrency(isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Text(_flagFor(code), style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isFrom ? 'Dari' : 'Ke',
                    style: TextStyle(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
                  Text(code.toUpperCase(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Currency Picker Bottom Sheet ──

class _CurrencyPickerSheet extends StatefulWidget {
  final List<_CurrInfo> currencies;
  final String selected;
  const _CurrencyPickerSheet({required this.currencies, required this.selected});

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<_CurrInfo> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.currencies;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = widget.currencies.where((c) =>
        c.code.contains(lower) || c.name.toLowerCase().contains(lower)
      ).toList();
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
            const Text('Pilih Mata Uang',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari mata uang... (contoh: USD, Bitcoin)',
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
                child: Text('${_filtered.length} mata uang tersedia',
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
                  final c = _filtered[i];
                  final isSelected = c.code == widget.selected;
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(c.code.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                    subtitle: Text(c.name,
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      overflow: TextOverflow.ellipsis),
                    trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                      : null,
                    onTap: () => Navigator.pop(context, c.code),
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
