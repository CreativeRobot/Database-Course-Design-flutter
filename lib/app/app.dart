import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

class BookStoreApp extends ConsumerWidget {
  const BookStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'BookStore',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF171717),
          onPrimary: Colors.white,
          surface: Color(0xFFF7F6F2),
          onSurface: Color(0xFF171717),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F6F2),
        fontFamily: 'sans',
        inputDecorationTheme: const InputDecorationTheme(
          errorStyle: TextStyle(fontSize: 11),
        ),
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
