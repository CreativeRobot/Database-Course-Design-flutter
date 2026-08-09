class Book {
  const Book({
    required this.id,
    required this.isbn,
    required this.title,
    required this.publisherId,
    required this.publisherName,
    required this.originalPrice,
    required this.salePrice,
    required this.stock,
    required this.status,
    this.coverUrl,
  });

  factory Book.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('图书响应格式不正确');
    }
    return Book(
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
}
