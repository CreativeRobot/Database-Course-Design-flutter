import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_bookstore/app/app.dart';

void main() {
  testWidgets('BookStore app shows the books route', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BookStoreApp(),
      ),
    );

    expect(find.text('图书'), findsOneWidget);
    expect(find.text('图书列表将在 books 功能模块中实现。'), findsOneWidget);
  });
}
