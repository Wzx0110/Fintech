import 'dart:convert';
import 'package:http/http.dart' as http;

class StockApiService {
  final String _baseUrl = "https://finnhub.io/api/v1";
  final String _apiKey = "d0pipl9r01qgccu9crcgd0pipl9r01qgccu9crd0";

  Future<Map<String, dynamic>?> getQuote(String symbol) async {
    final url = Uri.parse("$_baseUrl/quote?symbol=$symbol&token=$_apiKey");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data.containsKey('c') && data['c'] != null) {
          return data;
        }
        return null;
      } else {
        print("Failed to load quote for $symbol: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching quote for $symbol: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCompanyProfile(String symbol) async {
    final url = Uri.parse("$_baseUrl/stock/profile2?symbol=$symbol&token=$_apiKey");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data.isNotEmpty) {
          return data;
        }
        return null;
      } else {
        print("Failed to load profile for $symbol: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching profile for $symbol: $e");
      return null;
    }
  }
}