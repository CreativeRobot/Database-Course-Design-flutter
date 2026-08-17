import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_bookstore/data/models/book/book_review.dart';
import 'package:flutter_application_bookstore/features/books/presentation/books_page.dart';
import 'package:flutter_application_bookstore/features/cart/presentation/commerce_widgets.dart';

void main() {
  testWidgets('commerce loading state renders its message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CommerceLoadingState(message: '正在加载图书')),
    );

    expect(find.text('正在加载图书'), findsOneWidget);
  });

  test('book page dependencies expose the review model', () {
    expect(const BooksPage(), isA<BooksPage>());

    final review = BookReview.fromJson({
      'id': 1,
      'bookId': 2,
      'reviewerName': '读者',
      'rating': 5,
      'content': '很好',
      'createTime': '2026-08-17T10:00:00',
    });

    expect(review.bookId, 2);
    expect(review.reviewerName, '读者');
  });
}
