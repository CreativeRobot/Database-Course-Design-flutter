import '../../../core/utils/media_url.dart';

class BundleItem {
  const BundleItem({required this.bookId, required this.title, this.isbn = '', this.coverUrl, this.salePrice = 0});
  factory BundleItem.fromJson(dynamic json) => BundleItem(
    bookId: (json['bookId'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    isbn: json['isbn'] as String? ?? '',
    coverUrl: json['coverUrl'] as String?,
    salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
  );
  final int bookId;
  final String title;
  final String isbn;
  final String? coverUrl;
  final double salePrice;
}

class BookBundle {
  const BookBundle({required this.id, required this.name, required this.bundlePrice, required this.regularAmount, required this.savings, required this.items, this.description, this.status, this.version, this.priceValid, this.purchasable, this.unavailableReason});
  factory BookBundle.fromJson(dynamic json) => BookBundle(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    bundlePrice: (json['bundlePrice'] as num?)?.toDouble() ?? 0,
    regularAmount: (json['regularAmount'] as num?)?.toDouble() ?? 0,
    savings: (json['savings'] as num?)?.toDouble() ?? 0,
    items: (json['items'] is List) ? (json['items'] as List).map(BundleItem.fromJson).toList(growable: false) : const [],
    status: json['status'] as String?, version: (json['version'] as num?)?.toInt(),
    priceValid: json['priceValid'] as bool?, purchasable: json['purchasable'] as bool?, unavailableReason: json['unavailableReason'] as String?,
  );
  final int id; final String name; final String? description; final double bundlePrice; final double regularAmount; final double savings; final List<BundleItem> items; final String? status; final int? version; final bool? priceValid; final bool? purchasable; final String? unavailableReason;
}

class CartBundle {
  const CartBundle({required this.id, required this.name, required this.bundlePrice, required this.regularAmount, required this.savings, required this.items, required this.applied});
  factory CartBundle.fromJson(dynamic json) => CartBundle(
    id: (json['id'] as num?)?.toInt() ?? 0, name: json['name'] as String? ?? '',
    bundlePrice: (json['bundlePrice'] as num?)?.toDouble() ?? 0, regularAmount: (json['regularAmount'] as num?)?.toDouble() ?? 0,
    savings: (json['savings'] as num?)?.toDouble() ?? 0, applied: json['applied'] as bool? ?? false,
    items: (json['items'] is List) ? (json['items'] as List).map(BundleItem.fromJson).toList(growable: false) : const [],
  );
  final int id; final String name; final double bundlePrice; final double regularAmount; final double savings; final List<BundleItem> items; final bool applied;
}
