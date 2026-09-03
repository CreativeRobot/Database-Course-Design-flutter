import '../../cart/data/bundle_models.dart';

class BookPromotion {
  const BookPromotion({required this.id, required this.name, required this.discountPercent, this.description, this.startTime, this.endTime});
  factory BookPromotion.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return BookPromotion(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      discountPercent: (map['discountPercent'] as num?)?.toInt() ?? 0,
      startTime: DateTime.tryParse(map['startTime'] as String? ?? ''),
      endTime: DateTime.tryParse(map['endTime'] as String? ?? ''),
    );
  }
  final int id;
  final String name;
  final String? description;
  final int discountPercent;
  final DateTime? startTime;
  final DateTime? endTime;
  String get discountLabel => '${(discountPercent / 10).toStringAsFixed(discountPercent % 10 == 0 ? 0 : 1)}折';
}

class PromotionBook {
  const PromotionBook({
    required this.id,
    required this.title,
    required this.salePrice,
    required this.baseSalePrice,
    this.coverUrl,
    this.promotion,
  });

  factory PromotionBook.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return PromotionBook(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? '',
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0,
      baseSalePrice: (map['baseSalePrice'] as num?)?.toDouble() ?? 0,
      coverUrl: map['coverUrl'] as String?,
      promotion: map['promotion'] == null ? null : BookPromotion.fromJson(map['promotion']),
    );
  }

  final int id;
  final String title;
  final double salePrice;
  final double baseSalePrice;
  final String? coverUrl;
  final BookPromotion? promotion;
}

class PromotionHome {
  const PromotionHome({this.discountedBooks = const [], this.bundles = const []});
  factory PromotionHome.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return PromotionHome(
      discountedBooks: (map['discountedBooks'] as List? ?? const []).map(PromotionBook.fromJson).toList(growable: false),
      bundles: (map['bundles'] as List? ?? const []).map(BookBundle.fromJson).toList(growable: false),
    );
  }
  final List<PromotionBook> discountedBooks;
  final List<BookBundle> bundles;
}
