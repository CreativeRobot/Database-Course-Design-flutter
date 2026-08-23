import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import 'app_route_guard.dart';
import 'app_route_paths.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutePaths.login,
    refreshListenable: refresh,
    redirect: (_, state) => redirectForRoute(
      authState: ref.read(authControllerProvider),
      matchedLocation: state.matchedLocation,
    ),
    routes: buildAppRoutes(),
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
