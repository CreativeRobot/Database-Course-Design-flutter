import '../../../data/models/book/book.dart';
import '../../../data/models/book/book_detail.dart';
import '../../orders/data/order_models.dart';
import '../../reviews/data/review_models.dart';

class AdminStatistics {
  const AdminStatistics({
    required this.completedOrderCount,
    required this.salesAmount,
    required this.soldQuantity,
    required this.monthlySales,
    required this.dailySales,
    required this.topBooks,
    required this.categorySales,
    required this.lowStockBooks,
  });

  factory AdminStatistics.fromJson(dynamic json) {
    final map = _map(json, '统计');
    return AdminStatistics(
      completedOrderCount: _int(map['completedOrderCount']),
      salesAmount: _double(map['salesAmount']),
      soldQuantity: _int(map['soldQuantity']),
      monthlySales: _list(map['monthlySales'], MonthlySale.fromJson),
      dailySales: _list(map['dailySales'], DailySale.fromJson),
      topBooks: _list(map['topBooks'], BookSale.fromJson),
      categorySales: _list(map['categorySales'], CategorySale.fromJson),
      lowStockBooks: _list(map['lowStockBooks'], LowStockBook.fromJson),
    );
  }

  final int completedOrderCount;
  final double salesAmount;
  final int soldQuantity;
  final List<MonthlySale> monthlySales;
  final List<DailySale> dailySales;
  final List<BookSale> topBooks;
  final List<CategorySale> categorySales;
  final List<LowStockBook> lowStockBooks;
}

class MonthlySale {
  const MonthlySale(this.month, this.orders, this.quantity, this.amount);
  factory MonthlySale.fromJson(dynamic json) {
    final map = _map(json, '月度销售');
    return MonthlySale(
      map['saleMonth'] as String? ?? '',
      _int(map['completedOrderCount']),
      _int(map['soldQuantity']),
      _double(map['salesAmount']),
    );
  }
  final String month;
  final int orders;
  final int quantity;
  final double amount;
}

class DailySale {
  const DailySale(this.date, this.quantity, this.amount);
  factory DailySale.fromJson(dynamic json) {
    final map = _map(json, '每日销售');
    return DailySale(
      map['saleDate'] as String? ?? '',
      _int(map['soldQuantity']),
      _double(map['salesAmount']),
    );
  }

  final String date;
  final int quantity;
  final double amount;
}

class BookSale {
  const BookSale(this.id, this.name, this.quantity, this.amount);
  factory BookSale.fromJson(dynamic json) {
    final map = _map(json, '图书销售');
    return BookSale(
      _int(map['bookId']),
      map['bookTitle'] as String? ?? '',
      _int(map['soldQuantity']),
      _double(map['salesAmount']),
    );
  }
  final int id;
  final String name;
  final int quantity;
  final double amount;
}

class CategorySale {
  const CategorySale(this.id, this.name, this.quantity, this.amount);
  factory CategorySale.fromJson(dynamic json) {
    final map = _map(json, '分类销售');
    return CategorySale(
      _int(map['categoryId']),
      map['categoryName'] as String? ?? '',
      _int(map['soldQuantity']),
      _double(map['salesAmount']),
    );
  }
  final int id;
  final String name;
  final int quantity;
  final double amount;
}

class LowStockBook {
  const LowStockBook(this.id, this.isbn, this.title, this.stock, this.status);
  factory LowStockBook.fromJson(dynamic json) {
    final map = _map(json, '低库存图书');
    return LowStockBook(
      _int(map['bookId']),
      map['isbn'] as String? ?? '',
      map['title'] as String? ?? '',
      _int(map['stock']),
      map['status'] as String? ?? '',
    );
  }
  final int id;
  final String isbn;
  final String title;
  final int stock;
  final String status;
}

class AdminAuthor {
  const AdminAuthor({
    required this.id,
    required this.name,
    required this.country,
    required this.introduction,
  });
  factory AdminAuthor.fromJson(dynamic json) {
    final map = _map(json, '作者');
    return AdminAuthor(
      id: _int(map['id']),
      name: map['name'] as String? ?? '',
      country: map['country'] as String? ?? '',
      introduction: map['introduction'] as String? ?? '',
    );
  }
  final int id;
  final String name;
  final String country;
  final String introduction;
}

class AdminPublisher {
  const AdminPublisher({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.introduction,
  });
  factory AdminPublisher.fromJson(dynamic json) {
    final map = _map(json, '出版社');
    return AdminPublisher(
      id: _int(map['id']),
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      introduction: map['introduction'] as String? ?? '',
    );
  }
  final int id;
  final String name;
  final String phone;
  final String address;
  final String introduction;
}

class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.status,
    this.parentId,
    this.parentName,
    this.children = const [],
  });

  factory AdminCategory.fromJson(dynamic json) {
    final map = _map(json, '分类');
    return AdminCategory(
      id: _int(map['id']),
      name: map['name'] as String? ?? '',
      parentId: (map['parentId'] as num?)?.toInt(),
      parentName: map['parentName'] as String?,
      sortOrder: _int(map['sortOrder']),
      status: _int(map['status'], fallback: 1),
      children:
          (map['children'] as List?)
              ?.map(AdminCategory.fromJson)
              .toList(growable: false) ??
          const [],
    );
  }

  final int id;
  final String name;
  final int? parentId;
  final String? parentName;
  final List<AdminCategory> children;
  final int sortOrder;
  final int status;
}

class InventoryLog {
  const InventoryLog({
    required this.id,
    required this.bookId,
    required this.isbn,
    required this.bookTitle,
    required this.changeQuantity,
    required this.beforeStock,
    required this.afterStock,
    required this.changeType,
    required this.remark,
    required this.createTime,
    this.orderId,
    this.orderNo,
  });
  factory InventoryLog.fromJson(dynamic json) {
    final map = _map(json, '库存流水');
    return InventoryLog(
      id: _int(map['id']),
      bookId: _int(map['bookId']),
      isbn: map['isbn'] as String? ?? '',
      bookTitle: map['bookTitle'] as String? ?? '',
      changeQuantity: _int(map['changeQuantity']),
      beforeStock: _int(map['beforeStock']),
      afterStock: _int(map['afterStock']),
      changeType: map['changeType'] as String? ?? '',
      orderId: (map['orderId'] as num?)?.toInt(),
      orderNo: map['orderNo'] as String?,
      remark: map['remark'] as String? ?? '',
      createTime: DateTime.tryParse(map['createTime'] as String? ?? ''),
    );
  }
  final int id;
  final int bookId;
  final String isbn;
  final String bookTitle;
  final int changeQuantity;
  final int beforeStock;
  final int afterStock;
  final String changeType;
  final int? orderId;
  final String? orderNo;
  final String remark;
  final DateTime? createTime;
}

class UploadResult {
  const UploadResult(this.url, this.filename);
  factory UploadResult.fromJson(dynamic json) {
    final map = _map(json, '上传');
    return UploadResult(
      map['url'] as String? ?? '',
      map['filename'] as String? ?? '',
    );
  }
  final String url;
  final String filename;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.role,
    required this.status,
    required this.createTime,
    required this.updateTime,
  });

  factory AdminUser.fromJson(dynamic json) {
    final map = _map(json, '用户');
    return AdminUser(
      id: _int(map['id']),
      username: map['username'] as String? ?? '',
      nickname: map['nickname'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      role: map['role'] as String? ?? 'CUSTOMER',
      status: _int(map['status'], fallback: 1),
      createTime: DateTime.tryParse(map['createTime'] as String? ?? ''),
      updateTime: DateTime.tryParse(map['updateTime'] as String? ?? ''),
    );
  }

  final int id;
  final String username;
  final String nickname;
  final String email;
  final String phone;
  final String avatarUrl;
  final String role;
  final int status;
  final DateTime? createTime;
  final DateTime? updateTime;

  bool get isActive => status == 1;
  String get statusLabel => isActive ? '正常' : '已停用';
  String get roleLabel => role == 'ADMIN' ? '管理员' : '普通用户';
}

typedef AdminBook = Book;
typedef AdminBookDetail = BookDetail;
typedef AdminOrder = BookOrder;
typedef AdminReview = UserReview;

Map<String, dynamic> _map(dynamic value, String name) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$name响应格式不正确');
  }
  return value;
}

int _int(dynamic value, {int fallback = 0}) =>
    (value as num?)?.toInt() ?? fallback;
double _double(dynamic value) => (value as num?)?.toDouble() ?? 0;
List<T> _list<T>(dynamic value, T Function(dynamic) parser) =>
    value is List ? value.map(parser).toList(growable: false) : const [];

class AdminRefundRequest {
  const AdminRefundRequest({
    required this.id,
    required this.refundNo,
    required this.orderId,
    required this.orderNo,
    required this.orderItemId,
    required this.userId,
    required this.username,
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
    required this.createTime,
  });
  factory AdminRefundRequest.fromJson(dynamic json) {
    final m = Map<String, dynamic>.from(json as Map);
    int integer(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    double decimal(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return AdminRefundRequest(
      id: integer(m['id']),
      refundNo: m['refundNo'] as String? ?? '',
      orderId: integer(m['orderId']),
      orderNo: m['orderNo'] as String? ?? '',
      orderItemId: integer(m['orderItemId']),
      userId: integer(m['userId']),
      username: m['username'] as String? ?? '',
      bookId: integer(m['bookId']),
      bookTitle: m['bookTitle'] as String? ?? '',
      type: m['type'] as String? ?? '',
      status: m['status'] as String? ?? 'PENDING',
      quantity: integer(m['quantity']),
      itemQuantity: integer(m['itemQuantity']),
      refundedQuantity: integer(m['refundedQuantity']),
      amount: decimal(m['amount']),
      reason: m['reason'] as String? ?? '',
      reviewRemark: m['reviewRemark'] as String? ?? '',
      createTime: m['createTime'] as String? ?? '',
    );
  }
  final int id,
      orderId,
      orderItemId,
      userId,
      bookId,
      quantity,
      itemQuantity,
      refundedQuantity;
  final String refundNo,
      orderNo,
      username,
      bookTitle,
      type,
      status,
      reason,
      reviewRemark,
      createTime;
  final double amount;
  bool get pending => status == 'PENDING';
  String get typeLabel => type == 'RETURN_REFUND' ? '退货退款' : '仅退款';
  String get statusLabel => switch (status) {
    'APPROVED' => '已同意',
    'REJECTED' => '已拒绝',
    _ => '待审核',
  };
}


class AdminBundleRefundRequestItem {
  const AdminBundleRefundRequestItem({
    required this.orderItemId,
    required this.bookId,
    required this.bookTitle,
    required this.isbn,
    required this.salePrice,
    required this.allocatedDiscount,
    required this.quantity,
    required this.amount,
  });

  factory AdminBundleRefundRequestItem.fromJson(dynamic json) {
    final m = Map<String, dynamic>.from(json as Map);
    return AdminBundleRefundRequestItem(
      orderItemId: _int(m['orderItemId']),
      bookId: _int(m['bookId']),
      bookTitle: m['bookTitle'] as String? ?? '',
      isbn: m['isbn'] as String? ?? '',
      salePrice: _double(m['salePrice']),
      allocatedDiscount: _double(m['allocatedDiscount']),
      quantity: _int(m['quantity']),
      amount: _double(m['amount']),
    );
  }

  final int orderItemId;
  final int bookId;
  final String bookTitle;
  final String isbn;
  final double salePrice;
  final double allocatedDiscount;
  final int quantity;
  final double amount;
}

class AdminBundleRefundRequest {
  const AdminBundleRefundRequest({
    required this.id,
    required this.refundNo,
    required this.orderId,
    required this.orderNo,
    required this.bundleApplicationId,
    required this.bundleId,
    required this.bundleName,
    required this.type,
    required this.status,
    required this.amount,
    required this.reason,
    required this.reviewRemark,
    required this.items,
    required this.createTime,
    this.reviewerId,
    this.reviewedTime,
  });

  factory AdminBundleRefundRequest.fromJson(dynamic json) {
    final m = Map<String, dynamic>.from(json as Map);
    return AdminBundleRefundRequest(
      id: _int(m['id']),
      refundNo: m['refundNo'] as String? ?? '',
      orderId: _int(m['orderId']),
      orderNo: m['orderNo'] as String? ?? '',
      bundleApplicationId: _int(m['bundleApplicationId']),
      bundleId: _int(m['bundleId']),
      bundleName: m['bundleName'] as String? ?? '',
      type: m['type'] as String? ?? '',
      status: m['status'] as String? ?? 'PENDING',
      amount: _double(m['amount']),
      reason: m['reason'] as String? ?? '',
      reviewRemark: m['reviewRemark'] as String? ?? '',
      items: _list(m['items'], AdminBundleRefundRequestItem.fromJson),
      createTime: m['createTime'] as String? ?? '',
      reviewerId: (m['reviewerId'] as num?)?.toInt(),
      reviewedTime: m['reviewedTime'] as String?,
    );
  }

  final int id;
  final String refundNo;
  final int orderId;
  final String orderNo;
  final int bundleApplicationId;
  final int bundleId;
  final String bundleName;
  final String type;
  final String status;
  final double amount;
  final String reason;
  final String reviewRemark;
  final List<AdminBundleRefundRequestItem> items;
  final String createTime;
  final int? reviewerId;
  final String? reviewedTime;

  bool get pending => status == 'PENDING';
  String get typeLabel => type == 'RETURN_REFUND' ? '退货退款' : '仅退款';
  String get statusLabel => switch (status) {
    'APPROVED' => '已同意',
    'REJECTED' => '已拒绝',
    _ => '待审核',
  };
}
