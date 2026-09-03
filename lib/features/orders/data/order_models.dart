class BookOrder {
  const BookOrder({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.totalAmount,
    required this.discountAmount,
    required this.shippingFee,
    required this.payableAmount,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverAddress,
    required this.remark,
    required this.items,
    this.bundles = const [],
    this.expireTime,
    this.createTime,
    this.updateTime,
    this.paidTime,
    this.shippedTime,
    this.completedTime,
    this.cancelledTime,
  });

  factory BookOrder.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('订单响应格式不正确');
    }
    final rawItems = json['items'];
    final rawBundles = json['bundles'];
    return BookOrder(
      id: (json['id'] as num).toInt(),
      orderNo: json['orderNo'] as String? ?? '',
      status: json['status'] as String? ?? 'CANCELLED',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      shippingFee: (json['shippingFee'] as num?)?.toDouble() ?? 0,
      payableAmount: (json['payableAmount'] as num?)?.toDouble() ?? 0,
      expireTime: _date(json['expireTime']),
      receiverName: json['receiverName'] as String? ?? '',
      receiverPhone: json['receiverPhone'] as String? ?? '',
      receiverAddress: json['receiverAddress'] as String? ?? '',
      remark: json['remark'] as String? ?? '',
      createTime: _date(json['createTime']),
      updateTime: _date(json['updateTime']),
      paidTime: _date(json['paidTime']),
      shippedTime: _date(json['shippedTime']),
      completedTime: _date(json['completedTime']),
      cancelledTime: _date(json['cancelledTime']),
      items: rawItems is List
          ? rawItems.map(OrderLine.fromJson).toList(growable: false)
          : const [],
      bundles: rawBundles is List
          ? rawBundles
              .map(OrderBundleApplication.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  final int id;
  final String orderNo;
  final String status;
  final double totalAmount;
  final double discountAmount;
  final double shippingFee;
  final double payableAmount;
  final DateTime? expireTime;
  final String receiverName;
  final String receiverPhone;
  final String receiverAddress;
  final String remark;
  final DateTime? createTime;
  final DateTime? updateTime;
  final DateTime? paidTime;
  final DateTime? shippedTime;
  final DateTime? completedTime;
  final DateTime? cancelledTime;
  final List<OrderLine> items;
  final List<OrderBundleApplication> bundles;

  bool get canPay => status == 'PENDING_PAYMENT';
  bool get canCancel => status == 'PENDING_PAYMENT';
  bool get canConfirmReceipt => status == 'SHIPPED';
}

class OrderLine {
  const OrderLine({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.isbn,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.discountAmount = 0,
    this.paidSubtotal = 0,
    this.preSale = false,
    this.preSaleReleaseTime,
  });

  factory OrderLine.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('订单商品响应格式不正确');
    }
    return OrderLine(
      id: (json['id'] as num).toInt(),
      bookId: (json['bookId'] as num).toInt(),
      bookTitle: json['bookTitle'] as String? ?? '',
      isbn: json['isbn'] as String? ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      paidSubtotal: (json['paidSubtotal'] as num?)?.toDouble() ?? 0,
      preSale: json['preSale'] as bool? ?? false,
      preSaleReleaseTime: _date(json['preSaleReleaseTime']),
    );
  }

  final int id;
  final int bookId;
  final String bookTitle;
  final String isbn;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final double discountAmount;
  final double paidSubtotal;
  final bool preSale;
  final DateTime? preSaleReleaseTime;
}

class OrderBundleApplication {
  const OrderBundleApplication({
    required this.id,
    required this.bundleId,
    required this.bundleName,
    required this.bundlePrice,
    required this.regularAmount,
    required this.discountAmount,
    required this.items,
  });

  factory OrderBundleApplication.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('订单组合包响应格式不正确');
    }
    final rawItems = json['items'];
    return OrderBundleApplication(
      id: (json['id'] as num?)?.toInt() ?? 0,
      bundleId: (json['bundleId'] as num?)?.toInt() ?? 0,
      bundleName: json['bundleName'] as String? ?? '',
      bundlePrice: (json['bundlePrice'] as num?)?.toDouble() ?? 0,
      regularAmount: (json['regularAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      items: rawItems is List
          ? rawItems
              .map(OrderBundleApplicationItem.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  final int id;
  final int bundleId;
  final String bundleName;
  final double bundlePrice;
  final double regularAmount;
  final double discountAmount;
  final List<OrderBundleApplicationItem> items;
}

class OrderBundleApplicationItem {
  const OrderBundleApplicationItem({
    required this.orderItemId,
    required this.bookId,
    required this.bookTitle,
    required this.isbn,
    required this.salePrice,
    required this.allocatedDiscount,
    required this.quantity,
  });

  factory OrderBundleApplicationItem.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('订单组合包商品响应格式不正确');
    }
    return OrderBundleApplicationItem(
      orderItemId: (json['orderItemId'] as num?)?.toInt(),
      bookId: (json['bookId'] as num?)?.toInt() ?? 0,
      bookTitle: json['bookTitle'] as String? ?? '',
      isbn: json['isbn'] as String? ?? '',
      salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
      allocatedDiscount:
          (json['allocatedDiscount'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  final int? orderItemId;
  final int bookId;
  final String bookTitle;
  final String isbn;
  final double salePrice;
  final double allocatedDiscount;
  final int quantity;
}

class PaymentResult {
  const PaymentResult({
    required this.id,
    required this.paymentNo,
    required this.orderId,
    required this.orderNo,
    required this.paymentMethod,
    required this.amount,
    required this.status,
    this.paidTime,
    this.createTime,
  });

  factory PaymentResult.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('支付响应格式不正确');
    }
    return PaymentResult(
      id: (json['id'] as num).toInt(),
      paymentNo: json['paymentNo'] as String? ?? '',
      orderId: (json['orderId'] as num).toInt(),
      orderNo: json['orderNo'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String? ?? 'MOCK',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'FAILED',
      paidTime: _date(json['paidTime']),
      createTime: _date(json['createTime']),
    );
  }

  final int id;
  final String paymentNo;
  final int orderId;
  final String orderNo;
  final String paymentMethod;
  final double amount;
  final String status;
  final DateTime? paidTime;
  final DateTime? createTime;
}

DateTime? _date(dynamic value) {
  return value is String ? DateTime.tryParse(value) : null;
}