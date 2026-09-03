import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/book_filter_option.dart';
import '../../../data/models/book/category.dart';
import '../../../data/models/common/page_response.dart';
import '../data/book_repository.dart';
import 'books_controller.dart';

enum SearchResultsStatus { initial, loading, success, failure }

class SearchResultsState {
  const SearchResultsState({
    this.status = SearchResultsStatus.initial,
    this.books = const [],
    this.categories = const [],
    this.authors = const [],
    this.publishers = const [],
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
    this.optionsError,
    this.loadingMore = false,
  });

  final SearchResultsStatus status;
  final List<Book> books;
  final List<BookCategory> categories;
  final List<BookFilterOption> authors;
  final List<BookFilterOption> publishers;
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
  final String? optionsError;
  final bool loadingMore;

  bool get hasMore => totalPages > page;

  SearchResultsState copyWith({
    SearchResultsStatus? status,
    List<Book>? books,
    List<BookCategory>? categories,
    List<BookFilterOption>? authors,
    List<BookFilterOption>? publishers,
    String? keyword,
    int? categoryId,
    bool clearCategory = false,
    int? authorId,
    bool clearAuthor = false,
    int? publisherId,
    bool clearPublisher = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    bool? inStock,
    String? sortBy,
    String? direction,
    int? page,
    int? total,
    int? totalPages,
    String? errorMessage,
    bool clearError = false,
    String? optionsError,
    bool clearOptionsError = false,
    bool? loadingMore,
  }) {
    return SearchResultsState(
      status: status ?? this.status,
      books: books ?? this.books,
      categories: categories ?? this.categories,
      authors: authors ?? this.authors,
      publishers: publishers ?? this.publishers,
      keyword: keyword ?? this.keyword,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      authorId: clearAuthor ? null : authorId ?? this.authorId,
      publisherId: clearPublisher ? null : publisherId ?? this.publisherId,
      minPrice: clearMinPrice ? null : minPrice ?? this.minPrice,
      maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
      inStock: inStock ?? this.inStock,
      sortBy: sortBy ?? this.sortBy,
      direction: direction ?? this.direction,
      page: page ?? this.page,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      optionsError: clearOptionsError
          ? null
          : optionsError ?? this.optionsError,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class SearchResultsController extends StateNotifier<SearchResultsState> {
  SearchResultsController(
    this._repository, {
    String initialKeyword = '',
    int? initialCategoryId,
  }) : super(
         SearchResultsState(
           keyword: initialKeyword.trim(),
           categoryId: initialCategoryId,
         ),
       );

  final BookRepository _repository;

  Future<void> loadInitial() async {
    if (state.status != SearchResultsStatus.initial) return;
    await Future.wait([_loadPage(), _loadOptions()]);
  }

  Future<void> submitKeyword(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty && state.keyword.isEmpty) return;
    state = state.copyWith(keyword: trimmed, clearError: true);
    await _loadPage();
  }

  Future<void> updateFilters({
    int? categoryId,
    bool clearCategory = false,
    int? authorId,
    bool clearAuthor = false,
    int? publisherId,
    bool clearPublisher = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    bool? inStock,
    String? sortBy,
  }) async {
    final nextMin = clearMinPrice ? null : minPrice ?? state.minPrice;
    final nextMax = clearMaxPrice ? null : maxPrice ?? state.maxPrice;
    if (nextMin != null && nextMax != null && nextMin > nextMax) {
      state = state.copyWith(errorMessage: '最低价不能高于最高价');
      return;
    }
    state = state.copyWith(
      categoryId: categoryId,
      clearCategory: clearCategory,
      authorId: authorId,
      clearAuthor: clearAuthor,
      publisherId: publisherId,
      clearPublisher: clearPublisher,
      minPrice: minPrice,
      clearMinPrice: clearMinPrice,
      maxPrice: maxPrice,
      clearMaxPrice: clearMaxPrice,
      inStock: inStock,
      sortBy: sortBy,
      clearError: true,
    );
    await _loadPage();
  }

  Future<void> retry() => _loadPage();

  Future<void> loadMore() async {
    if (state.loadingMore ||
        state.status == SearchResultsStatus.loading ||
        !state.hasMore) {
      return;
    }
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final result = await _getBooks(page: state.page + 1);
      state = state.copyWith(
        status: SearchResultsStatus.success,
        books: [...state.books, ...result.records],
        page: result.page,
        total: result.total,
        totalPages: result.totalPages,
        loadingMore: false,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        loadingMore: false,
        errorMessage: _friendlyMessage(error),
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false, errorMessage: '更多图书暂时无法加载');
    }
  }

  Future<void> _loadPage() async {
    final hasBooks = state.books.isNotEmpty;
    state = state.copyWith(
      status: hasBooks
          ? SearchResultsStatus.success
          : SearchResultsStatus.loading,
      page: 1,
      clearError: true,
    );
    try {
      final result = await _getBooks();
      state = state.copyWith(
        status: SearchResultsStatus.success,
        books: result.records,
        page: result.page,
        total: result.total,
        totalPages: result.totalPages,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        status: SearchResultsStatus.failure,
        errorMessage: _friendlyMessage(error),
      );
    } catch (_) {
      state = state.copyWith(
        status: SearchResultsStatus.failure,
        errorMessage: '图书暂时无法加载，请稍后再试',
      );
    }
  }

  Future<void> _loadOptions() async {
    try {
      final categories = await _repository.getCategories();
      state = state.copyWith(categories: categories);
    } catch (_) {
      state = state.copyWith(optionsError: '分类筛选暂时无法加载');
    }
    try {
      final authors = await _repository.getAuthors();
      state = state.copyWith(authors: authors);
    } catch (_) {
      state = state.copyWith(optionsError: '作者筛选暂时无法加载');
    }
    try {
      final publishers = await _repository.getPublishers();
      state = state.copyWith(publishers: publishers);
    } catch (_) {
      state = state.copyWith(optionsError: '出版社筛选暂时无法加载');
    }
  }

  Future<PageResponse<Book>> _getBooks({int page = 1}) {
    return _repository.getBooks(
      keyword: state.keyword,
      categoryId: state.categoryId,
      authorId: state.authorId,
      publisherId: state.publisherId,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
      inStock: state.inStock,
      sortBy: state.sortBy,
      direction: state.direction,
      page: page,
    );
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

final searchResultsControllerProvider = StateNotifierProvider.autoDispose
    .family<
      SearchResultsController,
      SearchResultsState,
      ({String keyword, int? categoryId})
    >((ref, key) {
      return SearchResultsController(
        ref.watch(bookRepositoryProvider),
        initialKeyword: key.keyword,
        initialCategoryId: key.categoryId,
      );
    });
