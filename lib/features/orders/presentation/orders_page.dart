import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../cart/presentation/commerce_widgets.dart';
import '../data/order_models.dart';
import 'orders_controller.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class OrdersContent extends StatelessWidget {
  const OrdersContent({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return OrdersPage(embedded: embedded);
  }
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(ordersControllerProvider.notifier).loadOrders(),
    );
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final state = ref.read(ordersControllerProvider);
      if (state.orders.any((order) => order.canPay)) {
        ref.read(ordersControllerProvider.notifier).refreshLoadedOrders();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersControllerProvider);
    final controller = ref.read(ordersControllerProvider.notifier);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommerceTitle(
                eyebrow: 'ORDERS  ·  我的订单',
                title: '每一本，都有去向',
                subtitle: '查看订单进度，并处理待支付或可取消的订单。',
                trailing: OutlinedButton.icon(
                  onPressed: () => context.go('/books'),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('继续选书'),
                ),
              ),
              const SizedBox(height: 28),
              _OrderFilters(
                selected: state.filter,
                disabled: state.status == OrdersStatus.loading,
                onSelected: (status) => controller.loadOrders(
                  status: status,
                  clearFilter: status == null,
                ),
              ),
              const SizedBox(height: 20),
              if (state.errorMessage != null) ...[
                CommerceNotice(message: state.errorMessage!),
                const SizedBox(height: 18),
              ],
              if (state.status == OrdersStatus.loading && state.orders.isEmpty)
                const CommerceLoadingState(message: '正在加载订单')
              else if (state.status == OrdersStatus.failure &&
                  state.orders.isEmpty)
                CommerceErrorState(
                  message: state.errorMessage ?? '订单暂时无法加载',
                  onRetry: () => controller.loadOrders(),
                )
              else if (state.orders.isEmpty)
                CommerceEmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: state.filter != null ? '这个状态下暂无订单' : '还没有订单',
                  action: state.filter == null
                      ? FilledButton(
                          onPressed: () => context.go('/books'),
                          child: const Text('去选书'),
                        )
                      : null,
                )
              else
                Column(
                  children: [
                    for (
                      var index = 0;
                      index < state.orders.length;
                      index++
                    ) ...[
                      _OrderCard(
                        order: state.orders[index],
                        busy: state.busyOrderId == state.orders[index].id,
                        onPay: () => _confirmPay(state.orders[index]),
                        onCancel: () => _confirmCancel(state.orders[index]),
                        onConfirm: () => _confirmReceipt(state.orders[index]),
                        onOpen: () =>
                            context.push('/orders/${state.orders[index].id}'),
                        onExpired: controller.refreshLoadedOrders,
                      ),
                      if (index != state.orders.length - 1)
                        const SizedBox(height: 14),
                    ],
                    if (state.hasMore || state.loadingMore) ...[
                      const SizedBox(height: 22),
                      Center(
                        child: state.loadingMore
                            ? const SizedBox.square(
                                dimension: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: controller.loadMore,
                                icon: const Icon(Icons.expand_more_rounded),
                                label: Text(
                                  '加载更多（已显示 ${state.orders.length}/${state.total}）',
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    final body = widget.embedded
        ? content
        : RefreshIndicator(
            onRefresh: () => controller.loadOrders(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: content,
            ),
          );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      backgroundColor: CommerceColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const CommerceHeader(current: 'orders'),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPay(BookOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('模拟支付'),
        content: Text(
          '将使用 MOCK 方式支付订单 ${order.orderNo}，金额 ${money(order.payableAmount)}。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍后支付'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('确认支付'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ref
        .read(ordersControllerProvider.notifier)
        .payOrder(order);
    if (!mounted || !success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('模拟支付成功')));
  }

  Future<void> _confirmCancel(BookOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消订单'),
        content: Text('确定取消订单 ${order.orderNo} 吗？取消后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留订单'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ref
        .read(ordersControllerProvider.notifier)
        .cancelOrder(order);
    if (!mounted || !success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('订单已取消')));
  }

  Future<void> _confirmReceipt(BookOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认收货'),
        content: Text('确认已收到订单 ${order.orderNo} 的商品吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再看看'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认收货'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = await ref
        .read(ordersControllerProvider.notifier)
        .confirmReceipt(order);
    if (!mounted) return;
    if (updated == null) {
      final message = ref.read(ordersControllerProvider).errorMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message ?? '确认收货失败，请稍后再试')));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已确认收货，现在可以评价商品了')));
  }
}

class _OrderFilters extends StatelessWidget {
  const _OrderFilters({
    required this.selected,
    required this.disabled,
    required this.onSelected,
  });

  final String? selected;
  final bool disabled;
  final ValueChanged<String?> onSelected;

  static const filters = <(String?, String)>[
    (null, '全部'),
    ('PENDING_PAYMENT', '待支付'),
    ('PENDING_SHIPMENT', '待发货'),
    ('SHIPPED', '待收货'),
    ('COMPLETED', '已完成'),
    ('CANCELLED', '已取消'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in filters)
          ChoiceChip(
            label: Text(filter.$2),
            selected: selected == filter.$1,
            onSelected: disabled ? null : (_) => onSelected(filter.$1),
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
              side: const BorderSide(color: CommerceColors.line),
            ),
            selectedColor: CommerceColors.ink,
            labelStyle: TextStyle(
              color: selected == filter.$1 ? Colors.white : CommerceColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.busy,
    required this.onPay,
    required this.onCancel,
    required this.onOpen,
    required this.onConfirm,
    required this.onExpired,
  });

  final BookOrder order;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onCancel;
  final VoidCallback onOpen;
  final VoidCallback onConfirm;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final number = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '订单号  ${order.orderNo}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _dateTime(order.createTime),
                      style: const TextStyle(
                        color: CommerceColors.placeholder,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
                final status = _StatusBadge(status: order.status);
                if (constraints.maxWidth < 500) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [number, const SizedBox(height: 10), status],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: number),
                    status,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                for (var index = 0; index < order.items.length; index++) ...[
                  _OrderLineTile(line: order.items[index]),
                  if (index != order.items.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 11),
                      child: Divider(height: 1),
                    ),
                ],
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CommerceColors.canvas,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 9,
                    children: [
                      _Meta(
                        icon: Icons.person_outline,
                        text: order.receiverName,
                      ),
                      _Meta(
                        icon: Icons.phone_outlined,
                        text: order.receiverPhone,
                      ),
                      _Meta(
                        icon: Icons.location_on_outlined,
                        text: order.receiverAddress,
                      ),
                    ],
                  ),
                ),
                if (order.remark.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '备注：${order.remark}',
                      style: const TextStyle(
                        color: CommerceColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (order.canPay && order.expireTime != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CommerceCountdown(
                      expireTime: order.expireTime!,
                      onExpired: onExpired,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final amount = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '共 ${order.items.fold<int>(0, (sum, item) => sum + item.quantity)} 件  实付 ',
                          style: const TextStyle(
                            color: CommerceColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          money(order.payableAmount),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    );
                    final actions = _OrderActions(
                      order: order,
                      busy: busy,
                      onPay: onPay,
                      onCancel: onCancel,
                      onOpen: onOpen,
                      onConfirm: onConfirm,
                    );
                    if (constraints.maxWidth < 620) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [amount, const SizedBox(height: 14), actions],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [amount, const SizedBox(width: 22), actions],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderLineTile extends StatelessWidget {
  const _OrderLineTile({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CommerceColors.sand,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.auto_stories_outlined,
            color: CommerceColors.placeholder,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.bookTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ISBN ${line.isbn}  ·  ${money(line.unitPrice)} × ${line.quantity}',
                style: const TextStyle(
                  color: CommerceColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(money(line.subtotal), style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({
    required this.order,
    required this.busy,
    required this.onPay,
    required this.onCancel,
    required this.onOpen,
    required this.onConfirm,
  });

  final BookOrder order;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onCancel;
  final VoidCallback onOpen;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    if (!order.canPay && !order.canCancel && !order.canConfirmReceipt) {
      return OutlinedButton.icon(
        onPressed: onOpen,
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('查看详情'),
      );
    }
    if (busy) {
      return const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('详情'),
        ),
        if (order.canCancel)
          OutlinedButton(onPressed: onCancel, child: const Text('取消订单')),
        if (order.canPay)
          FilledButton.icon(
            onPressed: onPay,
            icon: const Icon(Icons.payments_outlined, size: 17),
            label: const Text('模拟支付'),
          ),
        if (order.canConfirmReceipt)
          FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_circle_outline, size: 17),
            label: const Text('确认收货'),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PENDING_PAYMENT' => CommerceColors.danger,
      'PENDING_SHIPMENT' || 'SHIPPED' => const Color(0xFF41617A),
      'COMPLETED' => CommerceColors.success,
      _ => CommerceColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: CommerceColors.placeholder),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: CommerceColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'PENDING_PAYMENT' => '待支付',
    'PENDING_SHIPMENT' => '待发货',
    'SHIPPED' => '待收货',
    'COMPLETED' => '已完成',
    'CANCELLED' => '已取消',
    _ => status,
  };
}

String _dateTime(DateTime? value) {
  if (value == null) return '--';
  return DateFormat('yyyy.MM.dd HH:mm').format(value.toLocal());
}
