import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/common/page_response.dart';
import '../../books/data/book_repository.dart';
import '../../books/presentation/books_controller.dart';
import '../data/community_models.dart';
import '../data/community_repository.dart';

enum CommunityFeedStatus { initial, loading, ready, failure }

class CommunityFeedState {
  const CommunityFeedState({
    this.status = CommunityFeedStatus.initial,
    this.posts = const [],
    this.keyword = '',
    this.bookId,
    this.page = 1,
    this.totalPages = 0,
    this.loadingMore = false,
    this.errorMessage,
  });
  final CommunityFeedStatus status;
  final List<CommunityPost> posts;
  final String keyword;
  final int? bookId;
  final int page;
  final int totalPages;
  final bool loadingMore;
  final String? errorMessage;
  bool get hasMore => page < totalPages;

  CommunityFeedState copyWith({
    CommunityFeedStatus? status,
    List<CommunityPost>? posts,
    String? keyword,
    int? bookId,
    bool clearBook = false,
    int? page,
    int? totalPages,
    bool? loadingMore,
    String? errorMessage,
    bool clearError = false,
  }) => CommunityFeedState(
    status: status ?? this.status,
    posts: posts ?? this.posts,
    keyword: keyword ?? this.keyword,
    bookId: clearBook ? null : bookId ?? this.bookId,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    loadingMore: loadingMore ?? this.loadingMore,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

class CommunityFeedController extends StateNotifier<CommunityFeedState> {
  CommunityFeedController(this._repository) : super(const CommunityFeedState());
  final CommunityRepository _repository;
  int _generation = 0;

  Future<void> load({
    String? keyword,
    int? bookId,
    bool clearBook = false,
  }) async {
    final generation = ++_generation;
    final nextKeyword = keyword ?? state.keyword;
    final nextBook = clearBook ? null : bookId ?? state.bookId;
    state = state.copyWith(
      status: CommunityFeedStatus.loading,
      keyword: nextKeyword,
      bookId: nextBook,
      clearBook: clearBook,
      loadingMore: false,
      clearError: true,
    );
    try {
      final result = await _repository.listPosts(
        keyword: nextKeyword,
        bookId: nextBook,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        status: CommunityFeedStatus.ready,
        posts: result.records,
        page: result.page,
        totalPages: result.totalPages,
        clearError: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        status: CommunityFeedStatus.failure,
        errorMessage: _message(error),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    final generation = _generation;
    final keyword = state.keyword;
    final bookId = state.bookId;
    final nextPage = state.page + 1;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final result = await _repository.listPosts(
        keyword: keyword,
        bookId: bookId,
        page: nextPage,
      );
      if (generation != _generation ||
          keyword != state.keyword ||
          bookId != state.bookId) {
        return;
      }
      state = state.copyWith(
        posts: [...state.posts, ...result.records],
        page: result.page,
        totalPages: result.totalPages,
        loadingMore: false,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(loadingMore: false, errorMessage: _message(error));
    }
  }

  String _message(Object error) =>
      error is ApiException && error.message.isNotEmpty
      ? error.message
      : '社区内容暂时无法加载';
}

Future<List<Book>> loadCommunityBookOptions(BookRepository repository) async {
  final books = <Book>[];
  var page = 1;
  var totalPages = 1;
  do {
    final result = await repository.getBooks(page: page, size: 50);
    books.addAll(result.records);
    totalPages = result.totalPages;
    page++;
  } while (page <= totalPages);
  return List.unmodifiable(books);
}

final communityBookOptionsProvider = FutureProvider.autoDispose<List<Book>>(
  (ref) => loadCommunityBookOptions(ref.watch(bookRepositoryProvider)),
);
final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(apiClientProvider)),
);
final communityFeedProvider =
    StateNotifierProvider.autoDispose<
      CommunityFeedController,
      CommunityFeedState
    >((ref) => CommunityFeedController(ref.watch(communityRepositoryProvider)));
final communityPostProvider = FutureProvider.family<CommunityPost, int>(
  (ref, id) => ref.watch(communityRepositoryProvider).getPost(id),
);
final communityCommentsProvider =
    FutureProvider.family<PageResponse<CommunityComment>, int>(
      (ref, id) => ref.watch(communityRepositoryProvider).listComments(id),
    );
