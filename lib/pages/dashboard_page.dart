import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/stock_api_service.dart';
import '../services/crypto_api_service.dart';
import '../helpers/database_helper.dart';
import '../models/stock_asset.dart';
import '../models/crypto_currency.dart';

class DashboardPage extends StatefulWidget {
  final User? user;

  const DashboardPage({super.key, this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double _totalStockPortfolioValue = 0.0;
  double _totalStockOriginalCost = 0.0;
  double _totalStockProfitLoss = 0.0;
  double _totalStockProfitLossPercentage = 0.0;
  bool _isLoadingStockSummary = true;

  final CryptoApiService _cryptoApiService = CryptoApiService();
  List<CryptoCurrency> _topCryptosData = [];
  bool _isLoadingCryptos = true;

  final StockApiService _stockApiService = StockApiService();
  List<Map<String, dynamic>> _stockIndexes = [];
  bool _isLoadingIndexes = true;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _percentFormat = NumberFormat("##0.0#", "en_US");
  final NumberFormat _numberFormat = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoadingStockSummary = true;
      _isLoadingCryptos = true;
      _isLoadingIndexes = true;
    });

    await Future.wait([
      _loadStockPortfolioSummary(),
      _loadTopCryptos(),
      _loadStockIndexes(),
    ]);
  }

  Future<void> _loadStockPortfolioSummary() async {
    if (!mounted) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoadingStockSummary = false);
      return;
    }
    final String userId = currentUser.uid;

    try {
      final allIndividualLots = await DatabaseHelper.instance.readAllAssets(userId);
      if (allIndividualLots.isEmpty) {
        if (mounted) {
          setState(() {
            _totalStockPortfolioValue = 0.0;
            _totalStockOriginalCost = 0.0;
            _totalStockProfitLoss = 0.0;
            _totalStockProfitLossPercentage = 0.0;
            _isLoadingStockSummary = false;
          });
        }
        return;
      }

      Map<String, List<StockAsset>> groupedAssets = {};
      for (var lot in allIndividualLots) {
        groupedAssets.putIfAbsent(lot.symbol, () => []).add(lot);
      }

      double tempTotalValue = 0;
      double tempTotalCost = 0;

      for (var entry in groupedAssets.entries) {
        String symbol = entry.key;
        List<StockAsset> lots = entry.value;
        double currentPrice = lots.first.avgCostPrice;

        final quoteData = await _stockApiService.getQuote(symbol);
        if (quoteData != null && quoteData['c'] != null) {
          currentPrice = (quoteData['c'] as num).toDouble();
        }

        double totalSharesForSymbol = 0;
        double totalCostForSymbol = 0;
        for (var lot in lots) {
          totalSharesForSymbol += lot.shares;
          totalCostForSymbol += lot.shares * lot.avgCostPrice;
        }
        tempTotalValue += totalSharesForSymbol * currentPrice;
        tempTotalCost += totalCostForSymbol;
      }

      if (mounted) {
        setState(() {
          _totalStockPortfolioValue = tempTotalValue;
          _totalStockOriginalCost = tempTotalCost;
          _totalStockProfitLoss = tempTotalValue - tempTotalCost;
          _totalStockProfitLossPercentage = tempTotalCost != 0
              ? (_totalStockProfitLoss / tempTotalCost) * 100
              : 0.0;
          _isLoadingStockSummary = false;
        });
      }
    } catch (e) {
      print("Error loading stock portfolio summary: $e");
      if (mounted) setState(() => _isLoadingStockSummary = false);
    }
  }

  Future<void> _loadTopCryptos() async {
    if (!mounted) return;
    try {
      final cryptos = await _cryptoApiService.getMarketData(perPage: 5, currency: 'usd');
      if (mounted) {
        setState(() {
          _topCryptosData = cryptos;
          _isLoadingCryptos = false;
        });
      }
    } catch (e) {
      print("Error loading top cryptos: $e");
      if (mounted) setState(() => _isLoadingCryptos = false);
    }
  }

  Future<void> _loadStockIndexes() async {
    if (!mounted) return;
    try {
      final spyData = await _stockApiService.getQuote("SPY");
      final qqqData = await _stockApiService.getQuote("QQQ");
      List<Map<String, dynamic>> indexes = [];

      if (spyData != null && spyData['c'] != null && spyData['dp'] != null) {
        indexes.add({
          'name': 'S&P 500 (SPY)',
          'value': (spyData['c'] as num).toDouble(),
          'change': (spyData['dp'] as num).toDouble(),
        });
      }
      if (qqqData != null && qqqData['c'] != null && qqqData['dp'] != null) {
        indexes.add({
          'name': 'Nasdaq 100 (QQQ)',
          'value': (qqqData['c'] as num).toDouble(),
          'change': (qqqData['dp'] as num).toDouble(),
        });
      }

      if (mounted) {
        setState(() {
          _stockIndexes = indexes;
          _isLoadingIndexes = false;
        });
      }
    } catch (e) {
      print("Error loading stock indexes: $e");
      if (mounted) setState(() => _isLoadingIndexes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('總覽'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            if (widget.user?.displayName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(
                  'Hi, ${widget.user!.displayName}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            _buildStockSummarySection(),
            const SizedBox(height: 24),
            Text('市場焦點', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            _buildCryptoFocusSection(),
            const SizedBox(height: 16),
            _buildStockIndexFocusSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStockSummarySection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingStockSummary) {
      return Card(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_totalStockPortfolioValue == 0 && _totalStockOriginalCost == 0) {
      return Card(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.show_chart_rounded, size: 40, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text("股票投資組合為空", style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text("新增資產以查看總覽", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '股票投資組合',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('總現值:', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                Text(
                  _currencyFormat.format(_totalStockPortfolioValue),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('總成本:', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                Text(
                  _currencyFormat.format(_totalStockOriginalCost),
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('總損益:', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                Text(
                  '${_totalStockProfitLoss >= 0 ? '+' : ''}${_currencyFormat.format(_totalStockProfitLoss.abs())} (${_totalStockProfitLossPercentage.toStringAsFixed(1)}%)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _totalStockProfitLoss >= 0
                        ? (theme.brightness == Brightness.dark ? Colors.greenAccent[400] : Colors.green[700])
                        : (theme.brightness == Brightness.dark ? Colors.redAccent[200] : Colors.red[700]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoFocusSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingCryptos) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_topCryptosData.isEmpty) {
      return Card(
        elevation: 1.0,
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: const SizedBox(height: 80, child: Center(child: Text('無法獲取加密貨幣行情', style: TextStyle(color: Colors.grey)))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text('熱門加密貨幣', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ),
        Column(
          children: _topCryptosData.map((crypto) {
            final priceChange = crypto.priceChangePercentage24h;
            return Card(
              elevation: 1.5,
              margin: const EdgeInsets.only(bottom: 10.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              color: colorScheme.surfaceContainerHigh,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(crypto.image),
                  backgroundColor: Colors.transparent,
                ),
                title: Text(
                  crypto.name,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  crypto.symbol.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(crypto.currentPrice),
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                    if (priceChange != null)
                      Text(
                        '${priceChange >= 0 ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: priceChange >= 0
                              ? (theme.brightness == Brightness.dark ? Colors.greenAccent[400] : Colors.green[700])
                              : (theme.brightness == Brightness.dark ? Colors.redAccent[200] : Colors.red[700]),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStockIndexFocusSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingIndexes) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_stockIndexes.isEmpty) {
      return Card(
        elevation: 1.0,
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: const SizedBox(height: 80, child: Center(child: Text('無法獲取股票指數行情', style: TextStyle(color: Colors.grey)))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text('主要市場指數', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ),
        Column(
          children: _stockIndexes.map((idx) {
            final change = idx['change'] as double?;
            return Card(
              elevation: 1.5,
              margin: const EdgeInsets.only(bottom: 10.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              color: colorScheme.surfaceContainerHigh,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                title: Text(
                  idx['name'],
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _numberFormat.format(idx['value']),
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                    if (change != null)
                      Text(
                        '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: change >= 0
                              ? (theme.brightness == Brightness.dark ? Colors.greenAccent[400] : Colors.green[700])
                              : (theme.brightness == Brightness.dark ? Colors.redAccent[200] : Colors.red[700]),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}