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
    'lib/features/orders/presentation/orders_page.dart',
  ).readAsStringSync();
  final orderDetailSource = File(
    'lib/features/orders/presentation/order_detail_page.dart',
  ).readAsStringSync();
  final adminOrdersSource = File(
    'lib/features/admin/presentation/admin_orders_reviews_pages.dart',
  ).readAsStringSync();
  final adminOverviewSource = File(
    'lib/features/admin/presentation/admin_overview_page.dart',
  ).readAsStringSync();
  final adminModelsSource = File(
    'lib/features/admin/data/admin_models.dart',
  ).readAsStringSync();

  test('admin navigation animates newly selected content', () {
    expect(adminSource, contains('AnimatedSwitcher('));
    expect(adminSource, contains('ValueKey(section)'));
    expect(adminSource, contains('SlideTransition('));
  });

  test('admin navigation softens selected item changes', () {
    expect(adminSource, contains('AnimatedContainer('));
    expect(adminSource, contains('Curves.easeInOutCubic'));
    expect(adminSource, contains('border: Border.all'));
  });

  test(
    'book header opens profile directly instead of showing an account menu',
    () {
      final header = booksSource.substring(
        booksSource.indexOf('class _BooksHeader'),
        booksSource.indexOf('class _HeaderSearch'),
      );

      expect(header, contains('onTap: onProfile'));
      expect(header, isNot(contains('PopupMenuButton<String>')));
    },
  );

  test('book header leaves order access to the user center', () {
    final header = booksSource.substring(
      booksSource.indexOf('class _BooksHeader'),
      booksSource.indexOf('class _HeaderSearch'),
    );

    expect(header, isNot(contains('onOrders')));
    expect(header, isNot(contains("Text('订单')")));
  });

  test('user center keeps profile editing out of the navigation', () {
    expect(
      profileSource,
      contains('ProfileSection { overview, orders, security }'),
    );
    expect(profileSource, isNot(contains('ProfileSection.profile')));
    expect(profileSource, isNot(contains('class _ProfileEditor')));
    expect(profileSource, isNot(contains('编辑资料')));
    expect(profileSource, contains('ProfileSection.orders =>'));
  });

  test(
    'overview owns nickname, contact, and address management entry points',
    () {
      final overview = profileSource.substring(
        profileSource.indexOf('class _OverviewSection'),
        profileSource.indexOf('class _MetricTile'),
      );

      expect(overview, contains('onEditNickname'));
      expect(overview, contains('onEditEmail'));
      expect(overview, contains('onEditPhone'));
      expect(overview, contains('onManageAddresses'));
      expect(overview, contains('profile.phone'));
      expect(overview, contains('手机号'));
      expect(profileSource, contains('class _AddressManagementDialog'));
    },
  );

  test('orders can be rendered as embedded user-center content', () {
    expect(profileSource, contains('OrdersContent('));
    expect(ordersSource, contains('class OrdersContent'));
    expect(ordersSource, contains('embedded'));
    expect(
      profileSource,
      contains('ProfileSection.orders => OrdersContent(embedded: true)'),
    );
    expect(ordersSource, contains("'SHIPPED'"));
  });
  test('payment and shipment success feedback dismisses quickly', () {
    expect(
      orderDetailSource,
      contains("duration: Duration(milliseconds: 1500)"),
    );
    expect(
      adminOrdersSource,
      contains("duration: const Duration(milliseconds: 1500)"),
    );
    expect(adminSource, contains('Duration? duration'));
  });

  test('admin overview renders a daily quantity and revenue line trend', () {
    expect(adminModelsSource, contains('dailySales'));
    expect(adminModelsSource, contains('class DailySale'));
    expect(
      adminOverviewSource,
      contains('_DailySalesTrendChart(stats.dailySales)'),
    );
    expect(adminOverviewSource, contains('CustomPaint('));
    expect(adminOverviewSource, contains("'售出数量'"));
    expect(adminOverviewSource, contains("'销售额'"));
    expect(adminOverviewSource, contains("'数量：本'"));
    expect(adminOverviewSource, contains("'金额：元'"));
    expect(
      adminOverviewSource,
      contains('crossAxisAlignment: CrossAxisAlignment.stretch'),
    );
  });
}
