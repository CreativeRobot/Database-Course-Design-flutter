import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_bookstore/core/utils/book_presale.dart';

void main() {
  test('presale is active only before its release time', () {
    final now = DateTime(2026, 8, 30, 12);

    expect(isActivePreSale(true, DateTime(2026, 9, 15, 10), now: now), true);
    expect(
      isActivePreSale(true, DateTime(2026, 8, 30, 11, 59), now: now),
      false,
    );
    expect(isActivePreSale(false, null, now: now), false);
  });

  test('presale notice contains a readable release time', () {
    expect(
      preSaleNotice(DateTime(2026, 9, 15, 10, 5)),
      '预售 · 预计 2026-09-15 10:05 发售',
    );
  });
}
