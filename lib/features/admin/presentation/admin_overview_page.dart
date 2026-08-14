import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/presentation/commerce_widgets.dart';
import '../data/admin_models.dart';
import 'admin_page.dart';
import 'admin_providers.dart';

class AdminOverviewPage extends ConsumerWidget {
  const AdminOverviewPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminStatisticsProvider);
    return AdminPageBody(
      child: AdminAsync(
        value: value,
        retry: () => ref.invalidate(adminStatisticsProvider),
        data: (stats) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '经营概览',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: '刷新数据',
                  onPressed: () => ref.invalidate(adminStatisticsProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (_, constraints) {
                final width = constraints.maxWidth < 700
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(
                      '已完成订单',
                      '${stats.completedOrderCount}',
                      Icons.task_alt,
                      width,
                    ),
                    _Metric(
                      '累计销售额',
                      money(stats.salesAmount),
                      Icons.payments_outlined,
                      width,
                    ),
                    _Metric(
                      '售出图书',
                      '${stats.soldQuantity} 本',
                      Icons.auto_stories_outlined,
                      width,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _SalesChart(stats.monthlySales),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (_, constraints) {
                final compact = constraints.maxWidth < 900;
                final children = [
                  Expanded(
                    child: _RankPanel(
                      title: '畅销图书',
                      rows: stats.topBooks
                          .map((e) => (e.name, e.quantity, e.amount))
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: _RankPanel(
                      title: '分类销售',
                      rows: stats.categorySales
                          .map((e) => (e.name, e.quantity, e.amount))
                          .toList(),
                    ),
                  ),
                ];
                return compact
                    ? Column(
                        children: [
                          children[0].child,
                          const SizedBox(height: 18),
                          children[1].child,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          children[0],
                          const SizedBox(width: 18),
                          children[1],
                        ],
                      );
              },
            ),
            const SizedBox(height: 18),
            AdminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '低库存预警',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  if (stats.lowStockBooks.isEmpty)
                    const Text(
                      '当前没有低库存图书',
                      style: TextStyle(color: AdminColors.muted),
                    )
                  else
                    for (final book in stats.lowStockBooks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.warning_amber,
                          color: Color(0xFFC47C16),
                        ),
                        title: Text(book.title),
                        subtitle: Text('ISBN ${book.isbn}'),
                        trailing: Text(
                          '库存 ${book.stock}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
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

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.width);
  final String label;
  final String value;
  final IconData icon;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AdminPanel(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            color: AdminColors.green.withValues(alpha: .1),
            child: Icon(icon, color: AdminColors.green),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AdminColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SalesChart extends StatelessWidget {
  const _SalesChart(this.items);
  final List<MonthlySale> items;
  @override
  Widget build(BuildContext context) {
    final max = items.fold<double>(0, (m, e) => e.amount > m ? e.amount : m);
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('月度销售趋势', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const Text('暂无已完成订单数据', style: TextStyle(color: AdminColors.muted))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  children: [
                    SizedBox(
                      width: 66,
                      child: Text(
                        item.month,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 12,
                            width: max == 0
                                ? 0
                                : c.maxWidth * item.amount / max,
                            color: AdminColors.green,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: Text(
                        money(item.amount),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RankPanel extends StatelessWidget {
  const _RankPanel({required this.title, required this.rows});
  final String title;
  final List<(String, int, double)> rows;
  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('暂无数据', style: TextStyle(color: AdminColors.muted))
        else
          for (var i = 0; i < rows.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 13,
                child: Text('${i + 1}', style: const TextStyle(fontSize: 11)),
              ),
              title: Text(
                rows[i].$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('售出 ${rows[i].$2}'),
              trailing: Text(money(rows[i].$3)),
            ),
      ],
    ),
  );
}
