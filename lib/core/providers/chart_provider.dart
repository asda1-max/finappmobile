import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/stock_repository.dart';

final stockRepositoryProvider = Provider((ref) => StockRepository());

class ChartParams {
  final String ticker;
  final String period;
  final String interval;

  const ChartParams({
    required this.ticker,
    required this.period,
    required this.interval,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartParams &&
          runtimeType == other.runtimeType &&
          ticker == other.ticker &&
          period == other.period &&
          interval == other.interval;

  @override
  int get hashCode => ticker.hashCode ^ period.hashCode ^ interval.hashCode;
}

final chartHistoryProvider = FutureProvider.family<Map<String, dynamic>, ChartParams>((ref, params) async {
  final repo = ref.watch(stockRepositoryProvider);
  return repo.fetchPriceHistory(
    params.ticker,
    period: params.period,
    interval: params.interval,
  );
});
