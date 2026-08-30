import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_bookstore/data/models/book/book.dart';
import 'package:flutter_application_bookstore/features/cart/data/cart_models.dart';
import 'package:flutter_application_bookstore/features/orders/data/order_models.dart';

void main() {
  test('book parses active presale fields', () {
    final book = Book.fromJson({
      'id': 1,
      'isbn': '9780000000001',
      'title': '预售图书',
      'publisherId': 2,
      'publisherName': '测试出版社',
      'originalPrice': 100,
      'salePrice': 80,
      'stock': 50,
      'status': 'ON_SALE',
      'preSale': true,
      'preSaleReleaseTime': '2026-09-15T10:00:00',
    });

    expect(book.preSale, true);
    expect(book.preSaleReleaseTime, DateTime(2026, 9, 15, 10));
  });

  test('cart and order lines retain presale shipping notice', () {
    final cartItem = CartItem.fromJson({
      'id': 3,
      'bookId': 1,
      'isbn': '9780000000001',
      'title': '预售图书',
      'salePrice': 80,
      'stock': 50,
      'bookStatus': 'ON_SALE',
      'quantity': 1,
      'selected': true,
      'available': true,
      'subtotal': 80,
      'preSale': true,
      'preSaleReleaseTime': '2026-09-15T10:00:00',
    });
    final line = OrderLine.fromJson({
      'id': 4,
      'bookId': 1,
      'bookTitle': '预售图书',
      'isbn': '9780000000001',
      'unitPrice': 80,
      'quantity': 1,
      'subtotal': 80,
      'preSale': true,
      'preSaleReleaseTime': '2026-09-15T10:00:00',
    });

    expect(cartItem.preSale, true);
    expect(line.preSale, true);
    expect(line.preSaleReleaseTime, DateTime(2026, 9, 15, 10));
  });
}
