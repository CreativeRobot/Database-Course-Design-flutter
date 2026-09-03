import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/category.dart';
import '../data/promotion_models.dart';
import 'books_controller.dart';

enum HomepageStatus { initial, loading, success, failure }

class HomepageState {
  const HomepageState({
    this.status = HomepageStatus.initial,
    this.newReleases = const [],
    this.bestSellers = const [],
    this.upcoming = const [],
    this.categories = const [],
    this.promotions = const PromotionHome(),
    this.errorMessage,
  });

  final HomepageStatus status;
  final List<Book> newReleases;
  final List<Book> bestSellers;
  final List<Book> upcoming;
  final List<BookCategory> categories;
  final PromotionHome promotions;
  final String? errorMessage;

  HomepageState copyWith({
    HomepageStatus? status,
    List<Book>? newReleases,
    List<Book>? bestSellers,
    List<Book>? upcoming,
    List<BookCategory>? categories,
    PromotionHome? promotions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomepageState(
      status: status ?? this.status,
      newReleases: newReleases ?? this.newReleases,
      bestSellers: bestSellers ?? this.bestSellers,
      upcoming: upcoming ?? this.upcoming,
      categories: categories ?? this.categories,
      promotions: promotions ?? this.promotions,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

typedef HomepageBooksLoader =
    Future<List<Book>> Function({required String sortBy, required int size});
typedef HomepageCategoriesLoader = Future<List<BookCategory>> Function();
typedef HomepagePromotionsLoader = Future<PromotionHome> Function();

class HomepageSections {
  static List<Book> limit(Iterable<Book> books, {int count = 10}) {
    return books.take(count).toList(growable: false);
  }

  static int promotionPageIndex(int currentIndex, int pageCount, int delta) {
    if (pageCount <= 0) return 0;
    return (currentIndex + delta) % pageCount;
  }

  static List<Book> randomCandidates(Iterable<Book> books) {
    final seenIds = <int>{};
    return books
        .where((book) => book.id > 0 && seenIds.add(book.id))
        .toList(growable: false);
  }

  static List<Book> upcoming(
    List<Book> books, {
    DateTime? now,
    int count = 10,
  }) {
    final current = now ?? DateTime.now();
    final result = books
        .where(
          (book) =>
              book.preSale &&
              book.preSaleReleaseTime != null &&
              book.preSaleReleaseTime!.isAfter(current),
        )
        .toList();
    result.sort(
      (a, b) => a.preSaleReleaseTime!.compareTo(b.preSaleReleaseTime!),
    );
    return limit(result, count: count);
  }

  static List<BookCategory> categories(
    List<BookCategory> values, {
    int count = 10,
    bool preserveOrder = false,
  }) {
    final roots = values
        .where((category) => category.parentId == null)
        .toList();
    if (preserveOrder) {
      return roots.take(count).toList(growable: false);
    }
    final indexed = <BookCategory, int>{
      for (var index = 0; index < roots.length; index++) roots[index]: index,
    };
    roots.sort((a, b) {
      final priority = _priority(a.name).compareTo(_priority(b.name));
      return priority == 0 ? indexed[a]!.compareTo(indexed[b]!) : priority;
    });
    return roots.take(count).toList(growable: false);
  }

  static int _priority(String name) {
    const preferred = ['文学', '小说', '计算机', '教材', '教育', '经济', '儿童', '生活'];
    final index = preferred.indexWhere(name.contains);
    return index < 0 ? preferred.length : index;
  }
}

class HomepageController extends StateNotifier<HomepageState> {
  HomepageController({
    required HomepageBooksLoader loadBooks,
    required HomepageCategoriesLoader loadCategories,
    HomepagePromotionsLoader? loadPromotions,
  }) : _loadBooks = loadBooks,
       _loadCategories = loadCategories,
       _loadPromotions = loadPromotions ?? _emptyPromotions,
       super(const HomepageState());

  final HomepageBooksLoader _loadBooks;
  final HomepageCategoriesLoader _loadCategories;
  final HomepagePromotionsLoader _loadPromotions;

  static Future<PromotionHome> _emptyPromotions() async =>
      const PromotionHome();

  Future<void> load() async {
    if (state.status == HomepageStatus.loading) return;
    state = state.copyWith(status: HomepageStatus.loading, clearError: true);
    Object? firstError;
    List<Book> latest = const [];
    List<Book> sales = const [];
    List<BookCategory> categories = const [];
    PromotionHome promotions = const PromotionHome();
    final latestFuture = _loadBooks(sortBy: 'latest', size: 60);
    final salesFuture = _loadBooks(sortBy: 'sales', size: 20);
    final categoriesFuture = _loadCategories();
    final promotionsFuture = _loadPromotions();
    try {
      latest = await latestFuture;
    } catch (error) {
      firstError ??= error;
    }
    try {
      sales = await salesFuture;
    } catch (error) {
      firstError ??= error;
    }
    try {
      categories = await categoriesFuture;
    } catch (error) {
      firstError ??= error;
    }
    try {
      promotions = await promotionsFuture;
    } catch (error) {
      firstError ??= error;
    }
    final current = DateTime.now();
    final upcoming = HomepageSections.upcoming(latest, now: current);
    final newReleases = HomepageSections.limit(
      latest.where(
        (book) =>
            !book.preSale ||
            book.preSaleReleaseTime == null ||
            !book.preSaleReleaseTime!.isAfter(current),
      ),
    );
    state = state.copyWith(
      status:
          firstError != null &&
              latest.isEmpty &&
              sales.isEmpty &&
              categories.isEmpty
          ? HomepageStatus.failure
          : HomepageStatus.success,
      newReleases: newReleases,
      bestSellers: HomepageSections.limit(sales),
      upcoming: upcoming,
      categories: HomepageSections.categories(categories, preserveOrder: true),
      promotions: promotions,
      errorMessage: firstError == null ? null : _friendlyMessage(firstError),
    );
  }

  String _friendlyMessage(Object error) {
    if (error is ApiException) {
      if (error.message == 'Unable to connect to the server') {
        return '暂时无法连接服务，请确认后端已经启动';
      }
      if (error.message == 'Connection to server timed out') {
        return '连接服务超时，请稍后再试';
      }
      return error.message;
    }
    return '首页内容暂时无法加载';
  }
}

final homepageControllerProvider =
    StateNotifierProvider<HomepageController, HomepageState>((ref) {
      final repository = ref.watch(bookRepositoryProvider);
      return HomepageController(
        loadBooks: ({required sortBy, required size}) async {
          final page = await repository.getBooks(
            sortBy: sortBy,
            size: size,
            inStock: true,
          );
          return page.records;
        },
        loadCategories: repository.getFeaturedCategories,
        loadPromotions: repository.getPromotionHome,
      );
    });
