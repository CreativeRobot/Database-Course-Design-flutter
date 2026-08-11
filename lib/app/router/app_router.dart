import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/books/presentation/books_page.dart';

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

      final isAuthPage =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isProtectedPage = const {
        '/cart',
        '/orders',
        '/profile',
      }.contains(state.matchedLocation);

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
      GoRoute(
        path: '/cart',
        builder: (context, state) => const ProtectedPlaceholderPage(
          title: '购物车',
          message: '购物车模块将在认证闭环之后接入。当前登录状态已经可以保护这条路由。',
        ),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const ProtectedPlaceholderPage(
          title: '我的订单',
          message: '订单模块将在购物车完成后接入。当前登录状态已经可以保护这条路由。',
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProtectedPlaceholderPage(
          title: '个人中心',
          message: '用户资料和收货地址模块将在下一阶段接入。',
        ),
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
