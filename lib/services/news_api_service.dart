import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';

class NewsApiService {
  final String _baseUrl = "https://newsapi.org/v2";
  final String _apiKey = "972bfaab44e14cb995f79ef2ad5d6f6d";

  Future<List<NewsArticle>> getTopHeadlines({String country = 'us', String category = 'business', int pageSize = 20}) async {
    if (_apiKey == "YOUR_NEWS_API_KEY" || _apiKey.isEmpty) {
      print("News API Key is not set. Please obtain a key from newsapi.org and set it in news_api_service.dart");
      throw Exception('News API Key not set');
    }
    final String url = "$_baseUrl/top-headlines?country=$country&category=$category&pageSize=$pageSize&apiKey=$_apiKey";
    print("Fetching top headlines from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['status'] == 'ok') {
          List<dynamic> articlesJson = jsonData['articles'];
          List<NewsArticle> articles = articlesJson.map((jsonItem) => NewsArticle.fromJson(jsonItem)).toList();
          print("Top headlines fetched successfully: ${articles.length} items");
          return articles;
        } else {
          print("News API returned error: ${jsonData['message']}");
          throw Exception('News API error: ${jsonData['message']}');
        }
      } else {
        print("Failed to load top headlines. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception('Failed to load top headlines (Status code: ${response.statusCode})');
      }
    } catch (e) {
      print("Error fetching top headlines: $e");
      throw Exception('Error fetching top headlines: $e');
    }
  }

  Future<List<NewsArticle>> searchNews({required String query, int pageSize = 20, String sortBy = 'publishedAt'}) async {
    if (_apiKey == "YOUR_NEWS_API_KEY" || _apiKey.isEmpty) {
      print("News API Key is not set.");
      throw Exception('News API Key not set');
    }
    final String encodedQuery = Uri.encodeComponent(query);
    final String url = "$_baseUrl/everything?q=$encodedQuery&pageSize=$pageSize&sortBy=$sortBy&apiKey=$_apiKey";
    print("Searching news for '$query' from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['status'] == 'ok') {
          List<dynamic> articlesJson = jsonData['articles'];
          List<NewsArticle> articles = articlesJson.map((jsonItem) => NewsArticle.fromJson(jsonItem)).toList();
          print("Search results for '$query' fetched successfully: ${articles.length} items");
          return articles;
        } else {
          print("News API search returned error: ${jsonData['message']}");
          throw Exception('News API search error: ${jsonData['message']}');
        }
      } else {
        print("Failed to search news. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception('Failed to search news (Status code: ${response.statusCode})');
      }
    } catch (e) {
      print("Error searching news: $e");
      throw Exception('Error searching news: $e');
    }
  }
}