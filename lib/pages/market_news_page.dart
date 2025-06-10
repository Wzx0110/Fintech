import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/news_api_service.dart';
import '../models/news_article.dart';

class MarketNewsPage extends StatefulWidget {
  const MarketNewsPage({super.key});

  @override
  State<MarketNewsPage> createState() => _MarketNewsPageState();
}

class _MarketNewsPageState extends State<MarketNewsPage> {
  late Future<List<NewsArticle>> _newsFuture;
  final NewsApiService _apiService = NewsApiService();
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews({String? query}) async {
    setState(() {
      _newsFuture = Future.value([]);
      if (query != null) {
        _currentQuery = query;
        _newsFuture = _apiService.searchNews(query: query);
      } else {
        _currentQuery = '';
        _newsFuture = _apiService.getTopHeadlines(
          category: 'business',
        );
      }
    });
    _newsFuture.catchError((error) {
      if (mounted) {
      }
      return <NewsArticle>[];
    });
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('無法打開連結: $urlString')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('市場資訊'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜尋新聞關鍵字...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                    onSubmitted: (query) {
                      if (query.isNotEmpty) {
                        _loadNews(query: query);
                      }
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _loadNews();
                    },
                  ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _loadNews(query: _searchController.text);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNews(query: _currentQuery.isEmpty ? null : _currentQuery),
        child: FutureBuilder<List<NewsArticle>>(
          future: _newsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 60),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '無法載入新聞: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _loadNews(query: _currentQuery.isEmpty ? null : _currentQuery),
                      child: Text("重試"),
                    ),
                  ],
                ),
              );
            } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final articles = snapshot.data!;
              return ListView.builder(
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: article.urlToImage != null
                          ? SizedBox(
                              width: 100,
                              height: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  article.urlToImage!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 40, color: Colors.grey[400]),
                                ),
                              ),
                            )
                          : null,
                      title: Text(
                        article.title,
                        style: TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (article.description != null && article.description!.isNotEmpty)
                            Text(
                              article.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  article.source?.name ?? '未知來源',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (article.publishedAt != null)
                                Text(
                                  DateFormat('yyyy-MM-dd HH:mm').format(article.publishedAt!),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () {
                        if (article.url.isNotEmpty) {
                          _launchURL(article.url);
                        }
                      },
                    ),
                  );
                },
              );
            } else {
              return const Center(child: Text('沒有找到相關新聞'));
            }
          },
        ),
      ),
    );
  }
}