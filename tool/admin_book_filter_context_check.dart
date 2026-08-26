import 'package:flutter_application_bookstore/features/admin/presentation/admin_book_filter.dart';

void expectEqual(Object? actual, Object? expected, String message) {
  if (actual != expected) {
    throw StateError('$message: expected $expected, got $actual');
  }
}

void main() {
  const author = AdminBookFilter.author(id: 7, name: '余华');
  expectEqual(author.authorId, 7, 'author ID');
  expectEqual(author.publisherId, null, 'author publisher ID');
  expectEqual(author.categoryId, null, 'author category ID');
  expectEqual(author.managementLabel, '正在管理：余华 的图书', 'author label');

  const publisher = AdminBookFilter.publisher(id: 11, name: '人民文学出版社');
  expectEqual(publisher.authorId, null, 'publisher author ID');
  expectEqual(publisher.publisherId, 11, 'publisher ID');
  expectEqual(publisher.categoryId, null, 'publisher category ID');
  expectEqual(publisher.managementLabel, '正在管理：人民文学出版社 的图书', 'publisher label');

  const category = AdminBookFilter.category(id: 13, name: '小说');
  expectEqual(category.authorId, null, 'category author ID');
  expectEqual(category.publisherId, null, 'category publisher ID');
  expectEqual(category.categoryId, 13, 'category ID');
  expectEqual(category.managementLabel, '正在管理：小说 分类图书', 'category label');
}
