import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glassmorphic_card.dart';
import '../main.dart';
import '../models/stock_data.dart';

/// Slot symbols ordered from best (7) to worst (cherry).
enum SlotSymbol {
  seven('7️⃣', 'Lucky 7', Color(0xFFFFD700), 6),
  diamond('💎', 'Diamond', Color(0xFFB388FF), 5),
  star('⭐', 'Star', Color(0xFFFFC107), 4),
  bell('🔔', 'Bell', Color(0xFFFF9800), 3),
  lemon('🍋', 'Lemon', Color(0xFFCDDC39), 2),
  grape('🍇', 'Grape', Color(0xFF9C27B0), 1),
  cherry('🍒', 'Cherry', Color(0xFFE53935), 0);

  final String emoji;
  final String label;
  final Color color;
  final int rank; // higher = better
  const SlotSymbol(this.emoji, this.label, this.color, this.rank);
}

class SlotMachineScreen extends ConsumerStatefulWidget {
  const SlotMachineScreen({super.key});

  @override
  ConsumerState<SlotMachineScreen> createState() => _SlotMachineScreenState();
}

class _SlotMachineScreenState extends ConsumerState<SlotMachineScreen>
    with TickerProviderStateMixin {
  final _rng = Random();

  // Reel state
  List<SlotSymbol> _reels = [SlotSymbol.seven, SlotSymbol.seven, SlotSymbol.seven];
  bool _spinning = false;
  int _coins = 100;
  int _totalWins = 0;

  // Animation
  late AnimationController _pulseController;
  late AnimationController _glowController;
  final List<AnimationController> _reelControllers = [];
  final List<Animation<double>> _reelAnimations = [];

  // Result
  String? _resultTicker;
  String? _resultMessage;
  Color _resultColor = AppColors.textSecondary;
  bool _isJackpot = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    for (int i = 0; i < 3; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + i * 400),
      );
      _reelControllers.add(ctrl);
      _reelAnimations.add(
        CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    for (final c in _reelControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Map the total reel score (0–18) to a stock index.
  /// 18 = best stock (#1), 0 = worst stock (last).
  StockData? _pickStock(int totalScore, List<StockData> stocks) {
    if (stocks.isEmpty) return null;
    final sorted = List<StockData>.from(stocks)
      ..sort((a, b) => b.displayHybridScore.compareTo(a.displayHybridScore));

    // Map 0..18 => last..first
    final maxScore = 18;
    final ratio = totalScore / maxScore; // 0.0 .. 1.0
    final idx = ((1.0 - ratio) * (sorted.length - 1)).round();
    return sorted[idx.clamp(0, sorted.length - 1)];
  }

  String _getResultTier(int totalScore) {
    if (totalScore >= 18) return '🎰 JACKPOT! Triple 7!';
    if (totalScore >= 15) return '💎 EPIC WIN!';
    if (totalScore >= 12) return '⭐ Great Spin!';
    if (totalScore >= 8) return '🔔 Nice!';
    if (totalScore >= 4) return '🍋 Okay...';
    return '🍒 Better luck next time!';
  }

  Color _getResultColor(int totalScore) {
    if (totalScore >= 18) return const Color(0xFFFFD700);
    if (totalScore >= 15) return const Color(0xFFB388FF);
    if (totalScore >= 12) return const Color(0xFFFFC107);
    if (totalScore >= 8) return const Color(0xFFFF9800);
    if (totalScore >= 4) return const Color(0xFFCDDC39);
    return const Color(0xFFE53935);
  }

  int _getCoinsWon(int totalScore) {
    if (totalScore >= 18) return 500;
    if (totalScore >= 15) return 100;
    if (totalScore >= 12) return 50;
    if (totalScore >= 8) return 20;
    if (totalScore >= 4) return 5;
    return 0;
  }


  Future<void> _spin() async {
    if (_spinning) return;
    if (_coins < 10) {
      setState(() {
        _resultMessage = '💸 Koin habis! Reset untuk main lagi.';
        _resultColor = AppColors.sellRed;
        _resultTicker = null;
      });
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _spinning = true;
      _coins -= 10;
      _resultTicker = null;
      _resultMessage = null;
      _isJackpot = false;
    });

    // Animate reels spinning
    for (final c in _reelControllers) {
      c.reset();
    }

    // Roll results
    final results = <SlotSymbol>[];
    for (int i = 0; i < 3; i++) {
      // Weighted random — 7 is rarer
      final roll = _rng.nextDouble();
      SlotSymbol sym;
      if (roll < 0.03) {
        sym = SlotSymbol.seven;
      } else if (roll < 0.10) {
        sym = SlotSymbol.diamond;
      } else if (roll < 0.22) {
        sym = SlotSymbol.star;
      } else if (roll < 0.40) {
        sym = SlotSymbol.bell;
      } else if (roll < 0.60) {
        sym = SlotSymbol.lemon;
      } else if (roll < 0.80) {
        sym = SlotSymbol.grape;
      } else {
        sym = SlotSymbol.cherry;
      }
      results.add(sym);
    }

    // Stagger reel stops
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: 200 + i * 300));
      _reelControllers[i].forward();
      setState(() => _reels[i] = results[i]);
      HapticFeedback.lightImpact();
    }

    await Future.delayed(const Duration(milliseconds: 400));

    // Calculate result
    final totalScore = results.fold<int>(0, (s, r) => s + r.rank);
    final coinsWon = _getCoinsWon(totalScore);

    // Check triple match bonus
    final tripleBonus = (results[0] == results[1] && results[1] == results[2])
        ? (results[0] == SlotSymbol.seven ? 500 : 50)
        : 0;
    final finalCoins = coinsWon + tripleBonus;

    // Get stocks
    final stocks = ref.read(stockDataProvider).value ?? [];
    final picked = _pickStock(totalScore, stocks);

    setState(() {
      _spinning = false;
      _coins += finalCoins;
      _totalWins += finalCoins;
      _isJackpot = totalScore >= 18;
      _resultColor = _getResultColor(totalScore);
      _resultMessage = _getResultTier(totalScore);
      _resultTicker = picked != null
          ? '${picked.ticker} — ${picked.name}'
          : (stocks.isEmpty
              ? 'Tambahkan ticker di Dashboard dulu!'
              : 'Spin lagi!');
    });

    if (_isJackpot) {
      _glowController.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  void _resetCoins() {
    setState(() {
      _coins = 100;
      _totalWins = 0;
      _resultTicker = null;
      _resultMessage = 'Koin di-reset! Ayo spin lagi! 🎰';
      _resultColor = AppColors.primary;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  const Text('🎰', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.primaryGradient.createShader(bounds),
                    child: const Text(
                      'Slot Machine',
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Spin untuk rekomendasi saham dari watchlist!',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 16),

              // Coin stats
              Row(
                children: [
                  _StatChip(icon: Icons.monetization_on_rounded,
                      label: 'Koin', value: '$_coins',
                      color: const Color(0xFFFFD700)),
                  const SizedBox(width: 8),
                  _StatChip(icon: Icons.emoji_events_rounded,
                      label: 'Total Win', value: '$_totalWins',
                      color: AppColors.buyGreen),
                  const SizedBox(width: 8),
                  _StatChip(icon: Icons.style_rounded,
                      label: 'Biaya', value: '10/spin',
                      color: AppColors.accent),
                ],
              ),
              const SizedBox(height: 20),

              // Slot machine body
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glow = 0.15 + _pulseController.value * 0.1;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (_isJackpot
                              ? const Color(0xFFFFD700)
                              : AppColors.primary)
                              .withValues(alpha: glow),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: GlassmorphicCard(
                  borderRadius: 24,
                  borderColor: _isJackpot
                      ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                      : AppColors.glassBorder,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 24),
                  child: Column(
                    children: [
                      // Machine top label
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB71C1C)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Text(
                          '★ TICK SLOTS ★',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFD700),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Reels
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2A2A3E),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            return Expanded(
                              child: AnimatedBuilder(
                                animation: _reelAnimations[i],
                                builder: (context, child) {
                                  final anim = _reelAnimations[i].value;
                                  return _ReelCell(
                                    symbol: _reels[i],
                                    spinning: _spinning &&
                                        !_reelControllers[i].isCompleted,
                                    scale: _spinning
                                        ? (0.7 + anim * 0.3)
                                        : 1.0,
                                  );
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Result display
                      if (_resultMessage != null)
                        AnimatedOpacity(
                          opacity: _resultMessage != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _resultColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _resultColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _resultMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _resultColor,
                                  ),
                                ),
                                if (_resultTicker != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Rekomendasi: $_resultTicker',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Spin button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _spinning ? null : _spin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _spinning
                                ? AppColors.surfaceLight
                                : const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: _spinning
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Spinning...',
                                        style: TextStyle(fontSize: 16)),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.casino_rounded, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'SPIN! (10 Koin)',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reset button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _resetCoins,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset Koin'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Paytable
              GlassmorphicCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Paytable',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kombinasi simbol menentukan kualitas saham rekomendasi.',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 10),
                    _PayRow(sym: '7️⃣ 7️⃣ 7️⃣', label: 'JACKPOT — Saham #1',
                        coins: '+500', color: const Color(0xFFFFD700)),
                    _PayRow(sym: '💎 💎 💎', label: 'Triple Diamond',
                        coins: '+150', color: const Color(0xFFB388FF)),
                    _PayRow(sym: '⭐ ⭐ ⭐', label: 'Triple Star',
                        coins: '+100', color: const Color(0xFFFFC107)),
                    _PayRow(sym: '💎 ⭐ 🔔', label: 'Great Mix',
                        coins: '+50', color: const Color(0xFFFF9800)),
                    _PayRow(sym: '🔔 🍋 🍇', label: 'Average Mix',
                        coins: '+20', color: const Color(0xFFCDDC39)),
                    _PayRow(sym: '🍒 🍒 🍒', label: 'Cherry — Saham terakhir',
                        coins: '+0', color: const Color(0xFFE53935)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reel Cell Widget ──

class _ReelCell extends StatelessWidget {
  final SlotSymbol symbol;
  final bool spinning;
  final double scale;

  const _ReelCell({
    required this.symbol,
    required this.spinning,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            symbol.color.withValues(alpha: 0.08),
            const Color(0xFF1A1A2E),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: spinning
              ? AppColors.primary.withValues(alpha: 0.5)
              : symbol.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          if (!spinning)
            BoxShadow(
              color: symbol.color.withValues(alpha: 0.15),
              blurRadius: 8,
            ),
        ],
      ),
      child: Center(
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          child: Text(
            spinning ? '❓' : symbol.emoji,
            style: const TextStyle(fontSize: 42),
          ),
        ),
      ),
    );
  }
}

// ── Stat Chip ──

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 9, color: AppColors.textTertiary)),
                  Text(value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pay Row ──

class _PayRow extends StatelessWidget {
  final String sym;
  final String label;
  final String coins;
  final Color color;

  const _PayRow({
    required this.sym,
    required this.label,
    required this.coins,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(sym, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(coins,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
          ),
        ],
      ),
    );
  }
}
