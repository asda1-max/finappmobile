class PortfolioItem {
  final int? id;
  final String ticker;
  final String type; // 'stock' or 'crypto'
  final double shares;
  final double averageCost;
  final DateTime dateAdded;

  PortfolioItem({
    this.id,
    required this.ticker,
    this.type = 'stock',
    required this.shares,
    required this.averageCost,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticker': ticker,
      'type': type,
      'shares': shares,
      'averageCost': averageCost,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory PortfolioItem.fromMap(Map<String, dynamic> map) {
    return PortfolioItem(
      id: map['id']?.toInt(),
      ticker: map['ticker'] ?? '',
      type: map['type'] ?? 'stock',
      shares: map['shares']?.toDouble() ?? 0.0,
      averageCost: map['averageCost']?.toDouble() ?? 0.0,
      dateAdded: map['dateAdded'] != null 
          ? DateTime.parse(map['dateAdded']) 
          : DateTime.now(),
    );
  }
}
