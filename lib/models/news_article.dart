class NewsArticleSource {
  final String? id;
  final String name;

  NewsArticleSource({this.id, required this.name});

  factory NewsArticleSource.fromJson(Map<String, dynamic> json) {
    return NewsArticleSource(
      id: json['id'] as String?,
      name: json['name'] as String,
    );
  }
}

class NewsArticle {
  final NewsArticleSource? source;
  final String? author;
  final String title;
  final String? description;
  final String url;
  final String? urlToImage;
  final DateTime? publishedAt;
  final String? content;

  NewsArticle({
    this.source,
    this.author,
    required this.title,
    this.description,
    required this.url,
    this.urlToImage,
    this.publishedAt,
    this.content,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      source: json['source'] != null ? NewsArticleSource.fromJson(json['source']) : null,
      author: json['author'] as String?,
      title: json['title'] as String? ?? 'No Title',
      description: json['description'] as String?,
      url: json['url'] as String? ?? '',
      urlToImage: json['urlToImage'] as String?,
      publishedAt: json['publishedAt'] != null ? DateTime.tryParse(json['publishedAt']) : null,
      content: json['content'] as String?,
    );
  }
}
