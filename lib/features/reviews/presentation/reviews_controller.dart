import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/review_models.dart';
import '../data/review_repository.dart';

enum ReviewsStatus { initial, loading, ready, failure }

class ReviewsState {
  const ReviewsState({
    this.status = ReviewsStatus.initial,
    this.reviews = const [],
    this.visibleCount = 10,
    this.busyOrderItemId,
    this.errorMessage,
  });

  final ReviewsStatus status;
  final List<UserReview> reviews;
  final int visibleCount;
  final int? busyOrderItemId;
  final String? errorMessage;

  List<UserReview> get visibleReviews =>
      reviews.take(visibleCount).toList(growable: false);
  bool get hasMore => visibleCount < reviews.length;

  UserReview? reviewFor(int orderItemId) {
    for (final review in reviews) {
      if (review.orderItemId == orderItemId) return review;
    }
    return null;
  }

  ReviewsState copyWith({
    ReviewsStatus? status,
    List<UserReview>? reviews,
    int? visibleCount,
    int? busyOrderItemId,
    bool clearBusy = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReviewsState(
      status: status ?? this.status,
      reviews: reviews ?? this.reviews,
      visibleCount: visibleCount ?? this.visibleCount,
      busyOrderItemId: clearBusy
          ? null
          : busyOrderItemId ?? this.busyOrderItemId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ReviewsController extends StateNotifier<ReviewsState> {
  ReviewsController({
    required ReviewRepository repository,
    required AuthController authController,
  }) : _repository = repository,
       _authController = authController,
       super(const ReviewsState());

  final ReviewRepository _repository;
  final AuthController _authController;

  Future<void> loadMyReviews({bool force = false}) async {
    if (!force && state.status == ReviewsStatus.ready) return;
    state = state.copyWith(status: ReviewsStatus.loading, clearError: true);
    try {
      final reviews = await _repository.listMyReviews();
      state = state.copyWith(
        status: ReviewsStatus.ready,
        reviews: reviews,
        visibleCount: 10,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        status: ReviewsStatus.failure,
        errorMessage: await _messageFor(error),
      );
    } catch (_) {
      state = state.copyWith(
        status: ReviewsStatus.failure,
        errorMessage: '评价暂时无法加载',
      );
    }
  }

  void loadMore() {
    if (!state.hasMore) return;
    final nextCount = (state.visibleCount + 10).clamp(0, state.reviews.length);
    state = state.copyWith(visibleCount: nextCount);
  }

  Future<UserReview?> saveReview({
    required int orderItemId,
    required int rating,
    required String content,
    UserReview? existing,
  }) async {
    if (state.busyOrderItemId != null) return null;
    state = state.copyWith(busyOrderItemId: orderItemId, clearError: true);
    try {
      final saved = existing == null
          ? await _repository.createReview(
              orderItemId: orderItemId,
              rating: rating,
              content: content,
            )
          : await _repository.updateReview(
              reviewId: existing.id,
              rating: rating,
              content: content,
            );
      state = state.copyWith(
        status: ReviewsStatus.ready,
        reviews: [
          saved,
          ...state.reviews.where((review) => review.id != saved.id),
        ],
        visibleCount: state.visibleCount + (existing == null ? 1 : 0),
        clearBusy: true,
        clearError: true,
      );
      return saved;
    } on ApiException catch (error) {
      state = state.copyWith(
        clearBusy: true,
        errorMessage: await _messageFor(error),
      );
      return null;
    } catch (_) {
      state = state.copyWith(clearBusy: true, errorMessage: '评价保存失败，请稍后再试');
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<String> _messageFor(ApiException error) async {
    if (error.isUnauthorized) {
      await _authController.logout();
      return '登录已过期，请重新登录';
    }
    if (error.message == 'Unable to connect to the server') {
      return '暂时无法连接服务，请确认后端已经启动';
    }
    return error.message.isEmpty ? '评价操作失败' : error.message;
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(apiClientProvider));
});

final reviewsControllerProvider =
    StateNotifierProvider<ReviewsController, ReviewsState>((ref) {
      return ReviewsController(
        repository: ref.watch(reviewRepositoryProvider),
        authController: ref.watch(authControllerProvider.notifier),
      );
    });
