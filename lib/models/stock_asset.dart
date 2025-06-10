const String tableStockAssets = 'stock_assets';

class StockAssetFields {
  static final List<String> values = [
    id, userId, symbol, name, shares, avgCostPrice, purchaseDate, industry
  ];

  static const String id = '_id';
  static const String userId = 'userId';
  static const String symbol = 'symbol';
  static const String name = 'name';
  static const String shares = 'shares';
  static const String avgCostPrice = 'avgCostPrice';
  static const String purchaseDate = 'purchaseDate';
  static const String industry = 'industry';
}

class StockAsset {
  final int? id;
  final String symbol;
  String? name;
  final double shares;
  final double avgCostPrice;
  final DateTime purchaseDate;
  String? industry;

  double? currentPrice;
  double get totalCost => shares * avgCostPrice;
  double get currentValue => currentPrice != null ? shares * currentPrice! : 0.0;
  double get profitLoss => currentPrice != null ? currentValue - totalCost : 0.0;
  double get profitLossPercentage => totalCost != 0 && currentPrice != null ? (profitLoss / totalCost) * 100 : 0.0;

  StockAsset({
    this.id,
    required this.symbol,
    this.name,
    required this.shares,
    required this.avgCostPrice,
    required this.purchaseDate,
    this.industry,
    this.currentPrice,
  });

  StockAsset copyWith({
    int? id,
    String? symbol,
    String? name,
    double? shares,
    double? avgCostPrice,
    DateTime? purchaseDate,
    String? industry,
    double? currentPrice,
  }) =>
      StockAsset(
        id: id ?? this.id,
        symbol: symbol ?? this.symbol,
        name: name ?? this.name,
        shares: shares ?? this.shares,
        avgCostPrice: avgCostPrice ?? this.avgCostPrice,
        purchaseDate: purchaseDate ?? this.purchaseDate,
        industry: industry ?? this.industry,
        currentPrice: currentPrice ?? this.currentPrice,
      );

  static StockAsset fromJson(Map<String, dynamic> json) => StockAsset(
        id: json[StockAssetFields.id] as int?,
        symbol: json[StockAssetFields.symbol] as String,
        name: json[StockAssetFields.name] as String?,
        shares: json[StockAssetFields.shares] as double,
        avgCostPrice: json[StockAssetFields.avgCostPrice] as double,
        purchaseDate: DateTime.parse(json[StockAssetFields.purchaseDate] as String),
        industry: json[StockAssetFields.industry] as String?,
      );

  Map<String, dynamic> toJson() => {
        StockAssetFields.id: id,
        StockAssetFields.symbol: symbol,
        StockAssetFields.name: name,
        StockAssetFields.shares: shares,
        StockAssetFields.avgCostPrice: avgCostPrice,
        StockAssetFields.purchaseDate: purchaseDate.toIso8601String(),
        StockAssetFields.industry: industry,
      };
}
