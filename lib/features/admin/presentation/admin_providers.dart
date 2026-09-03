import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/common/page_response.dart';
import '../../orders/data/order_models.dart';
import '../../reviews/data/review_models.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../../cart/data/bundle_models.dart';
import '../../cart/data/bundle_repository.dart';
import 'admin_book_filter.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});

final adminStatisticsProvider = FutureProvider.autoDispose<AdminStatistics>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).statistics();
});

final adminBookFilterProvider = StateProvider<AdminBookFilter?>((ref) => null);
final bundleRepositoryProvider = Provider<BundleRepository>((ref) {
  return BundleRepository(ref.watch(apiClientProvider));
});

final adminBundlesProvider = FutureProvider.autoDispose<List<BookBundle>>((ref) {
  return ref.watch(bundleRepositoryProvider).adminList();
});

typedef AdminUserFilter = ({
  String keyword,
  int? status,
  String? role,
  int page,
});

final adminUsersProvider = FutureProvider.autoDispose
    .family<PageResponse<AdminUser>, AdminUserFilter>((ref, filter) {
      return ref
          .watch(adminRepositoryProvider)
          .users(
            keyword: filter.keyword,
            status: filter.status,
            role: filter.role,
            page: filter.page,
          );
    });
final adminBooksProvider = FutureProvider.autoDispose
    .family<
      PageResponse<Book>,
      ({
        String keyword,
        String? status,
        int? authorId,
        int? publisherId,
        int? categoryId,
        int page,
      })
    >((ref, key) async {
      return ref
          .watch(adminRepositoryProvider)
          .books(
            keyword: key.keyword,
            status: key.status,
            authorId: key.authorId,
            publisherId: key.publisherId,
            categoryId: key.categoryId,
            page: key.page,
          );
    });

final adminAuthorsProvider = FutureProvider.autoDispose
    .family<PageResponse<AdminAuthor>, ({String keyword, int page})>((
      ref,
      key,
    ) {
      return ref
          .watch(adminRepositoryProvider)
          .authors(keyword: key.keyword, page: key.page);
    });

final adminPublishersProvider = FutureProvider.autoDispose
    .family<PageResponse<AdminPublisher>, ({String keyword, int page})>((
      ref,
      key,
    ) {
      return ref
          .watch(adminRepositoryProvider)
          .publishers(keyword: key.keyword, page: key.page);
    });

final adminCategoriesProvider = FutureProvider.autoDispose
    .family<List<AdminCategory>, ({String keyword, int? status})>((ref, key) {
      return ref
          .watch(adminRepositoryProvider)
          .categories(keyword: key.keyword, status: key.status);
    });

final adminCategoryTreeProvider = FutureProvider.autoDispose
    .family<List<AdminCategory>, ({String keyword, int? status})>((ref, key) {
      return ref
          .watch(adminRepositoryProvider)
          .categoryTree(keyword: key.keyword, status: key.status);
    });
typedef AdminOrderFilter = ({
  String orderNo,
  int? userId,
  String? status,
  int page,
});

final adminOrdersProvider = FutureProvider.autoDispose
    .family<PageResponse<BookOrder>, AdminOrderFilter>((ref, filter) {
      return ref
          .watch(adminRepositoryProvider)
          .orders(
            orderNo: filter.orderNo,
            userId: filter.userId,
            status: filter.status,
            page: filter.page,
          );
    });

typedef AdminReviewFilter = ({int? bookId, int? userId, int? status, int page});

final adminReviewsProvider = FutureProvider.autoDispose
    .family<PageResponse<UserReview>, AdminReviewFilter>((ref, filter) {
      return ref
          .watch(adminRepositoryProvider)
          .reviews(
            bookId: filter.bookId,
            userId: filter.userId,
            status: filter.status,
            page: filter.page,
          );
    });

typedef AdminInventoryFilter = ({
  int? bookId,
  int? orderId,
  String? type,
  String? startTime,
  String? endTime,
  int page,
});

final adminInventoryProvider = FutureProvider.autoDispose
    .family<PageResponse<InventoryLog>, AdminInventoryFilter>((ref, filter) {
      return ref
          .watch(adminRepositoryProvider)
          .inventoryLogs(
            bookId: filter.bookId,
            orderId: filter.orderId,
            type: filter.type,
            startTime: filter.startTime,
            endTime: filter.endTime,
            page: filter.page,
          );
    });

typedef AdminRefundFilter = ({String? status, String? type, int page});
final adminRefundsProvider = FutureProvider.autoDispose
    .family<PageResponse<AdminRefundRequest>, AdminRefundFilter>((ref, filter) {
      return ref
          .watch(adminRepositoryProvider)
          .refunds(status: filter.status, type: filter.type, page: filter.page);
    });
