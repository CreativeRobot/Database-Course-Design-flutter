import 'package:flutter_application_bookstore/app/router/app_route_paths.dart';
import 'package:flutter_application_bookstore/app/router/app_routes.dart';
import 'package:flutter_application_bookstore/core/constants/api_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('community API and route paths are stable', () {
    expect(ApiPaths.communityPosts, '/api/community/posts');
    expect(ApiPaths.communityPost(5), '/api/community/posts/5');
    expect(ApiPaths.communityComments(5), '/api/community/posts/5/comments');
    expect(ApiPaths.communityImageUpload, '/api/uploads/images');
    expect(AppRoutePaths.community, '/community');
    expect(AppRoutePaths.newCommunityPost, '/community/posts/new');
    expect(AppRoutePaths.communityPost(5), '/community/posts/5');
  });

  test('community feed detail and editor routes are registered', () {
    final paths = buildAppRoutes().whereType<GoRoute>().map(
      (route) => route.path,
    );

    expect(paths, contains(AppRoutePaths.community));
    expect(paths, contains('${AppRoutePaths.community}/posts/:postId'));
    expect(paths, contains(AppRoutePaths.newCommunityPost));
    final orderedPaths = paths.toList(growable: false);
    expect(
      orderedPaths.indexOf(AppRoutePaths.newCommunityPost),
      lessThan(
        orderedPaths.indexOf('${AppRoutePaths.community}/posts/:postId'),
      ),
      reason: 'The literal /new route must precede the dynamic postId route.',
    );
  });
}
