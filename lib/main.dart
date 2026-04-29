import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/formatters.dart';
import 'core/api_client.dart';
import 'core/services/session_service.dart';
import 'core/services/local_db_service.dart';
import 'models/stock_data.dart';
import 'data/stock_repository.dart';
import 'widgets/glassmorphic_card.dart';
import 'widgets/score_badge.dart';
import 'screens/login_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/stock_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/utilities_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/logout_screen.dart';

// ── Providers ──

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository();
});

class TickerListNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => LocalDbService.getSavedTickers();

  void addTicker(String symbol) {
    if (symbol.isEmpty || state.contains(symbol)) return;
    state = [...state, symbol];
    LocalDbService.saveTickers(state);
  }

  void removeTicker(String symbol) {
    state = state.where((item) => item != symbol).toList();
    LocalDbService.saveTickers(state);
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive local database
  await LocalDbService.init();

  // Restore JWT session if exists
  final savedToken = await SessionService.getToken();
  if (savedToken != null && savedToken.isNotEmpty) {
    ApiClient.setAuthToken(savedToken);
  }

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
      home: const AuthGate(),
    );
  }
}

// ── Auth Gate — routes to Login or AppShell based on session ──

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final isLoggedIn = await SessionService.isLoggedIn();
    setState(() {
      _loggedIn = isLoggedIn;
      _checking = false;
    });
  }

  void _onLoginSuccess() {
    setState(() => _loggedIn = true);
  }

  void _onLogout() async {
    await SessionService.clearSession();
    ApiClient.setAuthToken(null);
    setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (!_loggedIn) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    return AppShell(onLogout: _onLogout);
  }
}

// ── App Shell with Bottom Navigation (4 tabs) ──

class AppShell extends ConsumerStatefulWidget {
  final VoidCallback onLogout;
  const AppShell({super.key, required this.onLogout});

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
      const UtilitiesScreen(),
      const ProfileScreen(),
      const FeedbackScreen(),
      const SettingsScreen(),
      LogoutScreen(onLogout: widget.onLogout),
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
              icon: Icon(Icons.currency_exchange_rounded,
                  color: AppColors.textMuted),
              selectedIcon: Icon(Icons.currency_exchange_rounded,
                  color: AppColors.primary),
              label: 'Utilities',
            ),
            NavigationDestination(
              icon:
                  Icon(Icons.person_rounded, color: AppColors.textMuted),
              selectedIcon:
                  Icon(Icons.person_rounded, color: AppColors.primary),
              label: 'Profil',
            ),
            NavigationDestination(
              icon:
                  Icon(Icons.feedback_rounded, color: AppColors.textMuted),
              selectedIcon:
                  Icon(Icons.feedback_rounded, color: AppColors.primary),
              label: 'Saran & Kesan',
            ),
            NavigationDestination(
              icon:
                  Icon(Icons.settings_rounded, color: AppColors.textMuted),
              selectedIcon:
                  Icon(Icons.settings_rounded, color: AppColors.primary),
              label: 'Settings',
            ),
            NavigationDestination(
              icon: Icon(Icons.logout_rounded, color: AppColors.textMuted),
              selectedIcon:
                  Icon(Icons.logout_rounded, color: AppColors.primary),
              label: 'Logout',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings Screen Wrapper with Logout ──

class SettingsScreenWithLogout extends StatelessWidget {
  final VoidCallback onLogout;
  const SettingsScreenWithLogout({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: const SettingsScreen()),
            // Logout button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Logout'),
                        content:
                            const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Logout',
                                style:
                                    TextStyle(color: AppColors.sellRed)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await SessionService.setBiometricEnabled(false);
                      onLogout();
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.sellRed,
                    side: BorderSide(
                        color: AppColors.sellRed.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
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
  final TextEditingController _searchController = TextEditingController();
  bool _useJakartaSuffix = true;
  bool _isAdding = false;
  String _searchQuery = '';
  String? _lastAlertKey;

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addTicker() async {
    final normalized = normalizeSymbol(_controller.text, _useJakartaSuffix);
    if (normalized.isEmpty) return;
    setState(() => _isAdding = true);
    ref.read(tickerListProvider.notifier).addTicker(normalized);
    // Save to search history
    await LocalDbService.addSearchHistory(normalized);
    _controller.clear();
    FocusScope.of(context).unfocus();
    setState(() => _isAdding = false);
  }

  void _maybeNotify(List<StockData> stocks) {
    if (!mounted) return;
    final enabled =
        LocalDbService.getPreference<bool>('alert_enabled') ?? false;
    final tickerPref =
        (LocalDbService.getPreference<String>('alert_ticker') ?? '')
            .toUpperCase();
    final threshold =
        (LocalDbService.getPreference<num>('alert_threshold') ?? 5.0)
            .toDouble();
    if (!enabled || tickerPref.isEmpty) return;

    final stock = stocks.firstWhere(
      (s) => s.ticker.toUpperCase() == tickerPref,
      orElse: () => const StockData(
        ticker: '',
        name: '',
        sector: '',
        industry: '',
        price: 0,
        revenueAnnual: 0,
        epsNow: 0,
        perNow: 0,
        high52: 0,
        low52: 0,
        shares: 0,
        marketCap: 0,
        downFromHigh: 0,
        downFromMonth: 0,
        downFromWeek: 0,
        downFromToday: 0,
        riseFromLow: 0,
        bvpPerShare: 0,
        roe: 0,
        grahamNumber: 0,
        mos: 0,
        freeCashflow: 0,
        pbv: 0,
        qualityScore: 0,
        qualityLabel: '-',
        decisionBuy: 'NO BUY',
        decisionDiscount: '-',
        discountScore: 0,
        decisionDividend: '-',
        isRateLimited: false,
      ),
    );

    if (stock.ticker.isEmpty) return;

    final changeUp = -stock.downFromToday;
    if (changeUp < threshold) return;

    final key =
        '${stock.ticker}:${changeUp.toStringAsFixed(2)}:$threshold';
    if (_lastAlertKey == key) return;
    _lastAlertKey = key;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${stock.ticker} naik ${changeUp.toStringAsFixed(2)}% (>= $threshold%)',
        ),
        backgroundColor: AppColors.buyGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<StockData>>>(
      stockDataProvider,
      (previous, next) {
        next.whenData(_maybeNotify);
      },
    );
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

              // Search Portfolio
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      hintText: 'Cari ticker / nama perusahaan',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),

              // Stock Cards
              stocksAsync.when(
                data: (stocks) {
                  final query = _searchQuery.trim().toUpperCase();
                  final filtered = query.isEmpty
                      ? stocks
                      : stocks
                          .where((stock) =>
                              stock.ticker.toUpperCase().contains(query) ||
                              stock.name.toUpperCase().contains(query))
                          .toList();

                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_chart_rounded,
                                size: 56, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              query.isEmpty
                                  ? 'No stocks yet'
                                  : 'Tidak ada hasil pencarian',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              query.isEmpty
                                  ? 'Enter a ticker above to start tracking'
                                  : 'Coba kata kunci lain',
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
                          final stock = filtered[index];
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
                        childCount: filtered.length,
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
              _MiniMetric('MOS', Formatters.percent(stock.mos)),
              _MiniMetric('ROE', Formatters.percent(stock.roe)),
              _MiniMetric('PER', Formatters.ratio(stock.perNow)),
              _MiniMetric('PBV', Formatters.ratio(stock.pbv)),
              _MiniMetric(
                  'Div', Formatters.percent(stock.dividendYieldPercent)),
              _MiniMetric('Disc', Formatters.score(stock.discountScore)),
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
