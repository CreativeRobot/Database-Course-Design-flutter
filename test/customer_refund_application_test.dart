import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order detail offers a guarded per-item after-sales application flow', () {
    final source = File(
      'lib/features/orders/presentation/order_detail_page.dart',
    ).readAsStringSync();
    expect(source, contains('申请售后'));
    expect(source, contains('_RefundApplicationDialog'));
    expect(source, contains('refund.isActive'));
    expect(source, contains('CustomerRefundRequest'));
    expect(source, contains('createRefund('));
  });
}
