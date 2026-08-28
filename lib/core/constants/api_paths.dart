abstract final class ApiPaths {
  static const login = '/api/auth/login';
  static const register = '/api/auth/register';
  static const captcha = '/api/auth/captcha';

  static const books = '/api/books';
  static const categories = '/api/categories';
  static const authors = '/api/authors';
  static const publishers = '/api/publishers';
  static const recommendationsHome = '/api/recommendations/home';

  static String book(int bookId) => '$books/$bookId';
  static String bookReviews(int bookId) => '$books/$bookId/reviews';

  static const me = '/api/user/me';
  static const meAvatar = '$me/avatar';
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

  static const admin = '/api/admin';

  static const adminUsers = '$admin/users';
  static String adminUser(int id) => '$adminUsers/$id';
  static String adminUserStatus(int id) => '${adminUser(id)}/status';
  static const adminBooks = '$admin/books';
  static String adminBook(int bookId) => '$adminBooks/$bookId';
  static String adminBookStatus(int bookId) => '${adminBook(bookId)}/status';
  static String adminBookStock(int bookId) => '${adminBook(bookId)}/stock';

  static const adminAuthors = '$admin/authors';
  static String adminAuthor(int id) => '$adminAuthors/$id';

  static const adminPublishers = '$admin/publishers';
  static String adminPublisher(int id) => '$adminPublishers/$id';

  static const adminCategories = '$admin/categories';
  static const adminCategoriesTree = '$adminCategories/tree';
  static String adminCategory(int id) => '$adminCategories/$id';
  static String adminCategoryStatus(int id) => '${adminCategory(id)}/status';

  static const adminOrders = '$admin/orders';
  static String adminOrder(int id) => '$adminOrders/$id';
  static String adminShipOrder(int id) => '${adminOrder(id)}/ship';

  static const adminStatistics = '$admin/statistics/overview';

  static const adminReviews = '$admin/reviews';
  static String adminReview(int id) => '$adminReviews/$id';
  static String adminReviewStatus(int id) => '${adminReview(id)}/status';

  static const adminInventoryLogs = '$admin/inventory-logs';
  static const adminRefunds = '$admin/refunds';
  static String adminRefund(int id) => '$adminRefunds/$id';
  static String adminRefundReview(int id) => '${adminRefund(id)}/review';
  static const adminImageUpload = '$admin/uploads/images';
}
