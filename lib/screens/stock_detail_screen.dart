import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/stock_data.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/score_badge.dart';

/// Detailed view of a single stock with full fundamental breakdown.
class StockDetailScreen extends StatelessWidget {
  final StockData stock;
  const StockDetailScreen({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            pinned: true,
            title: Text(stock.ticker),
            actions: [
              ScoreBadge.decision(stock.effectiveDecision),
              const SizedBox(width: 16),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HeroHeader(stock: stock),
                const SizedBox(height: 16),
                // Decision gauge
                GlassmorphicCard(
                  child: Column(
                    children: [
                      const Text(
                        'FUZZY AHP-TOPSIS DECISION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DecisionGauge(
                        score: stock.effectiveHybridScore,
                        decision: stock.effectiveDecision,
                        category: stock.effectiveCategory,
                      ),
                      if (stock.safetyCheck != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.holdAmberBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppColors.holdAmber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.shield_rounded,
                                  size: 14, color: AppColors.holdAmber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  stock.safetyCheck!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.holdAmberLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Fundamentals
                _SectionTitle(title: 'FUNDAMENTALS'),
                const SizedBox(height: 8),
                _FundamentalsGrid(stock: stock),
                const SizedBox(height: 16),
                // Scoring
                _SectionTitle(title: 'SCORING'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ScoreCard(
                        title: 'Quality Score',
                        score: stock.qualityScore,
                        label: stock.qualityLabel,
                        labelColor:
                            AppColors.qualityColor(stock.qualityLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ScoreCard(
                        title: 'Discount Score',
                        score: stock.discountScore,
                        label: stock.decisionDiscount,
                        labelColor:
                            AppColors.scoreColor(stock.discountScore),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Dividend
                if (stock.dividendYieldPercent > 0) ...[
                  _SectionTitle(title: 'DIVIDEND'),
                  const SizedBox(height: 8),
                  GlassmorphicCard(
                    child: Column(
                      children: [
                        _DetailRow('Dividend Yield',
                            Formatters.percent(stock.dividendYieldPercent)),
                        _DetailRow('Dividend Growth',
                            Formatters.signedPercent(stock.dividendGrowth)),
                        _DetailRow('Payout Ratio',
                            Formatters.percent(stock.payoutRatio)),
                        _DetailRow(
                            'Dividend Status', stock.decisionDividend),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // CAGR
                if (stock.cagrApplied == true) ...[
                  _SectionTitle(title: 'CAGR (Growth Metrics)'),
                  const SizedBox(height: 8),
                  GlassmorphicCard(
                    child: Column(
                      children: [
                        _DetailRow('Net Income CAGR',
                            Formatters.signedPercent(stock.cagrNetIncomeUsed)),
                        _DetailRow('Revenue CAGR',
                            Formatters.signedPercent(stock.cagrRevenueUsed)),
                        _DetailRow('EPS CAGR',
                            Formatters.signedPercent(stock.cagrEpsUsed)),
                        _DetailRow('Source', stock.cagrSource ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Price Momentum
                _SectionTitle(title: 'PRICE MOMENTUM'),
                const SizedBox(height: 8),
                GlassmorphicCard(
                  child: Column(
                    children: [
                      _PriceDropIndicator(
                        downMonth: stock.downFromMonth,
                        downWeek: stock.downFromWeek,
                        downToday: stock.downFromToday,
                      ),
                      const SizedBox(height: 10),
                      _DetailRow('Down from 52W High',
                          Formatters.percent(stock.downFromHigh)),
                      _DetailRow('Rise from 52W Low',
                          Formatters.percent(stock.riseFromLow)),
                      if (stock.discountTimingVerdict != null)
                        _DetailRow(
                            'Timing Verdict', stock.discountTimingVerdict!),
                    ],
                  ),
                ),
                // Quality & Timing Verdicts
                if (stock.qualityVerdict != null ||
                    stock.discountTimingVerdict != null) ...[
                  const SizedBox(height: 16),
                  _SectionTitle(title: 'VERDICTS'),
                  const SizedBox(height: 8),
                  GlassmorphicCard(
                    child: Column(
                      children: [
                        if (stock.qualityVerdict != null)
                          _DetailRow('Quality', stock.qualityVerdict!),
                        if (stock.executionDecision != null)
                          _DetailRow(
                              'Execution', stock.executionDecision!),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Header ──
class _HeroHeader extends StatelessWidget {
  final StockData stock;
  const _HeroHeader({required this.stock});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stock.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ScoreBadge(label: stock.sector, color: AppColors.primary),
              const SizedBox(width: 6),
              if (stock.qualityVerdict != null)
                ScoreBadge.quality(stock.qualityLabel),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Formatters.price(stock.price),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          _WeekRangeBar(
            low: stock.low52,
            high: stock.high52,
            current: stock.price,
          ),
        ],
      ),
    );
  }
}

class _WeekRangeBar extends StatelessWidget {
  final double low, high, current;
  const _WeekRangeBar(
      {required this.low, required this.high, required this.current});

  @override
  Widget build(BuildContext context) {
    final range = high - low;
    final position =
        range > 0 ? ((current - low) / range).clamp(0.0, 1.0) : 0.5;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('52W Low: ${Formatters.price(low)}',
                style:
                    TextStyle(fontSize: 10, color: AppColors.textTertiary)),
            Text('52W High: ${Formatters.price(high)}',
                style:
                    TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.buyGreen,
                          AppColors.holdAmber,
                          AppColors.sellRed,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Positioned(
                    left: position * (constraints.maxWidth - 8),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Decision Gauge ──
class _DecisionGauge extends StatelessWidget {
  final double score;
  final String decision;
  final String category;
  const _DecisionGauge({
    required this.score,
    required this.decision,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0.0, 1.0);
    final decisionColor = AppColors.decisionColor(decision);

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: clampedScore,
                  strokeWidth: 10,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(decisionColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Formatters.score(clampedScore),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: decisionColor,
                    ),
                  ),
                  Text(
                    decision,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: decisionColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ScoreBadge.category(category),
      ],
    );
  }
}

// ── Fundamentals Grid ──
class _FundamentalsGrid extends StatelessWidget {
  final StockData stock;
  const _FundamentalsGrid({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FundamentalTile(label: 'EPS', value: stock.epsNow.toStringAsFixed(2)),
        _FundamentalTile(label: 'PER', value: Formatters.ratio(stock.perNow)),
        _FundamentalTile(
            label: 'BVPS', value: Formatters.price(stock.bvpPerShare)),
        _FundamentalTile(label: 'ROE', value: Formatters.percent(stock.roe)),
        _FundamentalTile(label: 'PBV', value: Formatters.ratio(stock.pbv)),
        _FundamentalTile(
            label: 'Graham #', value: Formatters.price(stock.grahamNumber)),
        _FundamentalTile(label: 'MOS', value: Formatters.percent(stock.mos)),
        _FundamentalTile(
            label: 'Mkt Cap', value: Formatters.compact(stock.marketCap)),
        if (stock.netProfitMargin != null)
          _FundamentalTile(
              label: 'NPM',
              value: Formatters.percent(stock.netProfitMargin)),
        if (stock.debtToEquity != null)
          _FundamentalTile(
              label: 'D/E',
              value:
                  '${(stock.debtToEquity! / 100).toStringAsFixed(2)}x'),
        if (stock.currentRatio != null)
          _FundamentalTile(
              label: 'Curr Ratio',
              value: stock.currentRatio!.toStringAsFixed(2)),
      ],
    );
  }
}

class _FundamentalTile extends StatelessWidget {
  final String label;
  final String value;
  const _FundamentalTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 3,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String title;
  final double score;
  final String label;
  final Color labelColor;
  const _ScoreCard({
    required this.title,
    required this.score,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.score(score),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 4),
          ScoreBadge(label: label, color: labelColor),
        ],
      ),
    );
  }
}

class _PriceDropIndicator extends StatelessWidget {
  final double downMonth;
  final double downWeek;
  final double downToday;
  const _PriceDropIndicator({
    required this.downMonth,
    required this.downWeek,
    required this.downToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _DropChip(label: 'Month', value: downMonth)),
        const SizedBox(width: 6),
        Expanded(child: _DropChip(label: 'Week', value: downWeek)),
        const SizedBox(width: 6),
        Expanded(child: _DropChip(label: 'Today', value: downToday)),
      ],
    );
  }
}

class _DropChip extends StatelessWidget {
  final String label;
  final double value;
  const _DropChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDown = value > 0;
    final color = isDown ? AppColors.buyGreen : AppColors.sellRed;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            Formatters.dropPercent(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.5,
      ),
    );
  }
}
