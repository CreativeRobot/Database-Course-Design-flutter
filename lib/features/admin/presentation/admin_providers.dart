import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/common/page_response.dart';
import '../../orders/data/order_models.dart';
import '../../reviews/data/review_models.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});

final adminStatisticsProvider = FutureProvider.autoDispose<AdminStatistics>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).statistics();
});

final adminBooksProvider = FutureProvider.autoDispose
    .family<PageResponse<Book>, ({String? status, int page})>((ref, key) async {
      return ref.watch(adminRepositoryProvider).books(status: key.status, page: key.page);
    });

final adminAuthorsProvider = FutureProvider.autoDispose
    .family<PageResponse<AdminAuthor>, ({String keyword, int page})>((ref, key) {
      return ref.watch(adminRepositoryProvider).authors(keyword: key.keyword, page: key.page);
    });

final adminPublishersProvider = FutureProvider.autoDispose
    .family<PageResponse<AdminPublisher>, ({String keyword, int page})>((ref, key) {
      return ref.watch(adminRepositoryProvider).publishers(keyword: key.keyword, page: key.page);
    });

final adminCategoriesProvider = FutureProvider.autoDispose
    .family<List<AdminCategory>, int?>((ref, status) {
      return ref.watch(adminRepositoryProvider).categories(status: status);
    });

typedef AdminOrderFilter = ({String orderNo, int? userId, String? status, int page});

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
