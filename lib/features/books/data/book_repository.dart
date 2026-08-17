import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/book_detail.dart';
import '../../../data/models/book/book_review.dart';
import '../../../data/models/book/category.dart';
import '../../../data/models/book/book_filter_option.dart';
import '../../../data/models/common/page_response.dart';

class BookRepository {
  const BookRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PageResponse<Book>> getBooks({
    String? keyword,
    int? categoryId,
    int? authorId,
    int? publisherId,
    double? minPrice,
    double? maxPrice,
    bool inStock = false,
    String sortBy = 'latest',
    String direction = 'desc',
    int page = 1,
    int size = 12,
  }) async {
    final response = await _apiClient.get<PageResponse<Book>>(
      ApiPaths.books,
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        if (categoryId != null) 'categoryId': categoryId,
        if (authorId != null) 'authorId': authorId,
        if (publisherId != null) 'publisherId': publisherId,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (inStock) 'inStock': true,
        'sortBy': sortBy,
        'direction': direction,
        'page': page,
        'size': size,
      },
      parser: (value) =>
          PageResponse.fromJson(value, itemParser: Book.fromJson),
    );
    return response.data;
  }

  Future<List<BookCategory>> getCategories() async {
    final response = await _apiClient.get<List<BookCategory>>(
      ApiPaths.categories,
      parser: (value) {
        if (value is! List) {
          throw const FormatException('分类响应必须是数组');
        }
        return value.map(BookCategory.fromJson).toList(growable: false);
      },
    );
    return response.data;
  }

  Future<List<BookFilterOption>> getAuthors() async =>
      _getOptions(ApiPaths.authors);

  Future<List<BookFilterOption>> getPublishers() async =>
      _getOptions(ApiPaths.publishers);

  Future<List<BookFilterOption>> _getOptions(String path) async {
    final response = await _apiClient.get<PageResponse<BookFilterOption>>(
      path,
      queryParameters: const {'page': 1, 'size': 100},
      parser: (value) =>
          PageResponse.fromJson(value, itemParser: BookFilterOption.fromJson),
    );
    return response.data.records;
  }

  Future<BookDetail> getBookDetail(int bookId) async {
    final response = await _apiClient.get<BookDetail>(
      ApiPaths.book(bookId),
      parser: BookDetail.fromJson,
    );
    return response.data;
  }

  Future<BookReviewSummary> getReviews(
    int bookId, {
    int page = 1,
    int size = 10,
  }) async {
    final response = await _apiClient.get<BookReviewSummary>(
      ApiPaths.bookReviews(bookId),
      queryParameters: {'page': page, 'size': size},
      parser: BookReviewSummary.fromJson,
    );
    return response.data;
  }
}
