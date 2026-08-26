import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_bookstore/features/admin/presentation/admin_book_filter.dart';

void main() {
  group('AdminBookFilter', () {
    test(
      'author filter keeps only the author query parameter and management label',
      () {
        const filter = AdminBookFilter.author(id: 7, name: '余华');

        expect(filter.authorId, 7);
        expect(filter.publisherId, isNull);
        expect(filter.categoryId, isNull);
        expect(filter.managementLabel, '正在管理：余华 的图书');
      },
    );

    test('publisher and category filters keep their own query parameters', () {
      const publisher = AdminBookFilter.publisher(id: 11, name: '人民文学出版社');
      const category = AdminBookFilter.category(id: 13, name: '小说');

      expect(publisher.publisherId, 11);
      expect(publisher.authorId, isNull);
      expect(publisher.categoryId, isNull);
      expect(publisher.managementLabel, '正在管理：人民文学出版社 的图书');

      expect(category.categoryId, 13);
      expect(category.authorId, isNull);
      expect(category.publisherId, isNull);
      expect(category.managementLabel, '正在管理：小说 分类图书');
    });
  });
}
