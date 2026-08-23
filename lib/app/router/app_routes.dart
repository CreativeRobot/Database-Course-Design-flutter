import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_page.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/books/presentation/books_page.dart';
import '../../features/books/presentation/search_results_page.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/orders/presentation/checkout_page.dart';
import '../../features/orders/presentation/order_detail_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/reviews/presentation/reviews_page.dart';
import 'app_route_paths.dart';

List<RouteBase> buildAppRoutes() => [
  ..._publicRoutes(),
  ..._customerRoutes(),
  ..._administratorRoutes(),
];

List<GoRoute> _publicRoutes() => [
  GoRoute(path: AppRoutePaths.login, builder: (_, _) => const LoginPage()),
  GoRoute(
    path: AppRoutePaths.register,
    builder: (_, _) => const RegisterPage(),
  ),
  GoRoute(path: AppRoutePaths.books, builder: (_, _) => const BooksPage()),
  GoRoute(
    path: AppRoutePaths.search,
    builder: (_, state) => SearchResultsPage(
      initialKeyword: state.uri.queryParameters['keyword'] ?? '',
    ),
  ),
  GoRoute(
    path: '${AppRoutePaths.books}/:bookId',
    builder: (_, state) {
      final bookId = int.tryParse(state.pathParameters['bookId'] ?? '');
      return bookId == null
          ? const BooksPage()
          : BookDetailPage(bookId: bookId);
    },
  ),
];

List<GoRoute> _customerRoutes() => [
  GoRoute(path: AppRoutePaths.cart, builder: (_, _) => const CartPage()),
  GoRoute(
    path: AppRoutePaths.checkout,
    builder: (_, _) => const CheckoutPage(),
  ),
  GoRoute(path: AppRoutePaths.orders, builder: (_, _) => const OrdersPage()),
  GoRoute(
    path: '${AppRoutePaths.orders}/:orderId',
    builder: (_, state) {
      final orderId = int.tryParse(state.pathParameters['orderId'] ?? '');
      return orderId == null
          ? const OrdersPage()
          : OrderDetailPage(orderId: orderId);
    },
  ),
  GoRoute(path: AppRoutePaths.reviews, builder: (_, _) => const ReviewsPage()),
  GoRoute(path: AppRoutePaths.profile, builder: (_, _) => const ProfilePage()),
];

List<GoRoute> _administratorRoutes() => [
  GoRoute(path: AppRoutePaths.admin, builder: (_, _) => const AdminPage()),
  for (final section in AdminSection.values)
    GoRoute(
      path: '${AppRoutePaths.admin}/${section.path}',
      builder: (_, _) => AdminPage(section: section),
    ),
];
