import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/crypto_currency.dart';
import '../models/crypto_detail.dart';

class CryptoApiService {
  final String _baseUrl = "https://api.coingecko.com/api/v3";

  Future<List<CryptoCurrency>> getMarketData({String currency = 'usd', int perPage = 100, int page = 1}) async {
    final String url = "$_baseUrl/coins/markets?vs_currency=$currency&order=market_cap_desc&per_page=$perPage&page=$page&sparkline=false";
    print("Fetching market data from: $url");

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        List<CryptoCurrency> cryptoList = jsonList.map((jsonItem) => CryptoCurrency.fromJson(jsonItem)).toList();
        print("Market data fetched successfully: ${cryptoList.length} items");
        return cryptoList;
      } else {
        print("Failed to load market data. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception('Failed to load market data (Status code: ${response.statusCode})');
      }
    } catch (e) {
      print("Error fetching market data: $e");
      throw Exception('Error fetching market data: $e');
    }
  }

  Future<CryptoDetail> getCoinDetail(String coinId) async {
    final String url = "$_baseUrl/coins/$coinId?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false";
    print("Fetching coin detail from: $url");

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final cryptoDetail = CryptoDetail.fromJson(jsonData);
        print("Coin detail for $coinId fetched successfully.");
        return cryptoDetail;
      } else {
        print("Failed to load coin detail for $coinId. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception('Failed to load coin detail (Status code: ${response.statusCode})');
      }
    } catch (e) {
      print("Error fetching coin detail for $coinId: $e");
      throw Exception('Error fetching coin detail: $e');
    }
  }

  Future<List<List<num>>> getCoinMarketChart(String coinId, {String vsCurrency = 'usd', String days = '7'}) async {
    final String url = "$_baseUrl/coins/$coinId/market_chart?vs_currency=$vsCurrency&days=$days";
    print("Fetching market chart for $coinId from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> pricesData = data['prices'];
        final List<List<num>> prices = pricesData.map((item) => List<num>.from(item)).toList();
        print("Market chart for $coinId fetched successfully.");
        return prices;
      } else {
        print("Failed to load market chart for $coinId. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception('Failed to load market chart (Status code: ${response.statusCode})');
      }
    } catch (e) {
      print("Error fetching market chart for $coinId: $e");
      throw Exception('Error fetching market chart: $e');
    }
  }

  Future<List<List<num>>> getCoinOHLCData(
    String coinId, {
    String vsCurrency = 'usd',
    String days = '7',
  }) async {
    final String url = "$_baseUrl/coins/$coinId/ohlc?vs_currency=$vsCurrency&days=$days";
    print("Fetching OHLC data for $coinId ($days days) from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<List<num>> ohlcData = data.map((item) => List<num>.from(item)).toList();
        print("OHLC data for $coinId fetched successfully. Items: ${ohlcData.length}");
        return ohlcData;
      } else {
        print("Failed to load OHLC data for $coinId. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception('Failed to load OHLC data (Status code: ${response.statusCode})');
      }
    } catch (e) {
      print("Error fetching OHLC data for $coinId: $e");
      throw Exception('Error fetching OHLC data: $e');
    }
  }
}