import '../lib/core/utils/book_pricing.dart';

void main() {
  _expectClose(
    BookPricing.salePrice(originalPrice: 99.99, discountPercent: 85),
    84.99,
  );
  _expectClose(
    BookPricing.salePrice(originalPrice: 100, discountPercent: 0),
    0,
  );
  _expectClose(
    BookPricing.salePrice(originalPrice: 100, discountPercent: 100),
    100,
  );
  _expectThrows(
    () => BookPricing.salePrice(originalPrice: 100, discountPercent: -1),
  );
  _expectThrows(
    () => BookPricing.salePrice(originalPrice: 100, discountPercent: 101),
  );
  _expectClose(
    BookPricing.discountPercent(originalPrice: 100, salePrice: 72.5),
    72.5,
  );
  _expectClose(
    BookPricing.discountPercent(originalPrice: 0, salePrice: 0),
    100,
  );
  print('book pricing checks passed');
}

void _expectClose(double actual, double expected) {
  if ((actual - expected).abs() > 0.000001) {
    throw StateError('Expected $expected, got $actual');
  }
}

void _expectThrows(void Function() callback) {
  try {
    callback();
  } on ArgumentError {
    return;
  }
  throw StateError('Expected ArgumentError');
}
