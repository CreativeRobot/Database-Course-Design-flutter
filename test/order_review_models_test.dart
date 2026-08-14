import 'package:flutter_application_bookstore/features/orders/data/order_models.dart';
import 'package:flutter_application_bookstore/features/orders/presentation/orders_controller.dart';
import 'package:flutter_application_bookstore/features/reviews/data/review_models.dart';
import 'package:flutter_application_bookstore/features/reviews/presentation/reviews_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order model exposes receipt and payment capabilities', () {
    final shipped = BookOrder.fromJson(_orderJson('SHIPPED'));
    final completed = BookOrder.fromJson(_orderJson('COMPLETED'));
    final pending = BookOrder.fromJson(_orderJson('PENDING_PAYMENT'));

    expect(shipped.canConfirmReceipt, isTrue);
    expect(completed.canConfirmReceipt, isFalse);
    expect(pending.canPay, isTrue);
    expect(shipped.items.single.id, 10);
  });

  test('user review parses the order item relationship and timestamps', () {
    final review = UserReview.fromJson({
      'id': 4,
      'bookId': 7,
      'bookTitle': 'Database Systems',
      'orderItemId': 10,
      'reviewerName': '读者',
      'rating': 5,
      'content': '很实用',
      'status': 1,
      'createTime': '2026-08-13T10:20:00',
      'updateTime': '2026-08-13T10:30:00',
    });

    expect(review.orderItemId, 10);
    expect(review.rating, 5);
    expect(review.createTime, isNotNull);
    expect(review.updateTime, isNotNull);
  });

  test('user review rejects missing identifiers', () {
    expect(
      () => UserReview.fromJson({'rating': 5, 'content': 'missing ids'}),
      throwsFormatException,
    );
  });

  test('order pagination reports whether another page is available', () {
    const firstPage = OrdersState(page: 1, totalPages: 3, total: 24);
    const lastPage = OrdersState(page: 3, totalPages: 3, total: 24);

    expect(firstPage.hasMore, isTrue);
    expect(lastPage.hasMore, isFalse);
  });

  test('review pagination exposes only the requested batch', () {
    final reviews = List.generate(
      12,
      (index) => UserReview.fromJson({
        'id': index + 1,
        'bookId': index + 1,
        'bookTitle': 'Book $index',
        'orderItemId': 100 + index,
        'rating': 5,
        'content': '',
        'status': 1,
      }),
    );
    final state = ReviewsState(reviews: reviews, visibleCount: 10);

    expect(state.visibleReviews, hasLength(10));
    expect(state.hasMore, isTrue);
    expect(state.reviewFor(111), isNotNull);
  });
}

Map<String, dynamic> _orderJson(String status) => {
  'id': 2,
  'orderNo': 'BS202608130001',
  'status': status,
  'totalAmount': 79.9,
  'discountAmount': 0,
  'shippingFee': 0,
  'payableAmount': 79.9,
  'receiverName': '张三',
  'receiverPhone': '13800000000',
  'receiverAddress': '深圳市南山区',
  'remark': '',
  'items': [
    {
      'id': 10,
      'bookId': 7,
      'bookTitle': 'Database Systems',
      'isbn': '9780000000007',
      'unitPrice': 79.9,
      'quantity': 1,
      'subtotal': 79.9,
    },
  ],
};
