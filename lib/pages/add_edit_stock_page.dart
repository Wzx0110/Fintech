import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/stock_asset.dart';
import '../helpers/database_helper.dart';
import '../services/stock_api_service.dart';

class AddEditStockPage extends StatefulWidget {
  final StockAsset? asset;
  final String userId;

  const AddEditStockPage({super.key, this.asset, required this.userId});

  @override
  State<AddEditStockPage> createState() => _AddEditStockPageState();
}

class _AddEditStockPageState extends State<AddEditStockPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _symbolController;
  late TextEditingController _sharesController;
  late TextEditingController _avgCostController;
  late TextEditingController _industryController;
  DateTime _selectedDate = DateTime.now();
  String? _stockNameFromApi;
  bool _isLoadingName = false;

  final StockApiService _stockApiService = StockApiService();

  bool get _isEditing => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final initialAsset = widget.asset;
    _symbolController = TextEditingController(text: initialAsset?.symbol ?? '');
    _sharesController = TextEditingController(
      text: initialAsset?.shares.toString() ?? '',
    );
    _avgCostController = TextEditingController(
      text: initialAsset?.avgCostPrice.toString() ?? '',
    );
    _industryController = TextEditingController(
      text: initialAsset?.industry ?? '',
    );
    _selectedDate = initialAsset?.purchaseDate ?? DateTime.now();

    if (_isEditing && initialAsset?.name != null) {
      _stockNameFromApi = initialAsset!.name;
    } else if (initialAsset?.symbol != null && initialAsset!.symbol!.isNotEmpty) {
      _fetchStockName(initialAsset!.symbol!);
    }
    _symbolController.addListener(() {
      if (_symbolController.text.isNotEmpty) {
        _fetchStockName(_symbolController.text);
      } else {
        setState(() {
          _stockNameFromApi = null;
        });
      }
    });
  }

  Future<void> _fetchStockName(String symbol) async {
    if (symbol.isEmpty) return;
    setState(() {
      _isLoadingName = true;
      _stockNameFromApi = null;
    });
    try {
      final profile = await _stockApiService.getCompanyProfile(symbol);
      if (mounted) {
        setState(() {
          _stockNameFromApi = profile?['name'] as String?;
          _isLoadingName = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingName = false;
        });
      }
      print("Error fetching stock name for $symbol: $e");
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveAsset() async {
    if (_formKey.currentState!.validate()) {
      final symbol = _symbolController.text.toUpperCase();
      final shares = double.tryParse(_sharesController.text) ?? 0.0;
      final avgCostPrice = double.tryParse(_avgCostController.text) ?? 0.0;
      final industry = _industryController.text;

      if (shares <= 0 || avgCostPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('股數和成本價必須大於0')));
        return;
      }

      final newAsset = StockAsset(
        id: widget.asset?.id,
        symbol: symbol,
        name: _stockNameFromApi,
        shares: shares,
        avgCostPrice: avgCostPrice,
        purchaseDate: _selectedDate,
        industry: industry.isNotEmpty ? industry : null,
      );

      try {
        if (_isEditing) {
          await DatabaseHelper.instance.update(newAsset, widget.userId);
        } else {
          await DatabaseHelper.instance.create(newAsset, widget.userId);
        }
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存資產失敗: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _sharesController.dispose();
    _avgCostController.dispose();
    _industryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯股票資產' : '新增股票資產'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveAsset),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _symbolController,
                decoration: InputDecoration(
                  labelText: '股票代號 (例如: AAPL, TSLA)',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入股票代號';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sharesController,
                decoration: const InputDecoration(labelText: '持有股數'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入持有股數';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return '請輸入有效的股數';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _avgCostController,
                decoration: const InputDecoration(labelText: '平均成本價 (每股)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入平均成本價';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return '請輸入有效的成本價';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '購買日期: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(context),
                    child: const Text('選擇日期'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _industryController,
                decoration: const InputDecoration(labelText: '產業分類 (可選)'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveAsset,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _isEditing ? '儲存變更' : '新增資產',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}