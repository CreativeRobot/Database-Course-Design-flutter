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
}

class _FakeRecommendationDataSource implements RecommendationDataSource {
  _FakeRecommendationDataSource(this._responses);

  final List<Object> _responses;

  @override
  Future<RecommendationHome> fetchHome({int limit = 12}) async {
    final response = _responses.removeAt(0);
    if (response is Exception) throw response;
    return response as RecommendationHome;
  }
}
