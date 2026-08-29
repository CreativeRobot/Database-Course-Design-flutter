import 'package:flutter_application_bookstore/core/constants/api_paths.dart';
import 'package:flutter_application_bookstore/features/refunds/data/refund_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('customer refund models', () {
    test('parses the customer refund response and supplies Chinese labels', () {
      final refund = CustomerRefundRequest.fromJson({
        'id': 88,
        'refundNo': 'REF202608290001',
        'orderId': 12,
        'orderNo': 'ORD202608290001',
        'orderItemId': 34,
        'bookId': 56,
        'bookTitle': '数据库系统概念',
        'type': 'RETURN_REFUND',
        'status': 'PENDING',
        'quantity': 2,
        'itemQuantity': 3,
        'refundedQuantity': 1,
        'amount': 99.80,
        'reason': '图书破损',
        'reviewRemark': null,
        'createTime': '2026-08-29T10:20:30',
      });

      expect(refund.id, 88);
      expect(refund.type, RefundType.returnRefund);
      expect(refund.typeLabel, '退货退款');
      expect(refund.status, RefundStatus.pending);
      expect(refund.statusLabel, '待审核');
      expect(refund.amount, 99.80);
      expect(refund.createTime, DateTime.parse('2026-08-29T10:20:30'));
      expect(refund.isActive, isTrue);
    });

    test(
      'serializes a trimmed application payload with exact backend fields',
      () {
        const application = RefundApplication(
          orderItemId: 34,
          type: RefundType.refundOnly,
          quantity: 1,
          reason: '  不想要了  ',
        );

        expect(application.toJson(), {
          'orderItemId': 34,
          'type': 'REFUND_ONLY',
          'quantity': 1,
          'reason': '不想要了',
        });
      },
    );

    test('defines the three existing customer refund endpoint paths', () {
      expect(ApiPaths.orderRefunds(12), '/api/orders/12/refunds');
      expect(ApiPaths.refunds, '/api/orders/refunds');
      expect(ApiPaths.refund(88), '/api/orders/refunds/88');
    });
  });
}
