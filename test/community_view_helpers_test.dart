import 'package:flutter_application_bookstore/data/models/book/book.dart';
import 'package:flutter_application_bookstore/features/community/data/community_models.dart';
import 'package:flutter_application_bookstore/features/community/presentation/community_view_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('arrangeCommunityComments', () {
    test('places replies directly after their parent comment', () {
      final comments = [
        _comment(4, parentId: 99),
        _comment(1),
        _comment(2),
        _comment(3, parentId: 1),
        _comment(5, parentId: 1),
      ];

      final arranged = arrangeCommunityComments(comments);

      expect(arranged.map((comment) => comment.id), [1, 3, 5, 2, 4]);
    });
  });

  group('filterCommunityBookOptions', () {
    test('keeps selected books visible before keyword matches', () {
      final books = [
        _book(1, '数据库系统概论'),
        _book(2, 'Dart 编程语言'),
        _book(3, 'Flutter 实战'),
      ];

      final filtered = filterCommunityBookOptions(books, {3}, 'dart');

      expect(filtered.map((book) => book.id), [3, 2]);
    });

    test('returns all books with selected books first for blank keyword', () {
      final books = [
        _book(1, '数据库系统概论'),
        _book(2, 'Dart 编程语言'),
        _book(3, 'Flutter 实战'),
      ];

      final filtered = filterCommunityBookOptions(books, {2}, '   ');

      expect(filtered.map((book) => book.id), [2, 1, 3]);
    });
  });
}

CommunityComment _comment(int id, {int? parentId}) => CommunityComment(
  id: id,
  postId: 10,
  userId: id,
  authorName: '读者$id',
  content: '评论$id',
  status: 1,
  parentId: parentId,
);

Book _book(int id, String title) => Book(
  id: id,
  isbn: 'isbn-$id',
  title: title,
  publisherId: 1,
  publisherName: '出版社',
  originalPrice: 10,
  salePrice: 10,
  stock: 10,
  status: 'ON_SALE',
);
