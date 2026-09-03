import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../data/recommendation_models.dart';
import '../data/recommendation_repository.dart';

enum RecommendationStatus {
  initial,
  loading,
  loadingMore,
  refreshing,
  success,
  failure,
}

class RecommendationState {
  const RecommendationState({
    this.status = RecommendationStatus.initial,
    this.home,
    this.errorMessage,
  });

  final RecommendationStatus status;
  final RecommendationHome? home;
  final String? errorMessage;

  bool get hasRecommendations => home?.books.isNotEmpty ?? false;
  bool get isLoadingMore => status == RecommendationStatus.loadingMore;

  RecommendationState copyWith({
    RecommendationStatus? status,
    RecommendationHome? home,
    bool clearHome = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecommendationState(
      status: status ?? this.status,
      home: clearHome ? null : home ?? this.home,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RecommendationController extends StateNotifier<RecommendationState> {
  RecommendationController(this._source) : super(const RecommendationState());

  final RecommendationDataSource _source;

  Future<void> load({int limit = 12}) async {
    if (state.status == RecommendationStatus.loading ||
        state.status == RecommendationStatus.refreshing ||
        state.status == RecommendationStatus.loadingMore) {
      return;
    }

    final hasHome = state.home != null;
    state = state.copyWith(
      status: hasHome
          ? RecommendationStatus.refreshing
          : RecommendationStatus.loading,
      clearError: true,
    );
    try {
      final home = await _source.fetchHome(limit: limit, page: 1);
      state = state.copyWith(
        status: RecommendationStatus.success,
        home: home,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        status: RecommendationStatus.failure,
        errorMessage: _friendlyMessage(error),
      );
    } on ArgumentError catch (error) {
      state = state.copyWith(
        status: RecommendationStatus.failure,
        errorMessage: error.message?.toString() ?? '推荐数量不正确',
      );
    } catch (_) {
      state = state.copyWith(
        status: RecommendationStatus.failure,
        errorMessage: '推荐暂时无法加载，请稍后再试',
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.home;
    if (current == null ||
        !current.hasMore ||
        state.isLoadingMore ||
        state.status == RecommendationStatus.loading ||
        state.status == RecommendationStatus.refreshing) {
      return;
    }
    state = state.copyWith(
      status: RecommendationStatus.loadingMore,
      clearError: true,
    );
    try {
      final next = await _source.fetchHome(
        limit: current.size,
        page: current.page + 1,
      );
      final merged = RecommendationHome(
        source: current.source,
        books: [...current.books, ...next.books],
        page: next.page,
        size: next.size,
        hasMore: next.hasMore,
      );
      state = state.copyWith(
        status: RecommendationStatus.success,
        home: merged,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        status: RecommendationStatus.success,
        errorMessage: _friendlyMessage(error),
      );
    } catch (_) {
      state = state.copyWith(
        status: RecommendationStatus.success,
        errorMessage: '更多推荐暂时无法加载，请稍后再试',
      );
    }
  }

  Future<void> refresh({int limit = 12}) => load(limit: limit);

  String _friendlyMessage(ApiException error) {
    if (error.message == 'Unable to connect to the server') {
      return '暂时无法连接服务，请确认后端已经启动';
    }
    if (error.message == 'Connection to server timed out') {
      return '连接服务超时，请稍后再试';
    }
    return error.message;
  }
}

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepository(ref.watch(apiClientProvider)),
);

final recommendationControllerProvider =
    StateNotifierProvider<RecommendationController, RecommendationState>(
      (ref) =>
          RecommendationController(ref.watch(recommendationRepositoryProvider)),
    );
