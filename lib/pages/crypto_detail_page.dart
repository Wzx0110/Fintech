import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/crypto_api_service.dart';
import '../models/crypto_detail.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class CryptoDetailPage extends StatefulWidget {
  final String coinId;
  const CryptoDetailPage({super.key, required this.coinId});
  @override
  State<CryptoDetailPage> createState() => _CryptoDetailPageState();
}

class _CryptoDetailPageState extends State<CryptoDetailPage> {
  late Future<CryptoDetail> _detailFuture;
  late Future<List<List<num>>> _ohlcDataFuture;
  final CryptoApiService _apiService = CryptoApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
  );
  final NumberFormat _numberFormat = NumberFormat("#,##0.00", "en_US");
  final NumberFormat _compactFormat = NumberFormat.compact(
    locale: 'en_US',
  );
  late ThemeData _theme;
  late ColorScheme _colorScheme;
  String _selectedChartDays = '7';
  final List<String> _chartDayOptions = [
    '1',
    '7',
    '30',
    '90',
    'max',
  ];

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _detailFuture = _apiService.getCoinDetail(widget.coinId);
    _fetchOHLCData();
    _startRefreshTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = Theme.of(context);
    _colorScheme = _theme.colorScheme;
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        print("Timer triggered: Refreshing OHLC data for ${widget.coinId}");
        _fetchOHLCData();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _fetchOHLCData() {
    if (mounted) {
      setState(() {
        _ohlcDataFuture = _apiService.getCoinOHLCData(
          widget.coinId,
          days: _selectedChartDays,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<CryptoDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('無法載入幣種詳情: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final detail = snapshot.data!;
            return CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  expandedHeight: 180.0,
                  pinned: true,
                  backgroundColor: _colorScheme.surface,
                  flexibleSpace: FlexibleSpaceBar(
                    background: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 10,
                          bottom: 40,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(width: 30),
                                if (detail.imageLarge.isNotEmpty)
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _colorScheme.surfaceVariant.withOpacity(0.5),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Image.network(
                                        detail.imageLarge,
                                        width: 30,
                                        height: 30,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  detail.symbol.toUpperCase(),
                                  style: _theme.textTheme.titleLarge?.copyWith(
                                    color: _colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  detail.name,
                                  style: _theme.textTheme.bodyMedium?.copyWith(
                                    color: _colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _currencyFormat.format(detail.currentPriceUsd),
                                      style: _theme.textTheme.headlineSmall?.copyWith(
                                        color: _colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                      ),
                                    ),
                                    if (detail.priceChangePercentage24h != null)
                                      Text(
                                        "${detail.priceChangePercentage24h! >= 0 ? '+' : ''}${detail.priceChangePercentage24h!.toStringAsFixed(2)}%",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: detail.priceChangePercentage24h! >= 0
                                              ? (_theme.brightness == Brightness.dark ? Colors.greenAccent[400] : Colors.green[700])
                                              : (_theme.brightness == Brightness.dark ? Colors.redAccent[200] : Colors.red[700]),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            if (detail.high24hUsd != null || detail.low24hUsd != null || detail.totalVolumeUsd != null) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildCompactHeaderInfo(
                                    "24h高",
                                    detail.high24hUsd != null ? _numberFormat.format(detail.high24hUsd) : "-",
                                    _theme,
                                  ),
                                  _buildCompactHeaderInfo(
                                    "24h低",
                                    detail.low24hUsd != null ? _numberFormat.format(detail.low24hUsd) : "-",
                                    _theme,
                                  ),
                                  _buildCompactHeaderInfo(
                                    "24h量(${detail.symbol.toUpperCase()})",
                                    detail.totalVolumeUsd != null ? _compactFormat.format(detail.totalVolumeUsd! / detail.currentPriceUsd) : "-",
                                    _theme,
                                  ),
                                  _buildCompactHeaderInfo(
                                    "24h額(USD)",
                                    detail.totalVolumeUsd != null ? _compactFormat.format(detail.totalVolumeUsd) : "-",
                                    _theme,
                                  ),
                                ],
                              ),
                              const Divider(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCandlestickChart(),
                          const Divider(),
                          const SizedBox(height: 24),
                          Text(
                            '市場數據',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          _buildInfoRow(
                            '市值:',
                            detail.marketCapUsd != null ? _currencyFormat.format(detail.marketCapUsd) : 'N/A',
                          ),
                          _buildInfoRow(
                            '24小時交易量:',
                            detail.totalVolumeUsd != null ? _currencyFormat.format(detail.totalVolumeUsd) : 'N/A',
                          ),
                          _buildInfoRow(
                            '24小時最高價:',
                            detail.high24hUsd != null ? _currencyFormat.format(detail.high24hUsd) : 'N/A',
                          ),
                          _buildInfoRow(
                            '24小時最低價:',
                            detail.low24hUsd != null ? _currencyFormat.format(detail.low24hUsd) : 'N/A',
                          ),
                          _buildPriceChangeRow(
                            '24小時變化:',
                            detail.priceChangePercentage24h,
                          ),
                          _buildPriceChangeRow(
                            '7天變化:',
                            detail.priceChangePercentage7d,
                          ),
                          _buildPriceChangeRow(
                            '30天變化:',
                            detail.priceChangePercentage30d,
                          ),
                          const SizedBox(height: 24),
                          if (detail.descriptionEn != null && detail.descriptionEn!.isNotEmpty) ...[
                            Text(
                              '簡介',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Divider(),
                            SelectableText(
                              _stripHtmlIfNeeded(detail.descriptionEn!),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            );
          }
          return const Center(child: Text('沒有數據'));
        },
      ),
    );
  }

  Widget _buildCompactHeaderInfo(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPriceChangeRow(String label, double? percentage) {
    if (percentage == null) {
      return _buildInfoRow(label, 'N/A');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            '${percentage.toStringAsFixed(2)}%',
            style: TextStyle(
              color: percentage >= 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _stripHtmlIfNeeded(String htmlString) {
    return htmlString.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
  }

  Widget _buildCandlestickChart() {
    return FutureBuilder<List<List<num>>>(
      future: _ohlcDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return SizedBox(
            height: 300,
            child: Center(child: Text('無法載入圖表數據: ${snapshot.error}')),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final List<List<num>> ohlcData = snapshot.data!;
          double minY = double.maxFinite;
          double maxY = double.minPositive;

          List<CandlestickSpot> candlestickSpots = [];
          List<double> xValues = [];

          for (int i = 0; i < ohlcData.length; i++) {
            final dataPoint = ohlcData[i];
            final double timestamp = dataPoint[0].toDouble();
            final double open = dataPoint[1].toDouble();
            final double high = dataPoint[2].toDouble();
            final double low = dataPoint[3].toDouble();
            final double close = dataPoint[4].toDouble();

            if (high > maxY) maxY = high;
            if (low < minY) minY = low;
            xValues.add(timestamp);

            candlestickSpots.add(
              CandlestickSpot(
                x: timestamp,
                open: open,
                high: high,
                low: low,
                close: close,
              ),
            );
          }

          if (candlestickSpots.isEmpty) {
            return const SizedBox(
              height: 300,
              child: Center(child: Text('沒有圖表數據可供顯示')),
            );
          }

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _chartDayOptions.map((days) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(
                          '$days天',
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedChartDays == days ? _colorScheme.onPrimary : _colorScheme.onSurfaceVariant,
                            fontWeight: _selectedChartDays == days ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: _selectedChartDays == days,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedChartDays = days;
                              _fetchOHLCData();
                            });
                          }
                        },
                        backgroundColor: _colorScheme.surfaceContainer,
                        selectedColor: _colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: BorderSide(
                            color: _selectedChartDays == days ? _colorScheme.primary : _colorScheme.outline.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                        elevation: _selectedChartDays == days ? 2 : 0,
                        pressElevation: 4,
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 10.0,
                    right: 20,
                    left: 10,
                    bottom: 10,
                  ),
                  child: CandlestickChart(
                    CandlestickChartData(
                      candlestickSpots: candlestickSpots,
                      minY: (minY * 0.95).floorToDouble(),
                      maxY: (maxY * 1.05).ceilToDouble(),
                      minX: xValues.first,
                      maxX: xValues.last,
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Text(
                                  _numberFormat.format(value),
                                  style: _theme.textTheme.bodySmall?.copyWith(color: _colorScheme.onSurfaceVariant),
                                  textAlign: TextAlign.left,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: (xValues.last - xValues.first) / 4,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  DateFormat('MM/dd').format(date),
                                  style: _theme.textTheme.bodySmall?.copyWith(color: _colorScheme.onSurfaceVariant),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        drawHorizontalLine: true,
                        getDrawingHorizontalLine: (value) => FlLine(color: _colorScheme.outline.withOpacity(0.1), strokeWidth: 0.5),
                        getDrawingVerticalLine: (value) => FlLine(color: _colorScheme.outline.withOpacity(0.1), strokeWidth: 0.5),
                      ),
                      borderData: FlBorderData(show: false),
                      candlestickTouchData: CandlestickTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: CandlestickTouchTooltipData(
                          getTooltipColor: (CandlestickSpot spot) {
                            return Colors.blueGrey.withOpacity(0.9);
                          },
                          getTooltipItems: (
                            FlCandlestickPainter painter,
                            CandlestickSpot spot,
                            int spotIndex,
                          ) {
                            final date = DateFormat('MM/dd HH:mm').format(
                              DateTime.fromMillisecondsSinceEpoch(
                                spot.x.toInt(),
                              ),
                            );
                            return CandlestickTooltipItem(
                              '$date\n'
                              '開: ${_numberFormat.format(spot.open)}\n'
                              '高: ${_numberFormat.format(spot.high)}\n'
                              '低: ${_numberFormat.format(spot.low)}\n'
                              '收: ${_numberFormat.format(spot.close)}',
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                          tooltipPadding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return const SizedBox(
          height: 300,
          child: Center(child: Text('沒有圖表數據')),
        );
      },
    );
  }
}