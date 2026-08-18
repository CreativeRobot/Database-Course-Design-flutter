import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final adminSource = File(
    'lib/features/admin/presentation/admin_page.dart',
  ).readAsStringSync();
  final booksSource = File(
    'lib/features/books/presentation/books_page.dart',
  ).readAsStringSync();
  final profileSource = File(
    'lib/features/profile/presentation/profile_page.dart',
  ).readAsStringSync();
  final ordersSource = File(
    'lib/features/orders/presentation/orders_controller.dart',
  ).readAsStringSync();

  test('admin navigation animates newly selected content', () {
    expect(adminSource, contains('AnimatedSwitcher('));
    expect(adminSource, contains('ValueKey(section)'));
    expect(adminSource, contains('SlideTransition('));
  });

  test(
    'book header opens profile directly instead of showing an account menu',
    () {
      final header = booksSource.substring(
        booksSource.indexOf('class _BooksHeader'),
        booksSource.indexOf('class _BookStoreMark'),
      );

      expect(header, contains('onTap: onProfile'));
      expect(header, isNot(contains('PopupMenuButton<String>')));
    },
  );

  test(
    'profile keeps address editing in personal details and shows shipped books',
    () {
      final overview = profileSource.substring(
        profileSource.indexOf('class _OverviewSection'),
        profileSource.indexOf('class _ProfileEditor'),
      );
      final profileEditor = profileSource.substring(
        profileSource.indexOf('class _ProfileEditor'),
        profileSource.indexOf('class _AddressSection'),
      );

      expect(overview, isNot(contains('_AddressSection(')));
      expect(profileEditor, contains('_AddressSection('));
      expect(profileSource, contains('_ShippingOrdersPanel'));
      expect(ordersSource, contains('shippedOrdersProvider'));
      expect(ordersSource, contains("status: 'SHIPPED'"));
    },
  );
}
