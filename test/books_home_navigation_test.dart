import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final booksSource = File(
    'lib/features/books/presentation/books_page.dart',
  ).readAsStringSync();
  final searchSource = File(
    'lib/features/books/presentation/search_results_page.dart',
  ).readAsStringSync();

  test('home header provides a search box before the cart action', () {
    final header = booksSource.substring(
      booksSource.indexOf('class _BooksHeader'),
      booksSource.indexOf('class _BooksHero'),
    );

    expect(header, contains('searchController'));
    expect(booksSource, contains("hintText: '搜索书名'"));
    expect(
      header.indexOf('child: _HeaderSearch('),
      lessThan(header.indexOf("label: const Text('购物车')")),
    );
  });

  test('home is labelled as the online bookstore without catalog filters', () {
    expect(booksSource, contains('BOOKS  ·  在线书店'));
    expect(booksSource, isNot(contains('BOOKS  ·  在线书库')));
    expect(booksSource, isNot(contains('class _CategoryBar')));
    expect(booksSource, isNot(contains('class _BookFilters')));
    expect(booksSource, isNot(contains("label: '全部'")));
  });

  test('search results retain the catalog filters', () {
    expect(searchSource, contains('class _SearchFilters'));
    expect(searchSource, contains('全部一级分类'));
    expect(searchSource, contains('全部二级分类'));
    expect(searchSource, contains('只看有库存'));
  });
}
