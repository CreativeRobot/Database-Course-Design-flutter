abstract final class ApiPaths {
  static const login = '/api/auth/login';
  static const register = '/api/auth/register';

  static const books = '/api/books';
  static const categories = '/api/categories';
  static const authors = '/api/authors';
  static const publishers = '/api/publishers';
  static String book(int bookId) => '$books/$bookId';
  static String bookReviews(int bookId) => '$books/$bookId/reviews';

  static const me = '/api/user/me';
  static const mePassword = '/api/user/me/password';
  static const addresses = '/api/user/addresses';
  static String address(int addressId) => '$addresses/$addressId';
  static String defaultAddress(int addressId) =>
      '$addresses/$addressId/default';
  static const cart = '/api/cart';
  static const cartItems = '/api/cart/items';
  static const cartSelection = '/api/cart/selection';
  static const cartSelected = '/api/cart/selected';
  static String cartItem(int bookId) => '$cartItems/$bookId';
  static const orders = '/api/orders';
  static String order(int orderId) => '$orders/$orderId';
  static String cancelOrder(int orderId) => '$orders/$orderId/cancel';
  static String orderPayment(int orderId) => '$orders/$orderId/payment';
  static String confirmOrderReceipt(int orderId) =>
      '$orders/$orderId/confirm-receipt';
  static const reviews = '/api/reviews';
  static const myReviews = '$reviews/me';
  static String review(int reviewId) => '$reviews/$reviewId';
}
