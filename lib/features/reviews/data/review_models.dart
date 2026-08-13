class UserReview {
  const UserReview({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.orderItemId,
    required this.rating,
    required this.content,
    required this.status,
    this.reviewerName = '',
    this.createTime,
    this.updateTime,
  });

  factory UserReview.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('评价响应格式不正确');
    }
    final id = (json['id'] as num?)?.toInt();
    final orderItemId = (json['orderItemId'] as num?)?.toInt();
    if (id == null || orderItemId == null) {
      throw const FormatException('评价响应缺少必要标识');
    }
    return UserReview(
      id: id,
      bookId: (json['bookId'] as num?)?.toInt() ?? 0,
      bookTitle: json['bookTitle'] as String? ?? '',
      orderItemId: orderItemId,
      reviewerName: json['reviewerName'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 1,
      createTime: _date(json['createTime']),
      updateTime: _date(json['updateTime']),
    );
  }

  final int id;
  final int bookId;
  final String bookTitle;
  final int orderItemId;
  final String reviewerName;
  final int rating;
  final String content;
  final int status;
  final DateTime? createTime;
  final DateTime? updateTime;
}

DateTime? _date(dynamic value) {
  return value is String ? DateTime.tryParse(value) : null;
}
