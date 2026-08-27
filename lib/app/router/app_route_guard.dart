import '../../features/auth/presentation/auth_controller.dart';
import 'app_route_paths.dart';

String destinationForRole(String role) =>
    role == 'ADMIN' ? AppRoutePaths.admin : AppRoutePaths.books;

String? redirectForRoute({
  required AuthState authState,
  required String matchedLocation,
}) {
  if (authState.status == AuthStatus.checking ||
      authState.status == AuthStatus.loading) {
    return null;
  }

  final isAdministrator = authState.session?.role == 'ADMIN';
  if (authState.isAuthenticated &&
      AppRoutePaths.isAuthenticationRoute(matchedLocation)) {
    return destinationForRole(authState.session!.role);
  }
  if (!authState.isAuthenticated &&
      (AppRoutePaths.isCustomerProtectedRoute(matchedLocation) ||
          AppRoutePaths.isAdminRoute(matchedLocation))) {
    return AppRoutePaths.login;
  }
  if (authState.isAuthenticated &&
      AppRoutePaths.isAdminRoute(matchedLocation) &&
      !isAdministrator) {
    return AppRoutePaths.books;
  }
  if (authState.isAuthenticated &&
      isAdministrator &&
      matchedLocation == AppRoutePaths.books) {
    return AppRoutePaths.admin;
  }
  return null;
}
