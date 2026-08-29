import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer refund history has route and orders entry point', () {
    final paths = File(
      'lib/app/router/app_route_paths.dart',
    ).readAsStringSync();
    final routes = File('lib/app/router/app_routes.dart').readAsStringSync();
    final orders = File(
      'lib/features/orders/presentation/orders_page.dart',
    ).readAsStringSync();
    expect(paths, contains("static const refunds = '/refunds'"));
    expect(routes, contains('CustomerRefundsPage'));
    expect(orders, contains('我的售后记录'));
  });
}
