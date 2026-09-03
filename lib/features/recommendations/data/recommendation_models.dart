class RecommendationHome {
  const RecommendationHome({
    required this.source,
    required this.books,
    this.page = 1,
    this.size = 12,
    this.hasMore = false,
  });

  factory RecommendationHome.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('推荐响应格式不正确');
    }
    final books = json['books'];
    if (books is! List) {
      throw const FormatException('推荐图书格式不正确');
    }
    return RecommendationHome(
      source: json['source'] as String? ?? 'POPULAR',
      books: books.map(RecommendationBook.fromJson).toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? books.length,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }

  final String source;
  final List<RecommendationBook> books;
  final int page;
  final int size;
  final bool hasMore;

  bool get isPersonalized => source == 'PERSONALIZED';
}

class RecommendationBook {
  const RecommendationBook({
    required this.id,
    required this.isbn,
    required this.title,
    required this.publisherId,
    required this.publisherName,
    required this.originalPrice,
    required this.salePrice,
    required this.stock,
    required this.status,
    required this.reason,
    this.coverUrl,
  });

  factory RecommendationBook.fromJson(dynamic json) {
    if (json is! Map<String, dynamic> || json['id'] is! num) {
      throw const FormatException('推荐图书格式不正确');
    }
    return RecommendationBook(
      id: (json['id'] as num).toInt(),
      isbn: json['isbn'] as String? ?? '',
      title: json['title'] as String? ?? '',
      publisherId: (json['publisherId'] as num?)?.toInt() ?? 0,
      publisherName: json['publisherName'] as String? ?? '',
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? 0,
      salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'OFF_SALE',
      coverUrl: json['coverUrl'] as String?,
      reason: json['reason'] as String? ?? '',
    );
  }

  final int id;
  final String isbn;
  final String title;
  final int publisherId;
  final String publisherName;
  final double originalPrice;
  final double salePrice;
  final int stock;
  final String status;
  final String? coverUrl;
  final String reason;
}
