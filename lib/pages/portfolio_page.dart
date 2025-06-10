import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import '../models/stock_asset.dart';
import 'add_edit_stock_page.dart'; // 創建新增/編輯頁面時引入
import '../services/stock_api_service.dart'; // 整合API時引入
import 'package:fl_chart/fl_chart.dart'; // 整合圖表時引入
import 'detailed_allocation_page.dart'; // 用於顯示詳細分佈頁面
import '../models/aggregated_stock_asset.dart'; // 新增模型，用於存儲加總後的數據
import 'stock_lots_detail_page.dart'; // 新增庫存明細頁面
import 'package:firebase_auth/firebase_auth.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  //List<StockAsset> _stockAssets = [];
  List<AggregatedStockAsset> _aggregatedStockAssets = []; // 新的，存儲加總後的數據
  bool _isLoading = true;
  final StockApiService _stockApiService = StockApiService(); // 稍後使用
  int _touchedIndexPieStock = -1; // 用於股票佔比圓餅圖的觸摸交互
  int _touchedIndexPieIndustry = -1; // 用於產業分佈圓餅圖的觸摸交互

  @override
  void initState() {
    super.initState();
    _refreshStockAssets();
  }

  Future<void> _refreshStockAssets() async {
    if (!mounted) return;

    // 1. 獲取當前用戶的 userId
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // 如果用戶未登入，則不執行任何操作或清空列表
      if (mounted) {
        setState(() {
          _aggregatedStockAssets = [];
          _isLoading = false;
        });
      }
      print("PortfolioPage: User not logged in, cannot refresh assets.");
      return;
    }
    final String userId = currentUser.uid; // <--- 獲取 userId

    setState(() {
      _isLoading = true;
    });
    try {
      // 2. 將 userId 傳遞給 readAllAssets
      final allIndividualLots = await DatabaseHelper.instance.readAllAssets(
        userId,
      ); // <--- 傳入 userId

      if (allIndividualLots.isEmpty) {
        if (mounted) {
          setState(() {
            _aggregatedStockAssets = [];
            _isLoading = false;
          });
        }
        return;
      }

      Map<String, List<StockAsset>> groupedAssets = {};
      for (var lot in allIndividualLots) {
        groupedAssets.putIfAbsent(lot.symbol, () => []).add(lot);
      }

      List<AggregatedStockAsset> newAggregatedAssets = [];
      for (var entry in groupedAssets.entries) {
        String symbol = entry.key;
        List<StockAsset> lots = entry.value;

        double currentPrice = lots.first.avgCostPrice;
        String? companyName = lots.first.name;
        String? companyIndustry = lots.first.industry;

        final quoteData = await _stockApiService.getQuote(symbol);
        if (quoteData != null && quoteData['c'] != null) {
          currentPrice = (quoteData['c'] as num).toDouble();
        }

        if (companyName == null ||
            companyName.isEmpty ||
            companyIndustry == null ||
            companyIndustry.isEmpty) {
          final profileData = await _stockApiService.getCompanyProfile(symbol);
          if (profileData != null) {
            companyName ??= profileData['name'] as String?;
            companyIndustry ??= profileData['finnhubIndustry'] as String?;

            for (var lotToUpdate in lots) {
              bool needsDbUpdate = false;
              StockAsset updatedLot = lotToUpdate;
              if ((updatedLot.name == null || updatedLot.name!.isEmpty) &&
                  companyName != null) {
                updatedLot = updatedLot.copyWith(name: companyName);
                needsDbUpdate = true;
              }
              if ((updatedLot.industry == null ||
                      updatedLot.industry!.isEmpty) &&
                  companyIndustry != null) {
                updatedLot = updatedLot.copyWith(industry: companyIndustry);
                needsDbUpdate = true;
              }
              if (needsDbUpdate && updatedLot.id != null) {
                // 3. 如果在這裡調用 update，也需要傳遞 userId
                await DatabaseHelper.instance.update(
                  updatedLot,
                  userId,
                ); // <--- 注意這裡也需要 userId
              }
            }
          }
        }

        double totalShares = 0;
        double totalCostValue = 0;
        for (var lot in lots) {
          totalShares += lot.shares;
          totalCostValue += lot.shares * lot.avgCostPrice;
        }
        double averageCostPrice =
            totalShares > 0 ? totalCostValue / totalShares : 0;

        newAggregatedAssets.add(
          AggregatedStockAsset(
            symbol: symbol,
            name: companyName,
            industry: companyIndustry,
            totalShares: totalShares,
            averageCostPrice: averageCostPrice,
            currentPrice: currentPrice,
            individualLots: lots,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _aggregatedStockAssets = newAggregatedAssets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('無法載入資產數據 (API): $e')));
      }
      print("Error refreshing aggregated stock assets: $e");
    }
  }

  @override
  void dispose() {
    // DatabaseHelper.instance.close(); // 通常不需要在頁面 dispose 時關閉數據庫
    super.dispose();
  }

  void _navigateToAddEditPage({StockAsset? asset}) async {
    final currentUser = FirebaseAuth.instance.currentUser; // 獲取當前用戶
    if (currentUser == null) {
      // 如果用戶未登入，理論上不應該能進入此頁面或執行此操作
      // 可以選擇顯示一個錯誤或直接返回
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('錯誤：用戶未登入')));
      return;
    }
    final String userId = currentUser.uid; // 獲取 userId

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddEditStockPage(
              asset: asset,
              userId: userId, // <--- 傳遞 userId 給 AddEditStockPage
            ),
      ),
    );

    if (result == true && mounted) {
      _refreshStockAssets();
    }
    // SnackBar 移到 AddEditStockPage 保存成功後顯示可能更好，或者保留在這裡
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text(asset == null ? '準備新增資產' : '準備編輯 ${asset.symbol}')),
    // );
  }

  @override
  Widget build(BuildContext context) {
    // 0. 初始計算和過濾 (確保 _stockAssets 中的 currentPrice 是最新的)
    // _refreshStockAssets() 應該已經處理了這個，這裡假設 _stockAssets 是最新的

    // 1. 計算投資組合總市值 (基於 _aggregatedStockAssets)
    final double totalPortfolioValue = _aggregatedStockAssets.fold(
      0.0,
      (sum, aggAsset) => sum + aggAsset.totalCurrentValue,
    );
    // 計算總成本
    final double totalOriginalCost = _aggregatedStockAssets.fold(
      0.0,
      (sum, aggAsset) => sum + aggAsset.totalOriginalCost,
    ); // 假設 AggregatedStockAsset 有 totalOriginalCost

    // 2. 準備股票佔比數據 (基於 _aggregatedStockAssets)
    List<MapEntry<AggregatedStockAsset, double>> allStockAllocations = [];
    if (totalPortfolioValue > 0) {
      for (var aggAsset in _aggregatedStockAssets) {
        if (aggAsset.totalCurrentValue > 0) {
          allStockAllocations.add(
            MapEntry(
              aggAsset,
              (aggAsset.totalCurrentValue / totalPortfolioValue) * 100,
            ),
          );
        }
      }
    }
    allStockAllocations.sort((a, b) => b.value.compareTo(a.value)); // 按百分比降序排序

    // 3. 準備產業分佈數據
    Map<String, double> industryRawValues = {}; // Key: 產業名, Value: 該產業總市值
    for (var aggAsset in _aggregatedStockAssets) {
      final industry =
          aggAsset.industry?.isNotEmpty == true ? aggAsset.industry! : '未分類';
      if (aggAsset.totalCurrentValue > 0) {
        industryRawValues[industry] =
            (industryRawValues[industry] ?? 0) + aggAsset.totalCurrentValue;
      }
    }
    List<MapEntry<String, double>> allIndustryAllocations = [];
    if (totalPortfolioValue > 0 && industryRawValues.isNotEmpty) {
      industryRawValues.forEach((industry, value) {
        allIndustryAllocations.add(
          MapEntry(industry, (value / totalPortfolioValue) * 100),
        );
      });
    }
    allIndustryAllocations.sort(
      (a, b) => b.value.compareTo(a.value),
    ); // 按百分比降序排序

    // 4. 準備初始概覽顯示的數據 (例如，最多顯示前 N 項 + 其他)
    const int maxItemsForInitialLegend = 4; // 你可以調整這個數量

    // 處理股票概覽數據
    List<MapEntry<String, double>> initialStockLegendData = [];
    List<Color> initialStockLegendColors = []; // 用於圖例的顏色
    final List<Color> stockPieColors = [
      // 為股票餅圖準備顏色
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.pink, Colors.indigo, Colors.amber, Colors.cyan,
      Colors.lime, Colors.brown, Colors.grey,
    ];
    int stockColorIdx = 0;

    double otherStocksPercentage = 0;
    if (allStockAllocations.length > maxItemsForInitialLegend) {
      for (int i = 0; i < maxItemsForInitialLegend; i++) {
        initialStockLegendData.add(
          MapEntry(
            allStockAllocations[i].key.symbol,
            allStockAllocations[i].value,
          ),
        );
        initialStockLegendColors.add(
          stockPieColors[stockColorIdx++ % stockPieColors.length],
        );
      }
      for (
        int i = maxItemsForInitialLegend;
        i < allStockAllocations.length;
        i++
      ) {
        otherStocksPercentage += allStockAllocations[i].value;
      }
      if (otherStocksPercentage > 0.01) {
        // 只有當"其他"有實際佔比時才顯示
        initialStockLegendData.add(MapEntry('其他股票', otherStocksPercentage));
        initialStockLegendColors.add(Colors.grey[700]!); // "其他" 給一個固定顏色
      }
    } else {
      for (var entry in allStockAllocations) {
        initialStockLegendData.add(MapEntry(entry.key.symbol, entry.value));
        initialStockLegendColors.add(
          stockPieColors[stockColorIdx++ % stockPieColors.length],
        );
      }
    }

    // 處理產業概覽數據
    List<MapEntry<String, double>> initialIndustryLegendData = [];
    List<Color> initialIndustryLegendColors = [];
    final List<Color> industryPieColors = [
      // 為產業餅圖準備不同的顏色
      Colors.lightBlueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.tealAccent,
      Colors.pinkAccent,
      Colors.indigoAccent,
      Colors.amberAccent,
      Colors.cyanAccent,
      Colors.limeAccent, Colors.brown[300]!, Colors.blueGrey[300]!,
    ];
    int industryColorIdx = 0;
    double otherIndustriesPercentage = 0;

    if (allIndustryAllocations.length > maxItemsForInitialLegend) {
      for (int i = 0; i < maxItemsForInitialLegend; i++) {
        initialIndustryLegendData.add(
          MapEntry(
            allIndustryAllocations[i].key,
            allIndustryAllocations[i].value,
          ),
        );
        initialIndustryLegendColors.add(
          industryPieColors[industryColorIdx++ % industryPieColors.length],
        );
      }
      for (
        int i = maxItemsForInitialLegend;
        i < allIndustryAllocations.length;
        i++
      ) {
        otherIndustriesPercentage += allIndustryAllocations[i].value;
      }
      if (otherIndustriesPercentage > 0.01) {
        initialIndustryLegendData.add(
          MapEntry('其他產業', otherIndustriesPercentage),
        );
        initialIndustryLegendColors.add(Colors.grey[700]!);
      }
    } else {
      for (var entry in allIndustryAllocations) {
        initialIndustryLegendData.add(MapEntry(entry.key, entry.value));
        initialIndustryLegendColors.add(
          industryPieColors[industryColorIdx++ % industryPieColors.length],
        );
      }
    }

    // 5. 為 PieChart 準備 PieChartSectionData (基於完整數據 allStockAllocations 和 allIndustryAllocations)
    // 確保 _buildStockPieChartSections 和 _buildIndustryPieChartSections
    // 使用傳入的完整數據和上面定義的顏色列表 (stockPieColors, industryPieColors)
    final List<PieChartSectionData> stockPieChartSectionsData =
        _buildPieChartSections(
          allStockAllocations
              .map((e) => MapEntry(e.key.symbol, e.value))
              .toList(), // 傳遞 symbol 和 percentage
          stockPieColors,
          _touchedIndexPieStock,
        );
    final List<PieChartSectionData> industryPieChartSectionsData =
        _buildPieChartSections(
          allIndustryAllocations, // 傳遞 industry name 和 percentage
          industryPieColors,
          _touchedIndexPieIndustry,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('股票總覽'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStockAssets,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _aggregatedStockAssets.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_chart_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '您的投資組合是空的',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '開始追蹤您的股票資產，點擊右下角的「+」按鈕新增您的第一筆持倉吧！',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: _refreshStockAssets,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPortfolioSummaryCard(
                        totalPortfolioValue,
                        totalOriginalCost,
                      ),
                      if (totalPortfolioValue > 0) ...[
                        const Divider(),
                        _buildChartSectionHeader(
                          title: '股票持倉比例',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => DetailedAllocationPage(
                                      title: '股票佔比詳情',
                                      allocationData:
                                          allStockAllocations
                                              .map(
                                                (e) => MapEntry(
                                                  e.key.symbol,
                                                  e.value,
                                                ),
                                              )
                                              .toList(),
                                      colors: stockPieColors,
                                    ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .center, // 改為 center 讓圖例和餅圖垂直居中對齊
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 150, // 調整餅圖高度
                                child:
                                    stockPieChartSectionsData.isNotEmpty
                                        ? PieChart(
                                          PieChartData(
                                            sections:
                                                stockPieChartSectionsData
                                                    .map(
                                                      (s) => s.copyWith(
                                                        showTitle:
                                                            s.value >
                                                            5, // 只有佔比較大時才在扇區上顯示文字
                                                        titleStyle: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                            centerSpaceRadius: 20, // 讓餅圖更大一些
                                            sectionsSpace: 1,
                                            startDegreeOffset:
                                                -90, // <--- 設定扇區從頂部開始
                                            pieTouchData: PieTouchData(
                                              touchCallback: (
                                                FlTouchEvent event,
                                                PieTouchResponse?
                                                pieTouchResponse,
                                              ) {
                                                setState(() {
                                                  if (!event
                                                          .isInterestedForInteractions ||
                                                      pieTouchResponse ==
                                                          null ||
                                                      pieTouchResponse
                                                              .touchedSection ==
                                                          null) {
                                                    _touchedIndexPieStock = -1;
                                                    return;
                                                  }
                                                  _touchedIndexPieStock =
                                                      pieTouchResponse
                                                          .touchedSection!
                                                          .touchedSectionIndex;
                                                });
                                              },
                                            ),
                                          ),
                                        )
                                        : const Center(child: Text('無數據')),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child:
                                  initialStockLegendData.isNotEmpty
                                      ? _buildLegend(
                                        initialStockLegendData,
                                        initialStockLegendColors,
                                      )
                                      : const SizedBox(
                                        height: 150,
                                        child: Center(child: Text("無圖例數據")),
                                      ), // 確保圖例區域有高度
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Divider(),
                        _buildChartSectionHeader(
                          title: '產業持倉比例',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => DetailedAllocationPage(
                                      title: '產業佔比詳情',
                                      allocationData: allIndustryAllocations,
                                      colors: industryPieColors,
                                    ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 150,
                                child:
                                    industryPieChartSectionsData.isNotEmpty
                                        ? PieChart(
                                          PieChartData(
                                            sections:
                                                industryPieChartSectionsData
                                                    .map(
                                                      (s) => s.copyWith(
                                                        showTitle: s.value > 5,
                                                        titleStyle: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                            centerSpaceRadius: 20,
                                            sectionsSpace: 1,
                                            startDegreeOffset:
                                                -90, // <--- 設定第一個扇區從頂部開始
                                            pieTouchData: PieTouchData(
                                              touchCallback: (
                                                FlTouchEvent event,
                                                PieTouchResponse?
                                                pieTouchResponse,
                                              ) {
                                                setState(() {
                                                  if (!event
                                                          .isInterestedForInteractions ||
                                                      pieTouchResponse ==
                                                          null ||
                                                      pieTouchResponse
                                                              .touchedSection ==
                                                          null) {
                                                    _touchedIndexPieIndustry =
                                                        -1;
                                                    return;
                                                  }
                                                  _touchedIndexPieIndustry =
                                                      pieTouchResponse
                                                          .touchedSection!
                                                          .touchedSectionIndex;
                                                });
                                              },
                                            ),
                                          ),
                                        )
                                        : const Center(child: Text('無數據')),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child:
                                  initialIndustryLegendData.isNotEmpty
                                      ? _buildLegend(
                                        initialIndustryLegendData,
                                        initialIndustryLegendColors,
                                      )
                                      : const SizedBox(
                                        height: 150,
                                        child: Center(child: Text("無圖例數據")),
                                      ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30.0),
                          child: Center(child: Text('當前投資組合無有效市值，無法繪製圖表。')),
                        ),
                        const Divider(),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                        child: Text(
                          '資產明細',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true, // 重要：讓 ListView 在 Column 中正確計算高度
                        physics:
                            const NeverScrollableScrollPhysics(), // 重要：禁用 ListView 自身的滾動，由 SingleChildScrollView 控制
                        itemCount: _aggregatedStockAssets.length, // 使用加總後的列表
                        itemBuilder: (context, index) {
                          // ... (你之前的 ListTile 程式碼)
                          final aggAsset = _aggregatedStockAssets[index];
                          // 顯示 aggAsset 的總股數、加權平均成本、目前價格、總市值、總損益等

                          return InkWell(
                            // 使用 InkWell 包裹 ListTile 以便整個區域可點擊並有水波紋效果
                            onTap: () async {
                              final bool?
                              needsRefresh = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => StockLotsDetailPage(
                                        symbol: aggAsset.symbol,
                                        name: aggAsset.name ?? aggAsset.symbol,
                                        initialLots: aggAsset.individualLots,
                                        currentPrice: aggAsset.currentPrice,
                                      ),
                                ),
                              );
                              if (needsRefresh == true && mounted) {
                                _refreshStockAssets();
                              }
                            },
                            // onLongPress: () async { /* ... 你的長按刪除邏輯 ... */ }, // 如果要保留長按刪除
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Expanded(
                                    // 左側資訊
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // --- 股票代號的膠囊背景 ---
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                            vertical: 3.0,
                                          ), // 膠囊的內邊距
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primaryContainer, // 使用 primaryContainer 作為背景色
                                            borderRadius: BorderRadius.circular(
                                              12.0,
                                            ), // 膠囊的圓角
                                          ),
                                          child: Text(
                                            aggAsset.symbol,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              // 可以用 bodySmall 或 caption
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer, // 膠囊內文字顏色
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 6,
                                        ), // 膠囊和公司名稱之間的間距

                                        Text(
                                          aggAsset.name ??
                                              aggAsset.symbol, // 如果沒有名稱，還是顯示代號
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2, // 公司名稱可能較長，允許換行
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '總股數: ${NumberFormat('#,##0.00##').format(aggAsset.totalShares)} @ 均價 \$${aggAsset.averageCostPrice.toStringAsFixed(2)}',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                        ),
                                        if (aggAsset.industry != null &&
                                            aggAsset.industry!.isNotEmpty)
                                          Padding(
                                            // 給產業文字一點上邊距
                                            padding: const EdgeInsets.only(
                                              top: 2.0,
                                            ),
                                            child: Text(
                                              '產業: ${aggAsset.industry}',
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16), // 左右資訊間隔
                                  Column(
                                    // 右側價格和損益資訊
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        ' \$${aggAsset.totalCurrentValue.toStringAsFixed(2)}', // 總市值
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '現價 \$${aggAsset.currentPrice.toStringAsFixed(2)}', // 目前股價
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.grey[600]),
                                      ),
                                      Text(
                                        '${aggAsset.totalProfitLoss >= 0 ? '+' : ''}${aggAsset.totalProfitLoss.toStringAsFixed(2)} (${aggAsset.totalProfitLossPercentage.toStringAsFixed(1)}%)',
                                        style: TextStyle(
                                          fontSize:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.fontSize,
                                          color:
                                              aggAsset.totalProfitLoss >= 0
                                                  ? Colors.green
                                                  : Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder:
                            (context, index) => const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ), // 添加分隔線
                      ),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditPage(),
        child: const Icon(Icons.add),
        tooltip: '新增股票資產',
      ),
    );
  }

  Widget _buildPortfolioSummaryCard(
    double totalCurrentValue,
    double totalOriginalCost,
  ) {
    final double totalProfitLoss = totalCurrentValue - totalOriginalCost;
    final double totalProfitLossPercentage =
        totalOriginalCost != 0
            ? (totalProfitLoss / totalOriginalCost) * 100
            : 0.0;
    // 預設貨幣符號和格式化
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final numberFormat = NumberFormat("#,##0.00", "en_US");

    // TODO: 加入眼睛圖示和資訊圖示的交互邏輯 (例如 bool _isValueVisible = true;)

    return Card(
      margin: const EdgeInsets.only(bottom: 20.0), // 與下方內容的間距
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- 頂部行 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: [
                    Text(
                      '總預估現值 (USD)', // TODO: 貨幣單位可以動態化
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 8),
                    // TODO: 眼睛圖示，點擊切換金額可見性
                    // Icon(Icons.visibility_outlined, size: 20, color: Colors.grey[700]),
                  ],
                ),
                // TODO: 資訊圖示，點擊顯示提示
                // Icon(Icons.info_outline, size: 20, color: Colors.grey[700]),
              ],
            ),
            const SizedBox(height: 8),

            // --- 中間行 (主要數據) ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline, // 讓主數字和百分比基線對齊
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  currencyFormat.format(totalCurrentValue),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    // color: Theme.of(context).colorScheme.onSurface, // 使用主題顏色
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${totalProfitLossPercentage >= 0 ? '+' : ''}${totalProfitLossPercentage.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
                    color:
                        totalProfitLossPercentage >= 0
                            ? Colors.green
                            : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            //const SizedBox(height: 16),
            //const Divider(), // 分隔線
            const SizedBox(height: 20),

            // --- 底部行 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // 左側：總成本
                Expanded(
                  // 使用 Expanded 確保即使文字長也能正確佈局
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '總成本',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(totalOriginalCost),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          // color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40, // 分隔線高度
                  width: 2,
                  color: Colors.grey[800],
                  margin: const EdgeInsets.symmetric(horizontal: 12.0),
                ),
                const SizedBox(width: 10), // 或者用 SizedBox 做間隔
                // 右側：總預估損益
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // 左對齊
                    children: <Widget>[
                      Text(
                        '總預估損益',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${totalProfitLoss >= 0 ? '+' : ''}${currencyFormat.format(totalProfitLoss.abs())}', // 確保金額前有+/-，並且是絕對值
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color:
                              totalProfitLoss >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    List<MapEntry<String, double>> allocationData, // Key: 標籤, Value: 百分比
    List<Color> colors,
    int touchedIndex,
  ) {
    if (allocationData.isEmpty) return [];

    return List.generate(allocationData.length, (i) {
      final entry = allocationData[i];
      final percentage = entry.value;
      final color =
          colors.isNotEmpty && i < colors.length ? colors[i] : Colors.grey;

      final isTouched = i == touchedIndex;
      // final double fontSize = isTouched ? 16.0 : 12.0; // 如果不顯示 title，這個就不需要了
      final double radius = isTouched ? 70.0 : 60.0;

      if (percentage < 0.01) {
        return PieChartSectionData(
          color: Colors.transparent,
          value: 0.01,
          showTitle: false, // 確保不顯示標題
          radius: radius,
        );
      }

      return PieChartSectionData(
        color: color,
        value: percentage,
        // title: '${percentage.toStringAsFixed(1)}%', // <--- 將這一行註釋掉或移除
        title: '',
        showTitle: false, // <--- 或者明確設定 showTitle 為 false
        radius: radius,
      );
    });
  }
  /*
  Map<String, double> _getUniqueIndustriesAndValues() {
    final Map<String, double> industryValues = {};
    for (var asset in _stockAssets) {
      final industry =
          asset.industry?.isNotEmpty == true ? asset.industry! : '未分類';
      industryValues[industry] =
          (industryValues[industry] ?? 0) + asset.currentValue;
    }
    return industryValues;
  }
  */

  Widget _buildChartSectionHeader({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 12.0,
          horizontal: 8.0,
        ), // 調整padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ), // 加粗標題
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.primary,
            ), // 使用主題色
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(
    List<MapEntry<String, double>> legendData,
    List<Color> colors,
  ) {
    if (legendData.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(child: Text("無數據生成圖例")),
      ); // 或者其他提示
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(legendData.length, (i) {
        final entry = legendData[i];
        final label = entry.key;
        final percentage = entry.value;
        final color =
            colors.isNotEmpty && i < colors.length ? colors[i] : Colors.grey;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0), // 調整垂直間距
          child: Row(
            children: <Widget>[
              Container(
                width: 10, // 顏色標識點大小
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall, // 使用小一點的字體
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${percentage.toStringAsFixed(2)}%',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }),
    );
  }
}
