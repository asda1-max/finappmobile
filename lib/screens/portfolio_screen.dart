import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/portfolio_item.dart';
import '../core/providers/portfolio_provider.dart';
import '../widgets/glassmorphic_card.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final pricesAsync = ref.watch(portfolioPricesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Portfolio'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _showAddAssetDialog(context, ref),
          ),
        ],
      ),
      body: pricesAsync.when(
        data: (prices) {
          double totalCost = 0;
          double currentValue = 0;

          for (final item in portfolio) {
            final stock = prices[item.ticker];
            final currentPrice = stock?.price ?? item.averageCost;
            totalCost += item.shares * item.averageCost;
            currentValue += item.shares * currentPrice;
          }

          final totalProfit = currentValue - totalCost;
          final totalProfitPercent = totalCost > 0 ? (totalProfit / totalCost) : 0.0;
          final isProfit = totalProfit >= 0;
          final portfolioTicker = _portfolioTicker(portfolio);

          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(portfolioPricesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeroHeader(currentValue, totalProfit, totalProfitPercent, isProfit, portfolioTicker),
                const SizedBox(height: 24),
                const Text(
                  'ASSETS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (portfolio.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'Belum ada aset. Tambahkan portofolio pertama Anda!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...portfolio.map((item) {
                    final stock = prices[item.ticker];
                    final currentPrice = stock?.price ?? item.averageCost;
                    return _buildAssetCard(context, item, currentPrice, ref);
                  }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.sellRed))),
      ),
    );
  }

  Widget _buildHeroHeader(
    double currentValue,
    double profit,
    double profitPercent,
    bool isProfit,
    String? ticker,
  ) {
    return GlassmorphicCard(
      child: Column(
        children: [
          const Text(
            'TOTAL BALANCE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.price(currentValue, ticker: ticker),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isProfit ? AppColors.buyGreen : AppColors.sellRed).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isProfit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 14,
                  color: isProfit ? AppColors.buyGreen : AppColors.sellRed,
                ),
                const SizedBox(width: 4),
                Text(
                  '${Formatters.price(profit.abs(), ticker: ticker)} (${Formatters.percent(profitPercent * 100)})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isProfit ? AppColors.buyGreen : AppColors.sellRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(BuildContext context, PortfolioItem item, double currentPrice, WidgetRef ref) {
    final costValue = item.shares * item.averageCost;
    final currentValue = item.shares * currentPrice;
    final profit = currentValue - costValue;
    final profitPercent = costValue > 0 ? (profit / costValue) : 0.0;
    final isProfit = profit >= 0;

    return GestureDetector(
      onTap: () => _showAssetDialog(context, ref, existing: item),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Hapus Aset?'),
            content: Text('Apakah Anda yakin ingin menghapus ${item.ticker} dari portofolio?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              TextButton(
                onPressed: () {
                  ref.read(portfolioProvider.notifier).deleteAsset(item.id!);
                  Navigator.pop(ctx);
                },
                child: const Text('Hapus', style: TextStyle(color: AppColors.sellRed)),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
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
                    item.ticker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.shares} shares @ ${Formatters.price(item.averageCost, ticker: item.ticker)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.price(currentValue, ticker: item.ticker),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isProfit ? '+' : ''}${Formatters.price(profit, ticker: item.ticker)} (${Formatters.percent(profitPercent * 100)})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isProfit ? AppColors.buyGreen : AppColors.sellRed,
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

  String? _portfolioTicker(List<PortfolioItem> items) {
    if (items.isEmpty) return null;
    final allJakarta = items.every((item) => item.ticker.toUpperCase().endsWith('.JK'));
    final allNonJakarta = items.every((item) => !item.ticker.toUpperCase().endsWith('.JK'));
    if (allJakarta || allNonJakarta) return items.first.ticker;
    return null;
  }

  void _showAddAssetDialog(BuildContext context, WidgetRef ref) {
    _showAssetDialog(context, ref);
  }

  void _showAssetDialog(BuildContext context, WidgetRef ref, {PortfolioItem? existing}) {
    final tickerController = TextEditingController(text: existing?.ticker ?? '');
    final sharesController = TextEditingController(
      text: existing != null ? existing.shares.toString() : '',
    );
    final priceController = TextEditingController(
      text: existing != null ? existing.averageCost.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                existing == null ? 'Add Asset' : 'Edit Asset',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: tickerController,
                decoration: const InputDecoration(
                  labelText: 'Ticker (e.g. BBCA.JK)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sharesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Shares (Lembar)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Average Cost (Harga Beli)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    final ticker = tickerController.text.trim().toUpperCase();
                    final shares = double.tryParse(sharesController.text) ?? 0;
                    final price = double.tryParse(priceController.text) ?? 0;

                    if (ticker.isNotEmpty && shares > 0 && price > 0) {
                      final item = PortfolioItem(
                        id: existing?.id,
                        ticker: ticker,
                        shares: shares,
                        averageCost: price,
                        dateAdded: existing?.dateAdded ?? DateTime.now(),
                        type: existing?.type ?? 'stock',
                      );
                      if (existing == null) {
                        ref.read(portfolioProvider.notifier).addAsset(item);
                      } else {
                        ref.read(portfolioProvider.notifier).updateAsset(item);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(existing == null ? 'Simpan' : 'Update'),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
