import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_bookstore/features/cart/presentation/commerce_widgets.dart';

void main() {
  testWidgets('BookstoreBrand uses the storefront cart mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BookstoreBrand())),
    );

    expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
    expect(find.text('书间'), findsOneWidget);
  });
}
