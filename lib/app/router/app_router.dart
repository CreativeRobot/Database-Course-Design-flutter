import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/admin/presentation/admin_page.dart';
import '../../features/books/presentation/books_page.dart';
import '../../features/books/presentation/search_results_page.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/orders/presentation/checkout_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/orders/presentation/order_detail_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/reviews/presentation/reviews_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      if (authState.status == AuthStatus.checking ||
          authState.status == AuthStatus.loading) {
        return null;
      }

      final location = state.matchedLocation;
      final isAuthPage = location == '/login' || location == '/register';
      final isAdminPage = location.startsWith('/admin');
      final isProtectedPage =
          location == '/cart' ||
          location == '/checkout' ||
          location.startsWith('/orders') ||
          location.startsWith('/reviews') ||
          location.startsWith('/profile');

      if (authState.isAuthenticated && isAuthPage) {
        return authState.session?.role == 'ADMIN' ? '/admin' : '/books';
      }
      if (!authState.isAuthenticated && isProtectedPage) {
        return '/login';
      }
      if (!authState.isAuthenticated && isAdminPage) {
        return '/login';
      }
      if (authState.isAuthenticated &&
          isAdminPage &&
          authState.session?.role != 'ADMIN') {
        return '/books';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(path: '/books', builder: (context, state) => const BooksPage()),
      GoRoute(
        path: '/search',
        builder: (context, state) => SearchResultsPage(
          initialKeyword: state.uri.queryParameters['keyword'] ?? '',
        ),
      ),
      GoRoute(
        path: '/books/:bookId',
        builder: (context, state) {
          final bookId = int.tryParse(state.pathParameters['bookId'] ?? '');
          if (bookId == null) {
            return const BooksPage();
          }
          return BookDetailPage(bookId: bookId);
        },
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutPage(),
      ),
      GoRoute(path: '/orders', builder: (context, state) => const OrdersPage()),
      GoRoute(
        path: '/reviews',
        builder: (context, state) => const ReviewsPage(),
      ),
      GoRoute(
        path: '/orders/:orderId',
        builder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['orderId'] ?? '');
          if (orderId == null) return const OrdersPage();
          return OrderDetailPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
      for (final section in AdminSection.values)
        GoRoute(
          path: '/admin/${section.path}',
          builder: (_, _) => AdminPage(section: section),
        ),
    ],
  );
});

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
