enum RefundType {
  refundOnly('REFUND_ONLY', '仅退款'),
  returnRefund('RETURN_REFUND', '退货退款');

  const RefundType(this.code, this.label);

  final String code;
  final String label;

  static RefundType fromCode(String? code) => switch (code) {
    'RETURN_REFUND' => RefundType.returnRefund,
    _ => RefundType.refundOnly,
  };
}

enum RefundStatus {
  pending('PENDING', '待审核'),
  approved('APPROVED', '已通过'),
  rejected('REJECTED', '已驳回'),
  unknown('UNKNOWN', '状态未知');

  const RefundStatus(this.code, this.label);

  final String code;
  final String label;

  static RefundStatus fromCode(String? code) => switch (code) {
    'PENDING' => RefundStatus.pending,
    'APPROVED' => RefundStatus.approved,
    'REJECTED' => RefundStatus.rejected,
    _ => RefundStatus.unknown,
  };
}

class RefundApplication {
  const RefundApplication({
    required this.orderItemId,
    required this.type,
    required this.quantity,
    required this.reason,
  });

  final int orderItemId;
  final RefundType type;
  final int quantity;
  final String reason;

  Map<String, dynamic> toJson() => {
    'orderItemId': orderItemId,
    'type': type.code,
    'quantity': quantity,
    'reason': reason.trim(),
  };
}

class CustomerRefundRequest {
  const CustomerRefundRequest({
    required this.id,
    required this.refundNo,
    required this.orderId,
    required this.orderNo,
    required this.orderItemId,
    required this.bookId,
    required this.bookTitle,
    required this.type,
    required this.status,
    required this.quantity,
    required this.itemQuantity,
    required this.refundedQuantity,
    required this.amount,
    required this.reason,
    required this.reviewRemark,
    this.reviewedTime,
    this.createTime,
  });

  factory CustomerRefundRequest.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('售后申请响应格式不正确');
    }
    final map = json;
    return CustomerRefundRequest(
      id: _integer(map['id']),
      refundNo: map['refundNo'] as String? ?? '',
      orderId: _integer(map['orderId']),
      orderNo: map['orderNo'] as String? ?? '',
      orderItemId: _integer(map['orderItemId']),
      bookId: _integer(map['bookId']),
      bookTitle: map['bookTitle'] as String? ?? '',
      type: RefundType.fromCode(map['type'] as String?),
      status: RefundStatus.fromCode(map['status'] as String?),
      quantity: _integer(map['quantity']),
      itemQuantity: _integer(map['itemQuantity']),
      refundedQuantity: _integer(map['refundedQuantity']),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      reason: map['reason'] as String? ?? '',
      reviewRemark: map['reviewRemark'] as String?,
      reviewedTime: _date(map['reviewedTime']),
      createTime: _date(map['createTime']),
    );
  }

  final int id;
  final String refundNo;
  final int orderId;
  final String orderNo;
  final int orderItemId;
  final int bookId;
  final String bookTitle;
  final RefundType type;
  final RefundStatus status;
  final int quantity;
  final int itemQuantity;
  final int refundedQuantity;
  final double amount;
  final String reason;
  final String? reviewRemark;
  final DateTime? reviewedTime;
  final DateTime? createTime;

  String get typeLabel => type.label;
  String get statusLabel => status.label;
  bool get isActive =>
      status == RefundStatus.pending || status == RefundStatus.approved;
}

int _integer(dynamic value) => (value as num?)?.toInt() ?? 0;

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;
