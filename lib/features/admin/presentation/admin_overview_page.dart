import 'dart:math' as math;

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
            _DailySalesTrendChart(stats.dailySales),
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

class _DailySalesTrendChart extends StatelessWidget {
  const _DailySalesTrendChart(this.items);

  final List<DailySale> items;

  @override
  Widget build(BuildContext context) {
    final maxQuantity = items.fold<int>(
      0,
      (max, item) => item.quantity > max ? item.quantity : max,
    );
    final maxAmount = items.fold<double>(
      0,
      (max, item) => item.amount > max ? item.amount : max,
    );

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '近 7 日销售趋势',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '按订单完成日期统计',
            style: TextStyle(color: AdminColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _TrendLegend(color: Color(0xFF147D64), label: '售出数量'),
              _TrendLegend(color: Color(0xFF2F6FE4), label: '销售额'),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text('暂无已完成订单数据', style: TextStyle(color: AdminColors.muted))
          else ...[
            SizedBox(
              height: 220,
              child: LayoutBuilder(
                builder: (_, constraints) => CustomPaint(
                  painter: _DailySalesTrendPainter(
                    items: items,
                    maxQuantity: maxQuantity,
                    maxAmount: maxAmount,
                  ),
                  child: SizedBox(width: constraints.maxWidth),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                Text(
                  '数量 0–$maxQuantity 本',
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '销售额 0–${money(maxAmount)}',
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 18, height: 3, color: color),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _DailySalesTrendPainter extends CustomPainter {
  const _DailySalesTrendPainter({
    required this.items,
    required this.maxQuantity,
    required this.maxAmount,
  });

  final List<DailySale> items;
  final int maxQuantity;
  final double maxAmount;

  static const _quantityColor = Color(0xFF147D64);
  static const _amountColor = Color(0xFF2F6FE4);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 12.0;
    const right = 12.0;
    const top = 12.0;
    const bottom = 30.0;
    final chartWidth = (size.width - left - right).clamp(0.0, double.infinity);
    final chartHeight = (size.height - top - bottom).clamp(
      0.0,
      double.infinity,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (var index = 0; index <= 3; index++) {
      final y = top + chartHeight * index / 3;
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
    }

    if (items.isEmpty || chartWidth == 0 || chartHeight == 0) return;

    final quantityPoints = <Offset>[];
    final amountPoints = <Offset>[];
    for (var index = 0; index < items.length; index++) {
      final x = items.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (items.length - 1);
      quantityPoints.add(
        Offset(x, _yFor(items[index].quantity, maxQuantity, top, chartHeight)),
      );
      amountPoints.add(
        Offset(x, _yFor(items[index].amount, maxAmount, top, chartHeight)),
      );
      _paintLabel(canvas, items[index].date, x, size, left, right);
    }

    _paintSeries(canvas, quantityPoints, _quantityColor);
    _paintSeries(canvas, amountPoints, _amountColor);
  }

  double _yFor(num value, num maximum, double top, double chartHeight) {
    final ratio = maximum == 0 ? 0.0 : value / maximum;
    return top + chartHeight * (1 - ratio);
  }

  void _paintSeries(Canvas canvas, List<Offset> points, Color color) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);

    final pointPaint = Paint()..color = color;
    for (final point in points) {
      canvas.drawCircle(point, 3.5, pointPaint);
      canvas.drawCircle(point, 1.5, Paint()..color = Colors.white);
    }
  }

  void _paintLabel(
    Canvas canvas,
    String value,
    double x,
    Size size,
    double left,
    double right,
  ) {
    final label = value.length >= 10 ? value.substring(5, 10) : value;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: AdminColors.muted, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelX = math
        .max(
          left,
          math.min(x - painter.width / 2, size.width - right - painter.width),
        )
        .toDouble();
    painter.paint(canvas, Offset(labelX, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant _DailySalesTrendPainter oldDelegate) =>
      oldDelegate.items != items ||
      oldDelegate.maxQuantity != maxQuantity ||
      oldDelegate.maxAmount != maxAmount;
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
