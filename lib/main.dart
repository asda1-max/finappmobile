import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/formatters.dart';
import 'models/stock_data.dart';
import 'data/stock_repository.dart';
import 'widgets/glassmorphic_card.dart';
import 'widgets/score_badge.dart';
import 'screens/ranking_screen.dart';
import 'screens/stock_detail_screen.dart';
import 'screens/settings_screen.dart';

// ── Providers ──

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository();
});

class TickerListNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void addTicker(String symbol) {
    if (symbol.isEmpty || state.contains(symbol)) return;
    state = [...state, symbol];
  }

  void removeTicker(String symbol) {
    state = state.where((item) => item != symbol).toList();
  }
}

final tickerListProvider =
    NotifierProvider<TickerListNotifier, List<String>>(TickerListNotifier.new);

final stockDataProvider = FutureProvider<List<StockData>>((ref) async {
  final symbols = ref.watch(tickerListProvider);
  if (symbols.isEmpty) return [];
  final repo = ref.watch(stockRepositoryProvider);
  return repo.fetchStocks(symbols);
});

String normalizeSymbol(String input, bool useJakartaSuffix) {
  final trimmed = input.trim().toUpperCase();
  if (trimmed.isEmpty) return '';
  if (useJakartaSuffix && !trimmed.contains('.')) return '$trimmed.JK';
  return trimmed;
}

// ── App ──

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tick Watchers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppShell(),
    );
  }
}

// ── App Shell with Bottom Navigation ──

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final stocksAsync = ref.watch(stockDataProvider);
    final stocks = stocksAsync.value ?? [];

    final screens = [
      const DashboardScreen(),
      RankingScreen(stocks: stocks),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 64,
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          indicatorColor: AppColors.primary.withValues(alpha: 0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon:
                  Icon(Icons.dashboard_rounded, color: AppColors.textMuted),
              selectedIcon:
                  Icon(Icons.dashboard_rounded, color: AppColors.primary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.leaderboard_rounded,
                  color: AppColors.textMuted),
              selectedIcon: Icon(Icons.leaderboard_rounded,
                  color: AppColors.primary),
              label: 'Rankings',
            ),
            NavigationDestination(
              icon:
                  Icon(Icons.settings_rounded, color: AppColors.textMuted),
              selectedIcon:
                  Icon(Icons.settings_rounded, color: AppColors.primary),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard Screen ──

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _useJakartaSuffix = true;
  bool _isAdding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addTicker() async {
    final normalized = normalizeSymbol(_controller.text, _useJakartaSuffix);
    if (normalized.isEmpty) return;
    setState(() => _isAdding = true);
    ref.read(tickerListProvider.notifier).addTicker(normalized);
    _controller.clear();
    FocusScope.of(context).unfocus();
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final stocksAsync = ref.watch(stockDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(stockDataProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        child: const Text(
                          'Tick Watchers',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Decision Making Support System',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Ticker Input
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  hintText: 'Enter ticker (e.g. BBCA)',
                                  hintStyle:
                                      TextStyle(color: AppColors.textMuted),
                                  prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                      color: AppColors.textMuted),
                                  suffixText:
                                      _useJakartaSuffix ? '.JK' : null,
                                  suffixStyle: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                onSubmitted: (_) => _addTicker(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 42,
                              child: ElevatedButton(
                                onPressed: _isAdding ? null : _addTicker,
                                child: _isAdding
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Fetch',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        )),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Switch(
                              value: _useJakartaSuffix,
                              onChanged: (v) =>
                                  setState(() => _useJakartaSuffix = v),
                              activeTrackColor: AppColors.primary,
                            ),
                            Text(
                              'Append .JK for IDX',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Label
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    'PORTFOLIO OVERVIEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              // Stock Cards
              stocksAsync.when(
                data: (stocks) {
                  if (stocks.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_chart_rounded,
                                size: 56, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No stocks yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter a ticker above to start tracking',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final stock = stocks[index];
                          return _StockCard(
                            stock: stock,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StockDetailScreen(stock: stock),
                                ),
                              );
                            },
                          );
                        },
                        childCount: stocks.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  ),
                ),
                error: (error, _) => SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 48, color: AppColors.sellRed),
                          const SizedBox(height: 12),
                          Text(
                            'Connection Error',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Make sure the FastAPI backend is running.\n$error',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.invalidate(stockDataProvider);
                            },
                            icon: const Icon(Icons.refresh_rounded,
                                size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stock Card ──

class _StockCard extends StatelessWidget {
  final StockData stock;
  final VoidCallback? onTap;
  const _StockCard({required this.stock, this.onTap});

  @override
  Widget build(BuildContext context) {
    final decision = stock.effectiveDecision;

    final category = stock.effectiveCategory;

    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  stock.ticker.isNotEmpty ? stock.ticker[0] : '?',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.ticker,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (stock.name.isNotEmpty)
                      Text(
                        stock.name,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ScoreBadge.decision(decision),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price + Quality
          Row(
            children: [
              Text(
                Formatters.price(stock.price),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              ScoreBadge.quality(stock.qualityLabel),
            ],
          ),
          const SizedBox(height: 10),

          // Hybrid Score bar
          if (stock.effectiveHybridScore > 0) ...[
            Row(
              children: [
                Text('Hybrid Score',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
                const Spacer(),
                Text(
                  Formatters.score(stock.effectiveHybridScore),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.scoreColor(
                        stock.effectiveHybridScore),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stock.effectiveHybridScore.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.surfaceLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.scoreColor(stock.effectiveHybridScore)),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Metric chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniMetric(
                  'MOS', Formatters.percent(stock.mos)),
              _MiniMetric(
                  'ROE', Formatters.percent(stock.roe)),
              _MiniMetric('PER', Formatters.ratio(stock.perNow)),
              _MiniMetric('PBV', Formatters.ratio(stock.pbv)),
              _MiniMetric(
                  'Div', Formatters.percent(stock.dividendYieldPercent)),
              _MiniMetric('Disc',
                  Formatters.score(stock.discountScore)),
            ],
          ),

          // Verdicts
          if (stock.qualityVerdict != null ||
              stock.discountTimingVerdict != null) ...[
            const SizedBox(height: 10),
            if (stock.discountTimingVerdict != null)
              Row(
                children: [
                  Icon(Icons.timer_rounded,
                      size: 12, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      stock.discountTimingVerdict!,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.accentLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MiniMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
