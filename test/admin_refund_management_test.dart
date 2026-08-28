import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_bookstore/core/constants/api_paths.dart';
import 'package:flutter_application_bookstore/features/admin/data/admin_models.dart';

void main() {
  test('refund model parses type/status and monetary fields', () {
    final request = AdminRefundRequest.fromJson({
      'id': 21,
      'refundNo': 'REF001',
      'orderId': 7,
      'orderNo': 'BS001',
      'orderItemId': 11,
      'userId': 3,
      'username': 'alice',
      'bookId': 9,
      'bookTitle': 'Database Systems',
      'type': 'RETURN_REFUND',
      'status': 'PENDING',
      'quantity': 1,
      'itemQuantity': 2,
      'refundedQuantity': 0,
      'amount': '12.50',
      'reason': '破损',
      'reviewRemark': '',
      'createTime': '2026-08-28T10:00:00',
    });
    expect(request.typeLabel, '退货退款');
    expect(request.statusLabel, '待审核');
    expect(request.amount, 12.5);
    expect(request.pending, isTrue);
  });

  test('refund admin paths expose list/detail/review endpoints', () {
    expect(ApiPaths.adminRefunds, '/api/admin/refunds');
    expect(ApiPaths.adminRefund(21), '/api/admin/refunds/21');
    expect(ApiPaths.adminRefundReview(21), '/api/admin/refunds/21/review');
  });
}
