import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/books/presentation/books_page.dart',
  ).readAsStringSync();

  test(
    'book header exposes the administrator shortcut and direct profile access',
    () {
      expect(
        source,
        contains(
          "final isAdmin = isAuthenticated && session!.role == 'ADMIN';",
        ),
      );
      expect(source, contains("if (isAdmin) ...["));
      expect(source, contains("onPressed: onAdmin"));
      expect(source, contains("label: const Text('管理台')"));
      final header = source.substring(
        source.indexOf('class _BooksHeader'),
        source.indexOf('class _HeaderSearch'),
      );
      expect(header, contains('onTap: onProfile'));
      expect(header, isNot(contains('PopupMenuButton<String>')));
    },
  );
}
