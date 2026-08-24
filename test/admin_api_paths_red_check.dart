import '../lib/core/constants/api_paths.dart';

void expectPath(String actual, String expected) {
  if (actual != expected) {
    throw StateError('Expected $expected, got $actual');
  }
}

void main() {
  expectPath(ApiPaths.adminBookStatus(7), '/api/admin/books/7/status');
  expectPath(ApiPaths.adminBookStock(7), '/api/admin/books/7/stock');
  expectPath(ApiPaths.adminCategoryStatus(5), '/api/admin/categories/5/status');
  expectPath(ApiPaths.adminShipOrder(11), '/api/admin/orders/11/ship');
  expectPath(ApiPaths.adminReviewStatus(13), '/api/admin/reviews/13/status');
}
