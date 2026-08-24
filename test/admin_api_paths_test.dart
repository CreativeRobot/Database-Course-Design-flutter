import 'package:flutter_application_bookstore/core/constants/api_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin mutation paths include the target resource id', () {
    expect(ApiPaths.adminBookStatus(7), '/api/admin/books/7/status');
    expect(ApiPaths.adminBookStock(7), '/api/admin/books/7/stock');
    expect(ApiPaths.adminCategoryStatus(5), '/api/admin/categories/5/status');
    expect(ApiPaths.adminShipOrder(11), '/api/admin/orders/11/ship');
    expect(ApiPaths.adminReviewStatus(13), '/api/admin/reviews/13/status');
  });
}
