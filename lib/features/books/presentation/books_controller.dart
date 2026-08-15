import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/book_detail.dart';
import '../../../data/models/book/book_review.dart';
import '../../../data/models/book/category.dart';
import '../data/book_repository.dart';

enum BooksStatus { initial, loading, refreshing, success, failure }

class BooksState {
  const BooksState({
    this.status = BooksStatus.initial,
    this.books = const [],
    this.categories = const [],
    this.keyword = '',
    this.categoryId,
    this.authorId,
    this.publisherId,
    this.minPrice,
    this.maxPrice,
    this.inStock = false,
    this.sortBy = 'latest',
    this.direction = 'desc',
    this.page = 1,
    this.total = 0,
    this.totalPages = 0,
    this.errorMessage,
  });

  final BooksStatus status;
  final List<Book> books;
  final List<BookCategory> categories;
  final String keyword;
  final int? categoryId;
  final int? authorId;
  final int? publisherId;
  final double? minPrice;
  final double? maxPrice;
  final bool inStock;
  final String sortBy;
  final String direction;
  final int page;
  final int total;
  final int totalPages;
  final String? errorMessage;

  bool get hasMore => totalPages > page;

  BooksState copyWith({
    BooksStatus? status,
    List<Book>? books,
    List<BookCategory>? categories,
    String? keyword,
    int? categoryId,
    bool clearCategory = false,
    int? authorId,
    int? publisherId,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    String? sortBy,
    String? direction,
    int? page,
    int? total,
    int? totalPages,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BooksState(
      status: status ?? this.status,
      books: books ?? this.books,
      categories: categories ?? this.categories,
      keyword: keyword ?? this.keyword,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      authorId: authorId ?? this.authorId,
      publisherId: publisherId ?? this.publisherId,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      inStock: inStock ?? this.inStock,
      sortBy: sortBy ?? this.sortBy,
      direction: direction ?? this.direction,
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
    await Future.wait([loadBooks(), loadCategories()]);
  }

  Future<void> loadBooks({
    String? keyword,
    int? categoryId,
    bool clearCategory = false,
    int? authorId,
    int? publisherId,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    String? sortBy,
    String? direction,
  }) async {
    final nextKeyword = keyword ?? state.keyword;
    final nextCategoryId = clearCategory
        ? null
        : categoryId ?? state.categoryId;
    final hasExistingBooks = state.books.isNotEmpty;
    state = state.copyWith(
      status: hasExistingBooks ? BooksStatus.refreshing : BooksStatus.loading,
      keyword: nextKeyword,
      categoryId: nextCategoryId,
      clearCategory: clearCategory,
      clearError: true,
      authorId: authorId,
      publisherId: publisherId,
      minPrice: minPrice,
      maxPrice: maxPrice,
      inStock: inStock,
      sortBy: sortBy,
      direction: direction,
    );
    try {
      final result = await _repository.getBooks(
        keyword: nextKeyword,
        categoryId: nextCategoryId,
        authorId: state.authorId,
        publisherId: state.publisherId,
        minPrice: state.minPrice,
        maxPrice: state.maxPrice,
        inStock: state.inStock,
        sortBy: state.sortBy,
        direction: state.direction,
        authorId: state.authorId,
        publisherId: state.publisherId,
        minPrice: state.minPrice,
        maxPrice: state.maxPrice,
        inStock: state.inStock,
        sortBy: state.sortBy,
        direction: state.direction,
      );
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
      final result = await _repository.getBooks(
        keyword: state.keyword,
        categoryId: state.categoryId,
        authorId: state.authorId,
        publisherId: state.publisherId,
        minPrice: state.minPrice,
        maxPrice: state.maxPrice,
        inStock: state.inStock,
        sortBy: state.sortBy,
        direction: state.direction,
        authorId: state.authorId,
        publisherId: state.publisherId,
        minPrice: state.minPrice,
        maxPrice: state.maxPrice,
        inStock: state.inStock,
        sortBy: state.sortBy,
        direction: state.direction,
        page: state.page + 1,
      );
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

  Future<void> loadCategories() async {
    try {
      final categories = await _repository.getCategories();
      state = state.copyWith(categories: categories);
    } on ApiException catch (error) {
      state = state.copyWith(errorMessage: _friendlyMessage(error));
    } catch (_) {
      state = state.copyWith(errorMessage: '分类暂时无法加载');
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

final bookDetailProvider = FutureProvider.autoDispose.family<BookDetail, int>((
  ref,
  bookId,
) {
  return ref.watch(bookRepositoryProvider).getBookDetail(bookId);
});

final bookReviewsProvider = FutureProvider.autoDispose
    .family<BookReviewSummary, ({int bookId, int page})>((ref, key) {
      return ref.watch(bookRepositoryProvider).getReviews(key.bookId, page: key.page);
    });
