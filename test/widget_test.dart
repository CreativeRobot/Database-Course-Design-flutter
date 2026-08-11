import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_bookstore/app/app.dart';

void main() {
  testWidgets('BookStore app shows the login page', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BookStoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
  });
}
