import 'dart:async';

import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_application_bookstore/core/network/api_client.dart';
import 'package:flutter_application_bookstore/core/storage/token_storage.dart';
import 'package:flutter_application_bookstore/data/models/book/book.dart';
import 'package:flutter_application_bookstore/data/models/common/page_response.dart';
import 'package:flutter_application_bookstore/features/books/data/book_repository.dart';
import 'package:flutter_application_bookstore/features/community/data/community_models.dart';
import 'package:flutter_application_bookstore/features/community/data/community_repository.dart';
import 'package:flutter_application_bookstore/features/community/presentation/community_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('older feed response cannot overwrite a newer search', () async {
    final repository = _DelayedCommunityRepository();
    final controller = CommunityFeedController(repository);

    final older = controller.load(keyword: '旧关键词');
    final newer = controller.load(keyword: '新关键词');
    repository.complete(1, _page(_post(2, '新结果')));
    await newer;
    repository.complete(0, _page(_post(1, '旧结果')));
    await older;

    expect(controller.state.keyword, '新关键词');
    expect(controller.state.posts.map((post) => post.id), [2]);
  });

  test('community book options load every available page', () async {
    final repository = _PagedBookRepository();

    final books = await loadCommunityBookOptions(repository);

    expect(books.map((book) => book.id), [1, 2]);
    expect(repository.requestedPages, [1, 2]);
  });
}

CommunityPost _post(int id, String title) => CommunityPost(
  id: id,
  userId: 1,
  authorName: '读者',
  title: title,
  content: '正文',
  status: 1,
  imageUrls: const [],
  books: const [],
  commentCount: 0,
);

PageResponse<CommunityPost> _page(CommunityPost post) =>
    PageResponse(records: [post], total: 1, page: 1, size: 10, totalPages: 1);

class _DelayedCommunityRepository extends CommunityRepository {
  _DelayedCommunityRepository()
    : super(
        ApiClient(
          config: const AppConfig(baseUrl: 'http://localhost'),
          tokenStorage: TokenStorage(),
        ),
      );

  final _requests = <Completer<PageResponse<CommunityPost>>>[];

  @override
  Future<PageResponse<CommunityPost>> listPosts({
    String? keyword,
    int? bookId,
    int page = 1,
    int size = 10,
  }) {
    final completer = Completer<PageResponse<CommunityPost>>();
    _requests.add(completer);
    return completer.future;
  }

  void complete(int index, PageResponse<CommunityPost> page) {
    _requests[index].complete(page);
  }
}

Book _book(int id) => Book(
  id: id,
  isbn: 'isbn-$id',
  title: '图书$id',
  publisherId: 1,
  publisherName: '出版社',
  originalPrice: 10,
  salePrice: 8,
  stock: 1,
  status: 'ON_SALE',
);

class _PagedBookRepository extends BookRepository {
  _PagedBookRepository()
    : super(
        ApiClient(
          config: const AppConfig(baseUrl: 'http://localhost'),
          tokenStorage: TokenStorage(),
        ),
      );

  final requestedPages = <int>[];

  @override
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
    requestedPages.add(page);
    return PageResponse(
      records: [_book(page)],
      total: 2,
      page: page,
      size: size,
      totalPages: 2,
    );
  }
}
