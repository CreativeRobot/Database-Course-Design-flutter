import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/books',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const _ScaffoldPage(
        title: '登录',
        message: '登录页面将在 auth 功能模块中实现。',
      ),
    ),
    GoRoute(
      path: '/books',
      builder: (context, state) => const _ScaffoldPage(
        title: '图书',
        message: '图书列表将在 books 功能模块中实现。',
      ),
    ),
    GoRoute(
      path: '/cart',
      builder: (context, state) => const _ScaffoldPage(
        title: '购物车',
        message: '购物车将在 cart 功能模块中实现。',
      ),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const _ScaffoldPage(
        title: '我的订单',
        message: '订单页面将在 orders 功能模块中实现。',
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const _ScaffoldPage(
        title: '个人中心',
        message: '用户资料和地址将在 profile 功能模块中实现。',
      ),
    ),
  ],
);

class _ScaffoldPage extends StatelessWidget {
  const _ScaffoldPage({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
