import 'package:flutter_application_bookstore/data/models/book/category.dart';
import 'package:flutter_application_bookstore/data/models/book/category_hierarchy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses category parents and finds two-level filtering options', () {
    final categories = [
      BookCategory.fromJson({'id': 1, 'name': '计算机'}),
      BookCategory.fromJson({
        'id': 2,
        'name': '数据库',
        'parentId': 1,
        'parentName': '计算机',
      }),
      BookCategory.fromJson({
        'id': 3,
        'name': '小说',
        'parentId': 4,
        'parentName': '文学',
      }),
      BookCategory.fromJson({'id': 4, 'name': '文学'}),
    ];
    final hierarchy = CategoryHierarchy(categories);

    expect(categories[1].parentId, 1);
    expect(hierarchy.roots.map((item) => item.name), ['计算机', '文学']);
    expect(hierarchy.childrenOf(1).map((item) => item.name), ['数据库']);
    expect(hierarchy.parentIdOf(2), 1);
    expect(hierarchy.parentIdOf(1), isNull);
    expect(hierarchy.childrenOf(1).map((item) => item.id), isNot(contains(3)));
  });

  test('parses nested children returned by a category tree endpoint', () {
    final category = BookCategory.fromJson({
      'id': 1,
      'name': '计算机',
      'children': [
        {'id': 2, 'name': '数据库', 'parentId': 1},
      ],
    });

    expect(category.children.single.name, '数据库');
  });
}
