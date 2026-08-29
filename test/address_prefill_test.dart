import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_bookstore/features/profile/presentation/profile_page.dart';

void main() {
  test('address draft keeps existing value and falls back to profile value', () {
    expect(addressFieldValue(existing: '已有姓名', fallback: '个人资料姓名'), '已有姓名');
    expect(addressFieldValue(existing: '  ', fallback: '个人资料姓名'), '个人资料姓名');
    expect(addressFieldValue(existing: null, fallback: '13800000000'), '13800000000');
    expect(addressFieldValue(existing: null, fallback: null), '');
  });
}
