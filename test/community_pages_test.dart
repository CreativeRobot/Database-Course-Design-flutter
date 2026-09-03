import 'package:flutter_application_bookstore/features/community/presentation/community_page.dart';
import 'package:flutter_application_bookstore/features/community/presentation/post_detail_page.dart';
import 'package:flutter_application_bookstore/features/community/presentation/post_editor_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community pages expose stable constructors and editor image limit', () {
    expect(const CommunityPage(), isA<CommunityPage>());
    expect(const PostDetailPage(postId: 5).postId, 5);
    expect(const PostEditorPage(), isA<PostEditorPage>());
    expect(PostEditorPage.maxImages, 9);
  });
}
