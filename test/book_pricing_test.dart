import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_bookstore/core/utils/book_pricing.dart';

void main() {
  group('BookPricing', () {
    test('calculates a discounted sale price rounded to cents', () {
      expect(
        BookPricing.salePrice(originalPrice: 99.99, discountPercent: 85),
        84.99,
      );
      expect(BookPricing.salePrice(originalPrice: 100, discountPercent: 0), 0);
      expect(
        BookPricing.salePrice(originalPrice: 100, discountPercent: 100),
        100,
      );
    });

    test('rejects discount rates outside 0 to 100 percent', () {
      expect(
        () => BookPricing.salePrice(originalPrice: 100, discountPercent: -1),
        throwsArgumentError,
      );
      expect(
        () => BookPricing.salePrice(originalPrice: 100, discountPercent: 101),
        throwsArgumentError,
      );
    });

    test('derives the current discount rate from persisted prices', () {
      expect(
        BookPricing.discountPercent(originalPrice: 100, salePrice: 72.5),
        72.5,
      );
      expect(BookPricing.discountPercent(originalPrice: 0, salePrice: 0), 100);
    });
  });
}
