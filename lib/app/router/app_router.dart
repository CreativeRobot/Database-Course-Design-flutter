import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/books/presentation/books_page.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/orders/presentation/checkout_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/orders/presentation/order_detail_page.dart';
import '../../features/profile/presentation/profile_page.dart';

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
      final isProtectedPage =
          location == '/cart' ||
          location == '/checkout' ||
          location.startsWith('/orders') ||
          location.startsWith('/profile');

      if (authState.isAuthenticated && isAuthPage) {
        return '/books';
      }
      if (!authState.isAuthenticated && isProtectedPage) {
        return '/login';
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
