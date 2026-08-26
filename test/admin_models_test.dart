import 'package:flutter_application_bookstore/features/admin/data/admin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin statistics parses all dashboard sections', () {
    final statistics = AdminStatistics.fromJson({
      'completedOrderCount': 3,
      'salesAmount': 99.9,
      'soldQuantity': 7,
      'monthlySales': [
        {
          'saleMonth': '2026-08',
          'completedOrderCount': 3,
          'soldQuantity': 7,
          'salesAmount': 99.9,
        },
      ],
      'topBooks': [
        {
          'bookId': 1,
          'bookTitle': '数据库系统',
          'soldQuantity': 4,
          'salesAmount': 60,
        },
      ],
      'categorySales': [],
      'lowStockBooks': [
        {
          'bookId': 2,
          'isbn': '9780000000002',
          'title': '低库存图书',
          'stock': 2,
          'status': 'ON_SALE',
        },
      ],
    });

    expect(statistics.completedOrderCount, 3);
    expect(statistics.monthlySales.single.month, '2026-08');
    expect(statistics.topBooks.single.quantity, 4);
    expect(statistics.lowStockBooks.single.stock, 2);
  });

  test('category and inventory log keep management relationships', () {
    final category = AdminCategory.fromJson({
      'id': 1,
      'name': '计算机',
      'sortOrder': 1,
      'status': 1,
      'children': [
        {
          'id': 3,
          'name': '数据库',
          'parentId': 1,
          'parentName': '计算机',
          'sortOrder': 2,
          'status': 1,
        },
      ],
    });
    final log = InventoryLog.fromJson({
      'id': 8,
      'bookId': 2,
      'isbn': '9780000000002',
      'bookTitle': '数据库系统',
      'changeQuantity': -1,
      'beforeStock': 5,
      'afterStock': 4,
      'changeType': 'ORDER_OUT',
      'orderId': 6,
      'orderNo': 'BS202608130001',
      'remark': '订单出库',
      'createTime': '2026-08-13T10:20:00',
    });

    expect(category.children.single.parentName, '计算机');
    expect(log.orderId, 6);
    expect(log.changeQuantity, -1);
    expect(log.createTime, isNotNull);
  });
}
