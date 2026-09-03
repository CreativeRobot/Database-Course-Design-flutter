import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_bookstore/core/constants/api_paths.dart';
import 'package:flutter_application_bookstore/features/admin/presentation/admin_community_posts_page.dart';
import 'package:flutter_application_bookstore/features/admin/presentation/admin_page.dart';

void main() {
  test('admin community post API paths are stable', () {
    expect(ApiPaths.adminCommunityPosts, '/api/admin/community/posts');
    expect(
      ApiPaths.adminCommunityPostStatus(7),
      '/api/admin/community/posts/7/status',
    );
  });

  test('admin navigation exposes community post management', () {
    expect(AdminSection.communityPosts.path, 'community-posts');
    expect(AdminSection.communityPosts.label, '帖子管理');
  });

  test('community post moderation labels match status semantics', () {
    expect(adminCommunityPostStatusLabel(1), '正常');
    expect(adminCommunityPostStatusLabel(0), '已屏蔽');
    expect(adminCommunityPostActionLabel(1), '屏蔽');
    expect(adminCommunityPostActionLabel(0), '恢复');
  });

  test('admin community posts page can be constructed', () {
    expect(const AdminCommunityPostsPage(), isA<AdminCommunityPostsPage>());
  });
}
