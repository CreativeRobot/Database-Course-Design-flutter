import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final booksSource = File(
    'lib/features/books/presentation/books_page.dart',
  ).readAsStringSync();
  final profileSource = File(
    'lib/features/profile/presentation/profile_page.dart',
  ).readAsStringSync();
  final adminSource = File(
    'lib/features/admin/presentation/admin_page.dart',
  ).readAsStringSync();

  test('guest homepage loads the recommendation flow', () {
    expect(
      booksSource,
      contains('ref.read(recommendationControllerProvider.notifier).load();'),
    );
    expect(booksSource, contains("if (session?.role == 'ADMIN')"));
    expect(booksSource, isNot(contains('登录后查看专属推荐')));
  });

  test('profile page reuses the shared bookstore brand', () {
    expect(profileSource, contains('BookstoreBrand'));
    expect(profileSource, isNot(contains('class _ProfileBrand')));
  });

  test('admin top bar no longer links back to the storefront', () {
    expect(adminSource, isNot(contains('查看商城')));
    expect(adminSource, isNot(contains("context.go('/books')")));
  });
}
