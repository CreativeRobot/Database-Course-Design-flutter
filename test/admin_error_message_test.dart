import 'package:flutter/material.dart';
import 'package:flutter_application_bookstore/core/network/api_exception.dart';
import 'package:flutter_application_bookstore/features/admin/presentation/admin_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin action errors show backend messages', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(key: key, builder: (_) => const SizedBox.shrink()),
        ),
      ),
    );

    showAdminError(
      key.currentContext!,
      const ApiException(statusCode: 409, code: 409, message: '该作者已关联图书，无法删除'),
    );
    await tester.pump();

    expect(find.text('该作者已关联图书，无法删除'), findsOneWidget);
  });
}
