import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/crypto_api_service.dart';
import '../models/crypto_currency.dart';
import 'crypto_detail_page.dart';

class SimulationPage extends StatefulWidget {
  const SimulationPage({super.key});

  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage> {
  Future<List<CryptoCurrency>>? _cryptoFuture;
 final CryptoApiService _apiService = CryptoApiService();
  List<CryptoCurrency> _allCryptos = [];
  List<CryptoCurrency> _displayedCryptos = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final NumberFormat _priceFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
  final NumberFormat _compactFormat = NumberFormat.compact(locale: 'en_US');

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text.trim()) {
        setState(() {
          _searchQuery = _searchController.text.trim();
          _filterCryptos();
        });
      }
    });
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _cryptoFuture = _apiService.getMarketData(perPage: 100);
      });
    }
    try {
      final data = await _cryptoFuture!;
      if (mounted) {
        setState(() {
          _allCryptos = data;
          _filterCryptos();
        });
      }
    } catch (error) {
      if (mounted) {
      }
    }
  }

  void _filterCryptos() {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) {
      _displayedCryptos = List.from(_allCryptos);
    } else {
      _displayedCryptos = _allCryptos
          .where((crypto) => crypto.name.toLowerCase().contains(query) || crypto.symbol.toLowerCase().contains(query))
          .toList();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('加密貨幣市場'),
          elevation: 0.5,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: '搜尋幣種 (例如 BTC, Ethereum)...',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      ),
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: IconButton(
                        icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadData,
          color: colorScheme.primary,
          backgroundColor: colorScheme.surfaceContainerHigh,
          child: FutureBuilder<List<CryptoCurrency>>(
            future: _cryptoFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _allCryptos.isEmpty) {
                return Center(child: CircularProgressIndicator(color: colorScheme.primary));
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_outlined, color: colorScheme.error, size: 70),
                        const SizedBox(height: 20),
                        Text(
                          '無法載入數據',
                          style: theme.textTheme.headlineSmall?.copyWith(color: colorScheme.onErrorContainer),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '請檢查您的網路連線或稍後再試。\n錯誤: ${snapshot.error.toString().substring(0,snapshot.error.toString().length > 100 ? 100 : snapshot.error.toString().length)}...',
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text("重試"),
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                          ),
                        )
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasData || _allCryptos.isNotEmpty) {
                if (_displayedCryptos.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 70, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('找不到 "$_searchQuery"', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('請嘗試其他關鍵字。', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }
                if (_allCryptos.isEmpty && !_searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.currency_bitcoin, size: 70, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('暫無加密貨幣數據。', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 10),
                        ElevatedButton(onPressed: _loadData, child: const Text("點此刷新"))
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: _displayedCryptos.length,
                  itemBuilder: (context, index) {
                    final crypto = _displayedCryptos[index];
                    final priceChange = crypto.priceChangePercentage24h;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.surfaceVariant,
                        child: ClipOval(
                          child: FadeInImage.assetNetwork(
                            placeholder: 'assets/images/default_coin_placeholder.png',
                            image: crypto.image,
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                            imageErrorBuilder: (context, error, stackTrace) {
                              return Center(child: Icon(Icons.broken_image_outlined, color: colorScheme.onSurfaceVariant.withOpacity(0.5)));
                            },
                          ),
                        ),
                      ),
                      title: Text(
                        crypto.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        crypto.symbol.toUpperCase(),
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _priceFormat.format(crypto.currentPrice),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          if (priceChange != null)
                            Text(
                              '${priceChange >= 0 ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: priceChange >= 0 ? Colors.green[600] : Colors.red[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else
                            Text('N/A', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        ],
                      ),
                      onTap: () {
                        _searchFocusNode.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CryptoDetailPage(coinId: crypto.id),
                          ),
                        );
                      },
                    );
                  },
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 20,
                    endIndent: 20,
                    color: colorScheme.outline.withOpacity(0.3),
                  ),
                );
              }
              return const Center(child: Text("正在準備數據..."));
            },
          ),
        ),
      ),
    );
  }
}