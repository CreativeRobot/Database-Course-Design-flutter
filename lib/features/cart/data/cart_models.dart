class CartItem {
  const CartItem({
    required this.id,
    required this.bookId,
    required this.isbn,
    required this.title,
    required this.coverUrl,
    required this.salePrice,
    required this.stock,
    required this.bookStatus,
    required this.quantity,
    required this.selected,
    required this.available,
    required this.subtotal,
    this.createTime,
    this.updateTime,
  });

  factory CartItem.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('购物车商品响应格式不正确');
    }
    return CartItem(
      id: (json['id'] as num).toInt(),
      bookId: (json['bookId'] as num).toInt(),
      isbn: json['isbn'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      bookStatus: json['bookStatus'] as String? ?? 'OFF_SALE',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      selected: json['selected'] as bool? ?? false,
      available: json['available'] as bool? ?? false,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      createTime: DateTime.tryParse(json['createTime'] as String? ?? ''),
      updateTime: DateTime.tryParse(json['updateTime'] as String? ?? ''),
    );
  }

  final int id;
  final int bookId;
  final String isbn;
  final String title;
  final String? coverUrl;
  final double salePrice;
  final int stock;
  final String bookStatus;
  final int quantity;
  final bool selected;
  final bool available;
  final double subtotal;
  final DateTime? createTime;
  final DateTime? updateTime;
}

class ShoppingCart {
  const ShoppingCart({
    required this.items,
    required this.totalQuantity,
    required this.selectedQuantity,
    required this.selectedAmount,
  });

  factory ShoppingCart.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('购物车响应格式不正确');
    }
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('购物车响应缺少商品列表');
    }
    return ShoppingCart(
      items: rawItems.map(CartItem.fromJson).toList(growable: false),
      totalQuantity: (json['totalQuantity'] as num?)?.toInt() ?? 0,
      selectedQuantity: (json['selectedQuantity'] as num?)?.toInt() ?? 0,
      selectedAmount: (json['selectedAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  static const empty = ShoppingCart(
    items: [],
    totalQuantity: 0,
    selectedQuantity: 0,
    selectedAmount: 0,
  );

  final List<CartItem> items;
  final int totalQuantity;
  final int selectedQuantity;
  final double selectedAmount;

  List<CartItem> get selectedItems =>
      items.where((item) => item.selected).toList(growable: false);

  bool get allSelected =>
      items.isNotEmpty && items.every((item) => item.selected);

  bool get canCheckout =>
      selectedItems.isNotEmpty && selectedItems.every((item) => item.available);
}
