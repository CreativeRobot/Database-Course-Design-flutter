import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refund repository uses the three customer API contracts', () {
    final source = File(
      'lib/features/refunds/data/refund_repository.dart',
    ).readAsStringSync();
    expect(source, contains('ApiPaths.orderRefunds(orderId)'));
    expect(source, contains("'page': page"));
    expect(source, contains('ApiPaths.refund(refundId)'));
    expect(source, contains('application.toJson()'));
  });
}
