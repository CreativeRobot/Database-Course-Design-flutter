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
    );
  }

  final int id;
  final int bookId;
  final String bookTitle;
  final String isbn;
  final double unitPrice;
  final int quantity;
  final double subtotal;
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
