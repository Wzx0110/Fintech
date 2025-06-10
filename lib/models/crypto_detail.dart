class CryptoDetail {
  final String id;
  final String symbol;
  final String name;
  final String imageLarge;
  final String? descriptionEn;
  final double currentPriceUsd;
  final double? marketCapUsd;
  final double? totalVolumeUsd;
  final double? high24hUsd;
  final double? low24hUsd;
  final double? priceChangePercentage24h;
  final double? priceChangePercentage7d;
  final double? priceChangePercentage30d;

  CryptoDetail({
    required this.id,
    required this.symbol,
    required this.name,
    required this.imageLarge,
    this.descriptionEn,
    required this.currentPriceUsd,
    this.marketCapUsd,
    this.totalVolumeUsd,
    this.high24hUsd,
    this.low24hUsd,
    this.priceChangePercentage24h,
    this.priceChangePercentage7d,
    this.priceChangePercentage30d,
  });

  factory CryptoDetail.fromJson(Map<String, dynamic> json) {
    final descriptionMap = json['description'] as Map<String, dynamic>?;
    final marketData = json['market_data'] as Map<String, dynamic>?;
    final currentPriceMap = marketData?['current_price'] as Map<String, dynamic>?;
    final high24hMap = marketData?['high_24h'] as Map<String, dynamic>?;
    final low24hMap = marketData?['low_24h'] as Map<String, dynamic>?;

    return CryptoDetail(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      imageLarge: (json['image'] as Map<String, dynamic>?)?['large'] as String? ?? '',
      descriptionEn: descriptionMap?['en'] as String?,
      currentPriceUsd: (currentPriceMap?['usd'] as num?)?.toDouble() ?? 0.0,
      marketCapUsd: ((marketData?['market_cap'] as Map<String, dynamic>?)?['usd'] as num?)?.toDouble(),
      totalVolumeUsd: ((marketData?['total_volume'] as Map<String, dynamic>?)?['usd'] as num?)?.toDouble(),
      high24hUsd: (high24hMap?['usd'] as num?)?.toDouble(),
      low24hUsd: (low24hMap?['usd'] as num?)?.toDouble(),
      priceChangePercentage24h: (marketData?['price_change_percentage_24h'] as num?)?.toDouble(),
      priceChangePercentage7d: (marketData?['price_change_percentage_7d'] as num?)?.toDouble(),
      priceChangePercentage30d: (marketData?['price_change_percentage_30d'] as num?)?.toDouble(),
    );
  }
}
