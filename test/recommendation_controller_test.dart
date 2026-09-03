import 'package:flutter_application_bookstore/core/network/api_exception.dart';
import 'package:flutter_application_bookstore/features/recommendations/data/recommendation_models.dart';
import 'package:flutter_application_bookstore/features/recommendations/data/recommendation_repository.dart';
import 'package:flutter_application_bookstore/features/recommendations/presentation/recommendation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the latest recommendations when a refresh fails', () async {
    final source = _FakeRecommendationDataSource([
      const RecommendationHome(
        source: 'PERSONALIZED',
        books: [
          RecommendationBook(
            id: 1,
            isbn: '9780000000001',
            title: '测试图书',
            publisherId: 1,
            publisherName: '出版社',
            originalPrice: 50,
            salePrice: 40,
            stock: 2,
            status: 'ON_SALE',
            reason: '与你喜欢的分类相似',
          ),
        ],
      ),
      const ApiException(statusCode: 500, code: 500, message: '服务暂不可用'),
    ]);
    final controller = RecommendationController(source);

    await controller.load();
    await controller.refresh();

    expect(controller.state.home?.books.single.title, '测试图书');
    expect(controller.state.status, RecommendationStatus.failure);
    expect(controller.state.errorMessage, '服务暂不可用');
  });

  test('loads another recommendation page and appends it to the existing list', () async {
    final source = _PagedRecommendationDataSource();
    final controller = RecommendationController(source);

    await controller.load(limit: 2);
    await controller.loadMore();

    expect(source.pages, [1, 2]);
    expect(controller.state.home?.books.map((book) => book.id), [1, 2, 3]);
    expect(controller.state.home?.hasMore, isFalse);
  });
}

class _FakeRecommendationDataSource implements RecommendationDataSource {
  _FakeRecommendationDataSource(this._responses);

  final List<Object> _responses;

  @override
  Future<RecommendationHome> fetchHome({int limit = 12, int page = 1}) async {
    final response = _responses.removeAt(0);
    if (response is Exception) throw response;
    return response as RecommendationHome;
  }
}

class _PagedRecommendationDataSource implements RecommendationDataSource {
  final pages = <int>[];

  @override
  Future<RecommendationHome> fetchHome({int limit = 12, int page = 1}) async {
    pages.add(page);
    if (page == 1) {
      return const RecommendationHome(
        source: 'POPULAR',
        books: [
          RecommendationBook(
            id: 1, isbn: 'isbn-1', title: '一', publisherId: 1,
            publisherName: '出版社', originalPrice: 10, salePrice: 8,
            stock: 1, status: 'ON_SALE', reason: '热门畅销书',
          ),
          RecommendationBook(
            id: 2, isbn: 'isbn-2', title: '二', publisherId: 1,
            publisherName: '出版社', originalPrice: 10, salePrice: 8,
            stock: 1, status: 'ON_SALE', reason: '热门畅销书',
          ),
        ],
        page: 1, size: 2, hasMore: true,
      );
    }
    return const RecommendationHome(
      source: 'POPULAR',
      books: [
        RecommendationBook(
          id: 3, isbn: 'isbn-3', title: '三', publisherId: 1,
          publisherName: '出版社', originalPrice: 10, salePrice: 8,
          stock: 1, status: 'ON_SALE', reason: '热门畅销书',
        ),
      ],
      page: 2, size: 2, hasMore: false,
    );
  }
}
