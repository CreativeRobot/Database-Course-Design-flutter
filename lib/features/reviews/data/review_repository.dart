import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import 'review_models.dart';

class ReviewRepository {
  const ReviewRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<UserReview>> listMyReviews() async {
    final response = await _apiClient.get<List<UserReview>>(
      ApiPaths.myReviews,
      parser: (value) {
        if (value is! List) {
          throw const FormatException('我的评价响应必须是数组');
        }
        return value.map(UserReview.fromJson).toList(growable: false);
      },
    );
    return response.data;
  }

  Future<UserReview> createReview({
    required int orderItemId,
    required int rating,
    required String content,
  }) async {
    final response = await _apiClient.post<UserReview>(
      ApiPaths.reviews,
      data: {
        'orderItemId': orderItemId,
        'rating': rating,
        'content': content.trim(),
      },
      parser: UserReview.fromJson,
    );
    return response.data;
  }

  Future<UserReview> updateReview({
    required int reviewId,
    required int rating,
    required String content,
  }) async {
    final response = await _apiClient.put<UserReview>(
      ApiPaths.review(reviewId),
      data: {'rating': rating, 'content': content.trim()},
      parser: UserReview.fromJson,
    );
    return response.data;
  }
}
