import 'package:flutter/material.dart';
import 'package:flutter_application_bookstore/features/books/presentation/books_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('community navigation is an icon button with community tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityNavigationButton(onPressed: () {})),
      ),
    );

    expect(find.byTooltip('社区'), findsOneWidget);
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.text('社区'), findsNothing);
  });
}
