import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/common/page_response.dart';
import '../../../core/errors/app_error.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/commerce_widgets.dart';
import 'admin_catalog_pages.dart';
import 'admin_providers.dart';
import 'admin_orders_reviews_pages.dart';
import 'admin_overview_page.dart';

enum AdminSection {
  overview('overview', '经营概览', Icons.dashboard_outlined),
  books('books', '图书管理', Icons.menu_book_outlined),
  authors('authors', '作者管理', Icons.edit_note_outlined),
  publishers('publishers', '出版社管理', Icons.apartment_outlined),
  categories('categories', '分类管理', Icons.account_tree_outlined),
  orders('orders', '订单管理', Icons.receipt_long_outlined),
  reviews('reviews', '评价审核', Icons.rate_review_outlined),
  inventory('inventory', '库存流水', Icons.inventory_2_outlined);

  const AdminSection(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

class AdminPage extends ConsumerWidget {
  const AdminPage({this.section = AdminSection.overview, super.key});
  final AdminSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = switch (section) {
      AdminSection.overview => const AdminOverviewPage(),
      AdminSection.books => const AdminBooksPage(),
      AdminSection.authors => const AdminAuthorsPage(),
      AdminSection.publishers => const AdminPublishersPage(),
      AdminSection.categories => const AdminCategoriesPage(),
      AdminSection.orders => const AdminOrdersPage(),
      AdminSection.reviews => const AdminReviewsPage(),
      AdminSection.inventory => const AdminInventoryPage(),
    };
    return Scaffold(
      backgroundColor: AdminColors.canvas,
      drawer: MediaQuery.sizeOf(context).width < 850
          ? Drawer(child: _AdminNav(selected: section))
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (MediaQuery.sizeOf(context).width >= 850)
              SizedBox(width: 232, child: _AdminNav(selected: section)),
            Expanded(
              child: Column(
                children: [
                  _TopBar(section: section),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(.012, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(section),
                        child: content,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.section});
  final AdminSection section;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AdminColors.line)),
      ),
      child: Row(
        children: [
          if (MediaQuery.sizeOf(context).width < 850)
            Builder(
              builder: (context) => IconButton(
                tooltip: '打开导航',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ),
          Text(
            section.label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _AdminNav extends ConsumerWidget {
  const _AdminNav({required this.selected});
  final AdminSection selected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    return ColoredBox(
      color: const Color(0xFF202523),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Row(
                children: [BookstoreBrand(color: Colors.white, fontSize: 18)],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final item in AdminSection.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _AdminNavItem(
                        item: item,
                        selected: selected == item,
                        onTap: () {
                          Navigator.maybePop(context);
                          if (item == AdminSection.books) {
                            ref.read(adminBookFilterProvider.notifier).state =
                                null;
                          }
                          context.go('/admin/${item.path}');
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white12,
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      session?.nickname.isNotEmpty == true
                          ? session!.nickname
                          : session?.username ?? '管理员',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: '退出登录',
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white70,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  const _AdminNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AdminSection item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: .12)
            : Colors.transparent,
        border: Border.all(
          color: selected
              ? Colors.white.withValues(alpha: .18)
              : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOutCubic,
                  tween: ColorTween(
                    begin: Colors.white70,
                    end: selected ? Colors.white : Colors.white70,
                  ),
                  builder: (_, color, __) =>
                      Icon(item.icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOutCubic,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    child: Text(item.label),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class AdminColors {
  static const canvas = Color(0xFFF4F5F3);
  static const line = Color(0xFFE1E4E0);
  static const ink = Color(0xFF202523);
  static const muted = Color(0xFF69716C);
  static const green = Color(0xFF2C6B4F);
  static const red = Color(0xFFA33B32);
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AdminColors.line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: child,
  );
}

class AdminWideTable extends StatelessWidget {
  const AdminWideTable({required this.child, this.minWidth = 820, super.key});
  final Widget child;
  final double minWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: constraints.maxWidth < minWidth
            ? minWidth
            : constraints.maxWidth,
        child: child,
      ),
    ),
  );
}

class AdminPageBody extends StatelessWidget {
  const AdminPageBody({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(22),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: child,
      ),
    ),
  );
}

class AdminAsync<T> extends StatelessWidget {
  const AdminAsync({
    required this.value,
    required this.data,
    required this.retry,
    super.key,
  });
  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => const SizedBox(
      height: 280,
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (error, _) => SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 34),
            const SizedBox(height: 10),
            Text(appErrorMessage(error), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载'),
            ),
          ],
        ),
      ),
    ),
  );
}

class AdminPagination extends StatelessWidget {
  const AdminPagination({required this.page, required this.onPage, super.key});
  final PageResponse<dynamic> page;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    final totalPages = page.totalPages == 0 ? 1 : page.totalPages;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '共 ${page.total} 条 · 第 ${page.page}/$totalPages 页',
            style: const TextStyle(color: AdminColors.muted, fontSize: 12),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: '上一页',
            onPressed: page.page > 1 ? () => onPage(page.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: '下一页',
            onPressed: page.page < totalPages
                ? () => onPage(page.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    ) ??
    false;

void showAdminMessage(BuildContext context, Object message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message is String && !message.startsWith('ApiException(')
              ? message
              : appErrorMessage(message),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

void showAdminError(BuildContext context, Object error) =>
    showAppError(context, error);
