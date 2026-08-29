abstract final class AppRoutePaths {
  static const login = '/login';
  static const register = '/register';
  static const books = '/books';
  static const search = '/search';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const refunds = '/refunds';
  static const reviews = '/reviews';
  static const profile = '/profile';
  static const admin = '/admin';

  static bool isAuthenticationRoute(String location) =>
      location == login || location == register;

  static bool isAdminRoute(String location) =>
      location == admin || location.startsWith('$admin/');

  static bool isCustomerProtectedRoute(String location) =>
      location == cart ||
      location == checkout ||
      location == orders ||
      location.startsWith('$orders/') ||
      location == refunds ||
      location == reviews ||
      location == profile;
}
