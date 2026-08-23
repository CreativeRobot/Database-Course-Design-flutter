import 'package:flutter_application_bookstore/app/router/app_route_paths.dart';
import 'package:flutter_application_bookstore/app/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test(
    'route table retains public, customer, and administrator entry paths',
    () {
      final paths = buildAppRoutes()
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toSet();

      expect(
        paths,
        containsAll({
          AppRoutePaths.login,
          AppRoutePaths.register,
          AppRoutePaths.books,
          AppRoutePaths.search,
          '/books/:bookId',
          AppRoutePaths.cart,
          AppRoutePaths.checkout,
          AppRoutePaths.orders,
          '/orders/:orderId',
          AppRoutePaths.reviews,
          AppRoutePaths.profile,
          AppRoutePaths.admin,
        }),
      );
    },
  );
}
