import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/ticker_metrics.dart';
import 'services/yahoo_finance_service.dart';

class TickerData {
  final String symbol;
  final double qualityScore;
  final double discountScore;
  final double marginOfSafety;

  const TickerData({
    required this.symbol,
    required this.qualityScore,
    required this.discountScore,
    required this.marginOfSafety,
  });

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'qualityScore': qualityScore,
      'discountScore': discountScore,
      'marginOfSafety': marginOfSafety,
    };
  }
}

class ScoredTicker {
  final String symbol;
  final TickerMetrics metrics;
  final double qualityScore;
  final double discountScore;
  final double marginOfSafety;
  final double? topsisScore;
  final String? decision;

  const ScoredTicker({
    required this.symbol,
    required this.metrics,
    required this.qualityScore,
    required this.discountScore,
    required this.marginOfSafety,
    this.topsisScore,
    this.decision,
  });

  ScoredTicker copyWith({
    double? topsisScore,
    String? decision,
  }) {
    return ScoredTicker(
      symbol: symbol,
      metrics: metrics,
      qualityScore: qualityScore,
      discountScore: discountScore,
      marginOfSafety: marginOfSafety,
      topsisScore: topsisScore ?? this.topsisScore,
      decision: decision ?? this.decision,
    );
  }
}

Future<List<Map<String, dynamic>>> calculateTopsisDecision(
  List<TickerData> tickers,
  Map<String, double> weights,
) async {
  final payload = {
    'tickers': tickers.map((t) => t.toMap()).toList(),
    'weights': weights,
  };
  return compute(_topsisEngine, payload);
}

List<Map<String, dynamic>> _topsisEngine(Map<String, dynamic> payload) {
  final rawTickers = payload['tickers'] as List<dynamic>;
  final weights = (payload['weights'] as Map).cast<String, double>();

  if (rawTickers.isEmpty) return [];

  final tickers = rawTickers.map((item) {
    final map = item as Map<String, dynamic>;
    return TickerData(
      symbol: map['symbol'] as String,
      qualityScore: (map['qualityScore'] as num).toDouble(),
      discountScore: (map['discountScore'] as num).toDouble(),
      marginOfSafety: (map['marginOfSafety'] as num).toDouble(),
    );
  }).toList();

  double sumSqQuality = 0, sumSqDiscount = 0, sumSqMos = 0;
  for (var t in tickers) {
    sumSqQuality += pow(t.qualityScore, 2);
    sumSqDiscount += pow(t.discountScore, 2);
    sumSqMos += pow(t.marginOfSafety, 2);
  }

  if (sumSqQuality == 0) sumSqQuality = 1;
  if (sumSqDiscount == 0) sumSqDiscount = 1;
  if (sumSqMos == 0) sumSqMos = 1;

  final weightedMatrix = tickers.map((t) {
    return {
      'symbol': t.symbol,
      'w_quality': (t.qualityScore / sqrt(sumSqQuality)) * (weights['quality'] ?? 0.0),
      'w_discount': (t.discountScore / sqrt(sumSqDiscount)) * (weights['discount'] ?? 0.0),
      'w_mos': (t.marginOfSafety / sqrt(sumSqMos)) * (weights['mos'] ?? 0.0),
    };
  }).toList();

  double vPlusQuality = weightedMatrix.map((e) => e['w_quality'] as double).reduce(max);
  double vMinusQuality = weightedMatrix.map((e) => e['w_quality'] as double).reduce(min);

  double vPlusDiscount = weightedMatrix.map((e) => e['w_discount'] as double).reduce(max);
  double vMinusDiscount = weightedMatrix.map((e) => e['w_discount'] as double).reduce(min);

  double vPlusMos = weightedMatrix.map((e) => e['w_mos'] as double).reduce(max);
  double vMinusMos = weightedMatrix.map((e) => e['w_mos'] as double).reduce(min);

  final finalRankings = <Map<String, dynamic>>[];

  for (var t in weightedMatrix) {
    final qV = t['w_quality'] as double;
    final dV = t['w_discount'] as double;
    final mV = t['w_mos'] as double;

    final sPlus = sqrt(
      pow(qV - vPlusQuality, 2) +
          pow(dV - vPlusDiscount, 2) +
          pow(mV - vPlusMos, 2),
    );

    final sMinus = sqrt(
      pow(qV - vMinusQuality, 2) +
          pow(dV - vMinusDiscount, 2) +
          pow(mV - vMinusMos, 2),
    );

    final denominator = sPlus + sMinus;
    final finalScore = denominator == 0 ? 0 : sMinus / denominator;
    final decision = finalScore > 0.65
        ? 'BUY'
        : (finalScore < 0.4 ? 'DO NOT BUY' : 'HOLD');

    finalRankings.add({
      'symbol': t['symbol'],
      'score': finalScore,
      'decision': decision,
    });
  }

  finalRankings.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  return finalRankings;
}

class WeightsNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    return {'quality': 0.5, 'discount': 0.3, 'mos': 0.2};
  }
}

final weightsProvider = NotifierProvider<WeightsNotifier, Map<String, double>>(() {
  return WeightsNotifier();
});

class TickerListNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void addTicker(String symbol) {
    if (symbol.isEmpty) return;
    if (state.contains(symbol)) return;
    state = [...state, symbol];
  }

  void removeTicker(String symbol) {
    state = state.where((item) => item != symbol).toList();
  }
}

final tickerListProvider = NotifierProvider<TickerListNotifier, List<String>>(() {
  return TickerListNotifier();
});

final yahooServiceProvider = Provider<YahooFinanceService>((ref) {
  return YahooFinanceService();
});

final tickerMetricsProvider = FutureProvider<List<TickerMetrics>>((ref) async {
  final symbols = ref.watch(tickerListProvider);
  if (symbols.isEmpty) return [];
  final service = ref.watch(yahooServiceProvider);
  Object? firstError;
  final futures = symbols.map((symbol) async {
    try {
      return await service.fetchMetrics(symbol);
    } catch (error) {
      firstError ??= error;
      return null;
    }
  }).toList();

  final results = await Future.wait(futures);
  final metrics = results.whereType<TickerMetrics>().toList();
  if (metrics.isEmpty) {
    if (firstError != null) {
      throw Exception(firstError.toString());
    }
    throw Exception('No ticker data could be loaded.');
  }
  return metrics;
});

final rankedTickersProvider = FutureProvider<List<ScoredTicker>>((ref) async {
  final weights = ref.watch(weightsProvider);
  final metrics = await ref.watch(tickerMetricsProvider.future);
  if (metrics.isEmpty) return [];

  final scored = metrics.map(_scoreFromMetrics).toList();
  final payload = scored
      .map((s) => TickerData(
            symbol: s.symbol,
            qualityScore: s.qualityScore,
            discountScore: s.discountScore,
            marginOfSafety: s.marginOfSafety,
          ))
      .toList();

  final rankings = await calculateTopsisDecision(payload, weights);
  final rankingMap = {
    for (final item in rankings) item['symbol'] as String: item,
  };

  final merged = scored.map((item) {
    final rank = rankingMap[item.symbol];
    if (rank == null) return item;
    return item.copyWith(
      topsisScore: rank['score'] as double,
      decision: rank['decision'] as String,
    );
  }).toList();

  merged.sort((a, b) => (b.topsisScore ?? 0).compareTo(a.topsisScore ?? 0));
  return merged;
});

ScoredTicker _scoreFromMetrics(TickerMetrics metrics) {
  final qualityScore = _scoreQuality(metrics);
  final discountScore = _scoreDiscount(metrics);
  final marginOfSafety = metrics.marginOfSafety ?? 0;

  return ScoredTicker(
    symbol: metrics.symbol,
    metrics: metrics,
    qualityScore: qualityScore,
    discountScore: discountScore,
    marginOfSafety: marginOfSafety,
  );
}

double _scoreQuality(TickerMetrics metrics) {
  final scores = <double>[];

  if (metrics.roe != null) {
    scores.add(_scaleScore(metrics.roe!, 20));
  }

  final avgCagr = _averageNonNull([
    metrics.cagrRevenue,
    metrics.cagrNetIncome,
    metrics.cagrEps,
  ]);
  if (avgCagr != null) {
    scores.add(_scaleScore(avgCagr, 15));
  }

  if (metrics.dividendYield != null) {
    scores.add(_scaleScore(metrics.dividendYield! * 100, 6));
  }

  if (metrics.pe != null) {
    scores.add(_inverseScore(metrics.pe!, 30));
  }

  if (metrics.pbv != null) {
    scores.add(_inverseScore(metrics.pbv!, 3));
  }

  if (scores.isEmpty) return 0;
  return scores.reduce((a, b) => a + b) / scores.length;
}

double _scoreDiscount(TickerMetrics metrics) {
  final avgDrop = _averageNonNull([
    metrics.dropDay,
    metrics.dropWeek,
    metrics.dropMonth,
  ]);
  if (avgDrop == null) return 0;

  final discount = avgDrop < 0 ? -avgDrop : 0.0;
  return _scaleScore(discount, 20);
}

double _scaleScore(double value, double target) {
  final score = (value / target) * 10;
  return score.clamp(0, 10).toDouble();
}

double _inverseScore(double value, double target) {
  if (value <= 0) return 0;
  final ratio = value / target;
  final score = (1 - ratio).clamp(0, 1) * 10;
  return score.toDouble();
}

double? _averageNonNull(List<double?> values) {
  final filtered = values.whereType<double>().toList();
  if (filtered.isEmpty) return null;
  final sum = filtered.reduce((a, b) => a + b);
  return sum / filtered.length;
}

String normalizeSymbol(String input, bool useJakartaSuffix) {
  final trimmed = input.trim().toUpperCase();
  if (trimmed.isEmpty) return '';
  if (useJakartaSuffix && !trimmed.contains('.')) {
    return '$trimmed.JK';
  }
  return trimmed;
}

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A6E5A)),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Tick Watchers',
      theme: base.copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme),
        appBarTheme: const AppBarTheme(centerTitle: false),
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _useJakartaSuffix = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTicker() {
    final normalized = normalizeSymbol(_controller.text, _useJakartaSuffix);
    if (normalized.isEmpty) return;
    ref.read(tickerListProvider.notifier).addTicker(normalized);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final tickers = ref.watch(tickerListProvider);
    final rankingAsync = ref.watch(rankedTickersProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F7F5), Color(0xFFE7F2EE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tick Watchers',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0B3B2E),
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Beginner-friendly decision support for smart investing',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF3B5A52),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Weights settings coming soon.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _TickerInputCard(
                  controller: _controller,
                  useJakartaSuffix: _useJakartaSuffix,
                  onSuffixChanged: (value) {
                    setState(() => _useJakartaSuffix = value);
                  },
                  onSubmit: _addTicker,
                ),
              ),
              if (tickers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ticker in tickers)
                          InputChip(
                            label: Text(ticker),
                            onDeleted: () => ref.read(tickerListProvider.notifier).removeTicker(ticker),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: rankingAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => _ErrorState(message: err.toString()),
                  data: (rankings) {
                    if (rankings.isEmpty) {
                      return const _EmptyState();
                    }
                    return _RankingTabs(rankings: rankings);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickerInputCard extends StatelessWidget {
  final TextEditingController controller;
  final bool useJakartaSuffix;
  final ValueChanged<bool> onSuffixChanged;
  final VoidCallback onSubmit;

  const _TickerInputCard({
    required this.controller,
    required this.useJakartaSuffix,
    required this.onSuffixChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Ticker',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B3B2E),
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'BBCA or AAPL',
                    filled: true,
                    fillColor: const Color(0xFFF3F7F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFF0A6E5A),
                  foregroundColor: Colors.white,
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: useJakartaSuffix,
                onChanged: onSuffixChanged,
                activeThumbColor: const Color(0xFF0A6E5A),
              ),
              const SizedBox(width: 8),
              Text(
                'Append .JK for IDX tickers',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF3B5A52),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankingTabs extends StatelessWidget {
  final List<ScoredTicker> rankings;

  const _RankingTabs({required this.rankings});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              labelColor: const Color(0xFF0B3B2E),
              unselectedLabelColor: const Color(0xFF5B6F69),
              indicatorColor: const Color(0xFF0A6E5A),
              tabs: const [
                Tab(text: 'Overall'),
                Tab(text: 'Margin of Safety'),
                Tab(text: 'Quality'),
                Tab(text: 'Discount'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _RankingList(items: rankings),
                _RankingList(items: _sortedByMos(rankings)),
                _RankingList(items: _sortedByQuality(rankings)),
                _RankingList(items: _sortedByDiscount(rankings)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<ScoredTicker> _sortedByMos(List<ScoredTicker> items) {
    final list = [...items];
    list.sort((a, b) => b.marginOfSafety.compareTo(a.marginOfSafety));
    return list;
  }

  List<ScoredTicker> _sortedByQuality(List<ScoredTicker> items) {
    final list = [...items];
    list.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    return list;
  }

  List<ScoredTicker> _sortedByDiscount(List<ScoredTicker> items) {
    final list = [...items];
    list.sort((a, b) => b.discountScore.compareTo(a.discountScore));
    return list;
  }
}

class _RankingList extends StatelessWidget {
  final List<ScoredTicker> items;

  const _RankingList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _TickerCard(item: items[index]);
      },
    );
  }
}

class _TickerCard extends StatelessWidget {
  final ScoredTicker item;

  const _TickerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final decision = item.decision ?? 'HOLD';
    final decisionColor = _decisionColor(decision);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE7F2EE),
                child: Text(
                  item.symbol.substring(0, 1),
                  style: const TextStyle(color: Color(0xFF0B3B2E)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.symbol,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0B3B2E),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Price: ${_formatValue(item.metrics.currentPrice)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5B6F69),
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: decisionColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  decision,
                  style: TextStyle(
                    color: decisionColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(label: 'TOPSIS', value: _formatPercent(item.topsisScore, scale: 100)),
              _MetricChip(label: 'MOS', value: _formatPercentValue(item.metrics.marginOfSafety)),
              _MetricChip(label: 'ROE', value: _formatPercentValue(item.metrics.roe)),
              _MetricChip(label: 'PER', value: _formatValue(item.metrics.pe)),
              _MetricChip(label: 'PBV', value: _formatValue(item.metrics.pbv)),
              _MetricChip(label: 'Div Yield', value: _formatPercentValue(item.metrics.dividendYield, ratio: true)),
              _MetricChip(label: 'CAGR Rev', value: _formatPercentValue(item.metrics.cagrRevenue)),
              _MetricChip(label: 'CAGR EPS', value: _formatPercentValue(item.metrics.cagrEps)),
              _MetricChip(label: 'Drop M/W/D', value: _formatDropSummary(item.metrics)),
            ],
          ),
        ],
      ),
    );
  }

  Color _decisionColor(String decision) {
    switch (decision) {
      case 'BUY':
        return const Color(0xFF1B7F5A);
      case 'DO NOT BUY':
        return const Color(0xFFC4412E);
      default:
        return const Color(0xFFB0781A);
    }
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF5B6F69),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B3B2E),
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stacked_line_chart, size: 48, color: Color(0xFF0A6E5A)),
            const SizedBox(height: 12),
            Text(
              'Start by adding a ticker symbol',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0B3B2E),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We will fetch live fundamentals and compute the Fuzzy AHP-TOPSIS decision automatically.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5B6F69),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFC4412E)),
            const SizedBox(height: 12),
            Text(
              'Unable to load data',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5B6F69),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatValue(double? value) {
  if (value == null) return 'N/A';
  return value.toStringAsFixed(2);
}

String _formatPercent(double? value, {double scale = 1}) {
  if (value == null) return 'N/A';
  return '${(value * scale).toStringAsFixed(1)}%';
}

String _formatPercentValue(double? value, {bool ratio = false}) {
  if (value == null) return 'N/A';
  final actual = ratio ? value * 100 : value;
  return '${actual.toStringAsFixed(1)}%';
}

String _formatDropSummary(TickerMetrics metrics) {
  final day = _formatSignedPercent(metrics.dropDay);
  final week = _formatSignedPercent(metrics.dropWeek);
  final month = _formatSignedPercent(metrics.dropMonth);
  return '$month / $week / $day';
}

String _formatSignedPercent(double? value) {
  if (value == null) return 'N/A';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}%';
}
