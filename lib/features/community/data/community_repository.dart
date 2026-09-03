import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/common/page_response.dart';
import 'community_models.dart';

class CommunityRepository {
  const CommunityRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<PageResponse<CommunityPost>> listPosts({
    String? keyword,
    int? bookId,
    int page = 1,
    int size = 10,
  }) async {
    final response = await _apiClient.get<PageResponse<CommunityPost>>(
      ApiPaths.communityPosts,
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        'bookId': ?bookId,
        'page': page,
        'size': size,
      },
      parser: communityPostPage,
    );
    return response.data;
  }

  Future<PageResponse<CommunityPost>> listMyPosts({
    int page = 1,
    int size = 50,
  }) async {
    final response = await _apiClient.get<PageResponse<CommunityPost>>(
      ApiPaths.myCommunityPosts,
      queryParameters: {'page': page, 'size': size},
      parser: communityPostPage,
    );
    return response.data;
  }

  Future<CommunityPost> getPost(int postId) async =>
      (await _apiClient.get<CommunityPost>(
        ApiPaths.communityPost(postId),
        parser: CommunityPost.fromJson,
      )).data;

  Future<PageResponse<CommunityComment>> listComments(
    int postId, {
    int page = 1,
    int size = 50,
  }) async => (await _apiClient.get<PageResponse<CommunityComment>>(
    ApiPaths.communityComments(postId),
    queryParameters: {'page': page, 'size': size},
    parser: communityCommentPage,
  )).data;

  Future<CommunityPost> createPost(CommunityPostDraft draft) async =>
      (await _apiClient.post<CommunityPost>(
        ApiPaths.communityPosts,
        data: draft.toJson(),
        parser: CommunityPost.fromJson,
      )).data;

  Future<CommunityComment> createComment(
    int postId, {
    required String content,
    int? parentId,
  }) async => (await _apiClient.post<CommunityComment>(
    ApiPaths.communityComments(postId),
    data: {'content': content.trim(), 'parentId': ?parentId},
    parser: CommunityComment.fromJson,
  )).data;

  Future<UploadedCommunityImage> uploadImage({
    required List<int> bytes,
    required String filename,
  }) async => (await _apiClient.postMultipart<UploadedCommunityImage>(
    ApiPaths.communityImageUpload,
    bytes: bytes,
    filename: filename,
    parser: UploadedCommunityImage.fromJson,
  )).data;
}
