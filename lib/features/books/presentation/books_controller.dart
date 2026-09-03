import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/book_detail.dart';
import '../../../data/models/book/book_review.dart';
import '../../cart/data/bundle_models.dart';
import '../data/book_repository.dart';

enum BooksStatus { initial, loading, refreshing, success, failure }

class BooksState {
  const BooksState({
    this.status = BooksStatus.initial,
    this.books = const [],
    this.page = 1,
    this.total = 0,
    this.totalPages = 0,
    this.errorMessage,
  });

  final BooksStatus status;
  final List<Book> books;
  final int page;
  final int total;
  final int totalPages;
  final String? errorMessage;

  bool get hasMore => totalPages > page;

  BooksState copyWith({
    BooksStatus? status,
    List<Book>? books,
    int? page,
    int? total,
    int? totalPages,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BooksState(
      status: status ?? this.status,
      books: books ?? this.books,
      page: page ?? this.page,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class BooksController extends StateNotifier<BooksState> {
  BooksController(this._repository) : super(const BooksState());

  final BookRepository _repository;

  Future<void> loadInitial() async {
    if (state.status != BooksStatus.initial) {
      return;
    }
    await loadBooks();
  }

  Future<void> loadBooks() async {
    final hasExistingBooks = state.books.isNotEmpty;
    state = state.copyWith(
      status: hasExistingBooks ? BooksStatus.refreshing : BooksStatus.loading,
      clearError: true,
    );
    try {
      final result = await _repository.getBooks();
      state = state.copyWith(
        status: BooksStatus.success,
        books: result.records,
        page: result.page,
        total: result.total,
        totalPages: result.totalPages,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        status: BooksStatus.failure,
        errorMessage: _friendlyMessage(error),
      );
    } catch (_) {
      state = state.copyWith(
        status: BooksStatus.failure,
        errorMessage: '图书暂时无法加载，请稍后再试',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.status == BooksStatus.loading ||
        state.status == BooksStatus.refreshing ||
        !state.hasMore) {
      return;
    }
    try {
      final result = await _repository.getBooks(page: state.page + 1);
      state = state.copyWith(
        status: BooksStatus.success,
        books: [...state.books, ...result.records],
        page: result.page,
        total: result.total,
        totalPages: result.totalPages,
      );
    } on ApiException catch (error) {
      state = state.copyWith(errorMessage: _friendlyMessage(error));
    }
  }

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

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(ref.watch(apiClientProvider));
});

final booksControllerProvider =
    StateNotifierProvider<BooksController, BooksState>((ref) {
      return BooksController(ref.watch(bookRepositoryProvider));
    });

final bookDetailProvider = FutureProvider.family<BookDetail, int>((
  ref,
  bookId,
) {
  return ref.watch(bookRepositoryProvider).getBookDetail(bookId);
});

final bookBundlesProvider = FutureProvider.family<List<BookBundle>, int>((ref, bookId) {
  return ref.watch(bookRepositoryProvider).getBundles(bookId);
});

final bookReviewsProvider =
    FutureProvider.family<BookReviewSummary, ({int bookId, int page})>((
      ref,
      key,
    ) {
      return ref
          .watch(bookRepositoryProvider)
          .getReviews(key.bookId, page: key.page);
    });


