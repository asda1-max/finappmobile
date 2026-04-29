import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/stock_data.dart';
import '../widgets/score_badge.dart';
import 'stock_detail_screen.dart';

/// Ranking criteria for the tab bar.
enum RankingCriteria {
  hybridScore('Best Overall', Icons.star_rounded),
  mos('Most Undervalued', Icons.trending_down_rounded),
  qualityScore('Quality Leaders', Icons.workspace_premium_rounded),
  discountScore('Best Discount', Icons.local_offer_rounded),
  dividendYield('Highest Yield', Icons.payments_rounded);

  final String label;
  final IconData icon;
  const RankingCriteria(this.label, this.icon);
}

/// Screen with tabs for ranking saved tickers by different criteria.
class RankingScreen extends ConsumerStatefulWidget {
  final List<StockData> stocks;
  const RankingScreen({super.key, required this.stocks});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: RankingCriteria.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<StockData> _sortByCriteria(
      List<StockData> stocks, RankingCriteria criteria) {
    final sorted = List<StockData>.from(stocks);
    switch (criteria) {
      case RankingCriteria.hybridScore:
        sorted.sort((a, b) =>
            b.displayHybridScore.compareTo(a.displayHybridScore));
      case RankingCriteria.mos:
        sorted.sort((a, b) => b.mos.compareTo(a.mos));
      case RankingCriteria.qualityScore:
        sorted.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
      case RankingCriteria.discountScore:
        sorted.sort((a, b) => b.discountScore.compareTo(a.discountScore));
      case RankingCriteria.dividendYield:
        sorted.sort(
            (a, b) => b.dividendYieldPercent.compareTo(a.dividendYieldPercent));
    }
    return sorted;
  }

  String _criteriaValue(StockData stock, RankingCriteria criteria) {
    switch (criteria) {
      case RankingCriteria.hybridScore:
        return Formatters.score(stock.displayHybridScore);
      case RankingCriteria.mos:
        return Formatters.percent(stock.mos);
      case RankingCriteria.qualityScore:
        return Formatters.score(stock.qualityScore);
      case RankingCriteria.discountScore:
        return Formatters.score(stock.discountScore);
      case RankingCriteria.dividendYield:
        return Formatters.percent(stock.dividendYieldPercent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stocks = widget.stocks;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        child: const Text(
                          'Rankings',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compare and rank your saved tickers',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Tab Bar ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: RankingCriteria.values.map((c) {
                  return Tab(
                    height: 38,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.icon, size: 14),
                        const SizedBox(width: 4),
                        Text(c.label),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // ── Tab Content ──
            Expanded(
              child: stocks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.leaderboard_rounded,
                              size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No stocks to rank',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add tickers from the Dashboard first',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: RankingCriteria.values.map((criteria) {
                        final ranked = _sortByCriteria(stocks, criteria);
                        return ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: ranked.length,
                          itemBuilder: (context, index) {
                            final stock = ranked[index];
                            return _RankedTickerRow(
                              rank: index + 1,
                              stock: stock,
                              criteriaValue:
                                  _criteriaValue(stock, criteria),
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
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single row in the ranking list.
class _RankedTickerRow extends StatelessWidget {
  final int rank;
  final StockData stock;
  final String criteriaValue;
  final VoidCallback? onTap;

  const _RankedTickerRow({
    required this.rank,
    required this.stock,
    required this.criteriaValue,
    this.onTap,
  });

  String get _rankEmoji {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = stock.effectiveDecision;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: rank <= 3
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: rank <= 3
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 36,
              child: _rankEmoji.isNotEmpty
                  ? Text(_rankEmoji, style: const TextStyle(fontSize: 18))
                  : Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),

            // Ticker + Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.ticker,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
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

            // Score value
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                criteriaValue,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),

            // Decision badge
            ScoreBadge.decision(decision),
          ],
        ),
      ),
    );
  }
}
