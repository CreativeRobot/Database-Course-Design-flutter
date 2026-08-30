import 'dart:io';

import 'package:flutter_application_bookstore/core/utils/book_presale.dart';
import 'package:flutter_application_bookstore/data/models/book/book.dart';
import 'package:flutter_application_bookstore/features/cart/data/cart_models.dart';
import 'package:flutter_application_bookstore/features/orders/data/order_models.dart';

void main() {
  final releaseTime = DateTime(2026, 9, 15, 10);
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
  final orderLine = OrderLine.fromJson({
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

  if (!book.preSale || book.preSaleReleaseTime != releaseTime) {
    throw StateError('Book pre-sale JSON parsing failed.');
  }
  if (!cartItem.preSale || cartItem.preSaleReleaseTime != releaseTime) {
    throw StateError('Cart pre-sale JSON parsing failed.');
  }
  if (!orderLine.preSale || orderLine.preSaleReleaseTime != releaseTime) {
    throw StateError('Order pre-sale snapshot parsing failed.');
  }
  if (!isActivePreSale(true, releaseTime, now: DateTime(2026, 8, 30))) {
    throw StateError('Active pre-sale policy failed.');
  }
  if (preSaleNotice(releaseTime) != '预售 · 预计 2026-09-15 10:00 发售') {
    throw StateError('Pre-sale notice formatting failed.');
  }

  stdout.writeln('Book pre-sale model checks passed.');
}
