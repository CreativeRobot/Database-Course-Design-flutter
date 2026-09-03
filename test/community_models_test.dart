import 'package:flutter_application_bookstore/features/community/data/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses community post with images books and comment count', () {
    final post = CommunityPost.fromJson({
      'id': 5,
      'userId': 1,
      'authorName': '读者',
      'authorAvatar': '/uploads/a.jpg',
      'title': '读书分享',
      'content': '正文',
      'status': 1,
      'createTime': '2026-09-03T10:00:00',
      'imageUrls': ['/uploads/posts/1/a.jpg'],
      'bookIds': [10],
      'bookTitles': ['数据库系统概论'],
      'commentCount': 3,
    });
    expect(post.id, 5);
    expect(post.imageUrls.single, '/uploads/posts/1/a.jpg');
    expect(post.books.single.title, '数据库系统概论');
    expect(post.commentCount, 3);
  });

  test('builds trimmed create post payload and enforces nine images', () {
    final draft = CommunityPostDraft(
      title: ' 标题 ',
      content: ' 正文 ',
      imageUrls: List.generate(9, (index) => '/$index.jpg'),
      bookIds: const [2, 2, 3],
    );
    expect(draft.toJson()['title'], '标题');
    expect(draft.toJson()['bookIds'], [2, 3]);
    expect(
      () => CommunityPostDraft(
        title: '标题',
        content: '正文',
        imageUrls: List.generate(10, (index) => '/$index.jpg'),
      ),
      throwsArgumentError,
    );
  });

  test('parses a reply comment', () {
    final comment = CommunityComment.fromJson({
      'id': 8,
      'postId': 5,
      'userId': 2,
      'authorName': '另一位读者',
      'parentId': 7,
      'content': '同意',
      'status': 1,
    });
    expect(comment.parentId, 7);
    expect(comment.isReply, isTrue);
  });
}
