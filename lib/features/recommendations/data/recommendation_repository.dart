import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import 'recommendation_models.dart';

abstract interface class RecommendationDataSource {
  Future<RecommendationHome> fetchHome({int limit = 12});
}

class RecommendationRepository implements RecommendationDataSource {
  const RecommendationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<RecommendationHome> fetchHome({int limit = 12}) async {
    if (limit < 1 || limit > 20) {
      throw ArgumentError.value(limit, 'limit', '推荐数量必须在 1 到 20 之间');
    }
    final response = await _apiClient.get<RecommendationHome>(
      ApiPaths.recommendationsHome,
      queryParameters: {'limit': limit},
      parser: RecommendationHome.fromJson,
    );
    return response.data;
  }
}
