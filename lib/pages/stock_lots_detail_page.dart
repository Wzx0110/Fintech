import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/stock_asset.dart';
import '../helpers/database_helper.dart';
import 'add_edit_stock_page.dart';

class StockLotsDetailPage extends StatefulWidget { 
  final String symbol;
  final String name;
  final List<StockAsset> initialLots;
  final double currentPrice;

  const StockLotsDetailPage({
    super.key,
    required this.symbol,
    required this.name,
    required this.initialLots,
    required this.currentPrice,
  });

  @override
  State<StockLotsDetailPage> createState() => _StockLotsDetailPageState();
}

class _StockLotsDetailPageState extends State<StockLotsDetailPage> {
  late List<StockAsset> _lots;
  bool _needsRefreshPortfolioPage = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _lots = List.from(widget.initialLots);
    _lots.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    _getCurrentUserId();
  }

  void _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    } else {
      print("StockLotsDetailPage: Error - User not logged in.");
    }
  }

  Future<void> _refreshLots() async {
    if (!mounted) return;
  }

  Future<void> _fetchLotsForCurrentSymbol() async {
    if (!mounted || _currentUserId == null) return;
    final allAssets = await DatabaseHelper.instance.readAllAssets(_currentUserId!);
    if (mounted) {
      setState(() {
        _lots = allAssets.where((asset) => asset.symbol == widget.symbol).toList();
        _lots.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      });
    }
  }

  void _editLot(StockAsset lot) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('錯誤: 無法獲取用戶資訊')));
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditStockPage(
          asset: lot,
          userId: _currentUserId!,
        ),
      ),
    );
    if (result == true && mounted) {
      _needsRefreshPortfolioPage = true;
      await _fetchLotsForCurrentSymbol();
    }
  }

  void _deleteLot(StockAsset lot) async {
    if (lot.id == null || _currentUserId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('您確定要刪除這筆 ${DateFormat('yyyy-MM-dd').format(lot.purchaseDate)} 購買的 ${lot.shares} 股 ${lot.symbol} 嗎？'),
          actions: <Widget>[
            TextButton(child: const Text('取消'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(child: Text('刪除', style: TextStyle(color: Colors.red[700])), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      try {
        await DatabaseHelper.instance.delete(lot.id!, _currentUserId!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lot.symbol} 的一筆記錄已刪除')),
        );
        _needsRefreshPortfolioPage = true;
        setState(() {
          _lots.removeWhere((item) => item.id == lot.id);
        });
        if (_lots.isEmpty) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _needsRefreshPortfolioPage);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.name} (${widget.symbol}) - 庫存明細'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, _needsRefreshPortfolioPage);
            },
          ),
        ),
        body: _lots.isEmpty
            ? const Center(child: Text('該股票已無庫存記錄。'))
            : ListView.builder(
                itemCount: _lots.length,
                itemBuilder: (context, index) {
                  final lot = _lots[index];
                  final lotCurrentValue = lot.shares * widget.currentPrice;
                  final lotTotalCost = lot.shares * lot.avgCostPrice;
                  final lotProfitLoss = lotCurrentValue - lotTotalCost;
                  final lotProfitLossPercent = lotTotalCost != 0 ? (lotProfitLoss / lotTotalCost) * 100 : 0.0;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '購買日期: ${DateFormat('yyyy-MM-dd').format(lot.purchaseDate)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (lot.industry != null && lot.industry!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('產業: ${lot.industry}', style: Theme.of(context).textTheme.bodySmall),
                            ),
                          const Divider(height: 16),
                          _buildDetailRow('股數:', NumberFormat('#,##0.00##').format(lot.shares)),
                          _buildDetailRow('成本價:', '\$${lot.avgCostPrice.toStringAsFixed(2)}'),
                          _buildDetailRow('總成本:', '\$${lotTotalCost.toStringAsFixed(2)}'),
                          const SizedBox(height: 8),
                          _buildDetailRow('目前市價:', '\$${widget.currentPrice.toStringAsFixed(2)}'),
                          _buildDetailRow('目前總值:', '\$${lotCurrentValue.toStringAsFixed(2)}'),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('預估損益:', style: TextStyle(color: Colors.grey[700])),
                              Text(
                                '${lotProfitLoss >= 0 ? '+' : ''}${lotProfitLoss.toStringAsFixed(2)} (${lotProfitLossPercent.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  color: lotProfitLoss >= 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.primary),
                                label: Text("編輯", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                onPressed: () => _editLot(lot),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: Icon(Icons.delete, size: 18, color: Colors.red[700]),
                                label: Text("刪除", style: TextStyle(color: Colors.red[700])),
                                onPressed: () => _deleteLot(lot),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}