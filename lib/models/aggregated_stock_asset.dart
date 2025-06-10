import 'stock_asset.dart';

class AggregatedStockAsset {
  final String symbol;
  String? name;
  String? industry;
  double totalShares;
  double averageCostPrice;
  double currentPrice;
  List<StockAsset> individualLots;

  AggregatedStockAsset({
    required this.symbol,
    this.name,
    this.industry,
    required this.totalShares,
    required this.averageCostPrice,
    required this.currentPrice,
    required this.individualLots,
  });

  double get totalCurrentValue => totalShares * currentPrice;
  double get totalOriginalCost => totalShares * averageCostPrice;
  double get totalProfitLoss => totalCurrentValue - totalOriginalCost;
  double get totalProfitLossPercentage =>
      totalOriginalCost != 0 ? (totalProfitLoss / totalOriginalCost) * 100 : 0.0;
}
