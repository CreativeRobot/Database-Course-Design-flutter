/// Pricing helpers shared by catalog and administration flows.
class BookPricing {
  const BookPricing._();

  /// Calculates the sale price for a rate expressed as a percentage.
  ///
  /// A rate of 100 means the original price, while 0 means free.
  static double salePrice({
    required double originalPrice,
    required double discountPercent,
  }) {
    _validateOriginalPrice(originalPrice);
    _validateDiscountPercent(discountPercent);
    return _roundToCents(originalPrice * discountPercent / 100);
  }

  /// Converts a persisted original/sale price pair back to a percentage rate.
  static double discountPercent({
    required double originalPrice,
    required double salePrice,
  }) {
    _validateOriginalPrice(originalPrice);
    if (!salePrice.isFinite || salePrice < 0 || salePrice > originalPrice) {
      throw ArgumentError.value(salePrice, 'salePrice', '售价必须在原价与 0 之间');
    }
    if (originalPrice == 0) return 100;
    return _roundToCents(salePrice / originalPrice * 100);
  }

  static void _validateOriginalPrice(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, 'originalPrice', '原价不能为负数');
    }
  }

  static void _validateDiscountPercent(double value) {
    if (!value.isFinite || value < 0 || value > 100) {
      throw ArgumentError.value(value, 'discountPercent', '折扣必须在 0 到 100 之间');
    }
  }

  static double _roundToCents(double value) =>
      (value * 100).roundToDouble() / 100;
}
