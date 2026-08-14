import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/book/book.dart';
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
    .family<List<Book>, String?>((ref, status) async {
      return (await ref.watch(adminRepositoryProvider).books(status: status))
          .records;
    });

final adminAuthorsProvider = FutureProvider.autoDispose
    .family<List<AdminAuthor>, String>((ref, keyword) {
      return ref.watch(adminRepositoryProvider).authors(keyword: keyword);
    });

final adminPublishersProvider = FutureProvider.autoDispose
    .family<List<AdminPublisher>, String>((ref, keyword) {
      return ref.watch(adminRepositoryProvider).publishers(keyword: keyword);
    });

final adminCategoriesProvider = FutureProvider.autoDispose
    .family<List<AdminCategory>, int?>((ref, status) {
      return ref.watch(adminRepositoryProvider).categories(status: status);
    });

typedef AdminOrderFilter = ({String orderNo, int? userId, String? status});

final adminOrdersProvider = FutureProvider.autoDispose
    .family<List<BookOrder>, AdminOrderFilter>((ref, filter) {
      return ref
          .watch(adminRepositoryProvider)
          .orders(
            orderNo: filter.orderNo,
            userId: filter.userId,
            status: filter.status,
          );
    });

typedef AdminReviewFilter = ({int? bookId, int? userId, int? status});

final adminReviewsProvider = FutureProvider.autoDispose
    .family<List<UserReview>, AdminReviewFilter>((ref, filter) {
      return ref
          .watch(adminRepositoryProvider)
          .reviews(
            bookId: filter.bookId,
            userId: filter.userId,
            status: filter.status,
          );
    });

typedef AdminInventoryFilter = ({
  int? bookId,
  int? orderId,
  String? type,
  String? startTime,
  String? endTime,
});

final adminInventoryProvider = FutureProvider.autoDispose
    .family<List<InventoryLog>, AdminInventoryFilter>((ref, filter) {
      return ref
          .watch(adminRepositoryProvider)
          .inventoryLogs(
            bookId: filter.bookId,
            orderId: filter.orderId,
            type: filter.type,
            startTime: filter.startTime,
            endTime: filter.endTime,
          );
    });
