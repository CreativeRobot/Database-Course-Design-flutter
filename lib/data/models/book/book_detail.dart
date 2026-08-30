import 'book.dart';

class BookDetail extends Book {
  const BookDetail({
    required super.id,
    required super.isbn,
    required super.title,
    required super.publisherId,
    required super.publisherName,
    required super.originalPrice,
    required super.salePrice,
    required super.stock,
    required super.status,
    super.coverUrl,
    super.preSale,
    super.preSaleReleaseTime,
    this.publishDate,
    this.edition,
    this.pages,
    this.description,
    this.createTime,
    this.updateTime,
    this.authors = const [],
    this.categories = const [],
  });

  factory BookDetail.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('图书详情响应格式不正确');
    }
    return BookDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      isbn: json['isbn'] as String? ?? '',
      title: json['title'] as String? ?? '',
      publisherId: (json['publisherId'] as num?)?.toInt() ?? 0,
      publisherName: json['publisherName'] as String? ?? '',
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? 0,
      salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'OFF_SALE',
      coverUrl: json['coverUrl'] as String?,
      preSale: json['preSale'] as bool? ?? false,
      preSaleReleaseTime: DateTime.tryParse(
        json['preSaleReleaseTime'] as String? ?? '',
      ),
      publishDate: json['publishDate'] as String?,
      edition: json['edition'] as String?,
      pages: (json['pages'] as num?)?.toInt(),
      description: json['description'] as String?,
      createTime: json['createTime'] as String?,
      updateTime: json['updateTime'] as String?,
      authors: _readNamedItems(json['authors']),
      categories: _readNamedItems(json['categories']),
    );
  }

  final String? publishDate;
  final String? edition;
  final int? pages;
  final String? description;
  final String? createTime;
  final String? updateTime;
  final List<BookNamedItem> authors;
  final List<BookNamedItem> categories;
}

class BookNamedItem {
  const BookNamedItem({required this.id, required this.name});

  factory BookNamedItem.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('图书关联信息格式不正确');
    }
    return BookNamedItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  final int id;
  final String name;
}

List<BookNamedItem> _readNamedItems(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value.map(BookNamedItem.fromJson).toList(growable: false);
}
