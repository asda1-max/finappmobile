import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/portfolio_item.dart';
import '../services/local_db_service.dart';
import '../../data/stock_repository.dart';
import '../../models/stock_data.dart';
import 'chart_provider.dart'; // to reuse stockRepositoryProvider

final portfolioProvider = NotifierProvider<PortfolioNotifier, List<PortfolioItem>>(
  PortfolioNotifier.new,
);

class PortfolioNotifier extends Notifier<List<PortfolioItem>> {
  @override
  List<PortfolioItem> build() {
    loadPortfolio();
    return [];
  }

  Future<void> loadPortfolio() async {
    final items = await LocalDbService.getPortfolioItems();
    state = items;
  }

  Future<void> addAsset(PortfolioItem item) async {
    await LocalDbService.addPortfolioItem(item);
    await loadPortfolio();
  }

  Future<void> updateAsset(PortfolioItem item) async {
    await LocalDbService.updatePortfolioItem(item);
    await loadPortfolio();
  }

  Future<void> deleteAsset(int id) async {
    await LocalDbService.deletePortfolioItem(id);
    await loadPortfolio();
  }
}

final portfolioPricesProvider = FutureProvider<Map<String, StockData>>((ref) async {
  final portfolio = ref.watch(portfolioProvider);
  if (portfolio.isEmpty) return {};

  final tickers = portfolio.map((e) => e.ticker).toSet().toList();
  final repo = ref.watch(stockRepositoryProvider);
  final stocks = await repo.fetchStocks(tickers);

  return {for (var stock in stocks) stock.ticker: stock};
});

