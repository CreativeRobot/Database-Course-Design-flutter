import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../cart/presentation/commerce_widgets.dart';
import '../../reviews/data/review_models.dart';
import '../../reviews/presentation/reviews_controller.dart';
import '../data/order_models.dart';
import 'orders_controller.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({required this.orderId, super.key});

  final int orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(ordersControllerProvider.notifier).clearError();
      return ref.read(reviewsControllerProvider.notifier).loadMyReviews();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final order = ref.read(orderDetailProvider(widget.orderId)).asData?.value;
      if (order?.canPay ?? false) _refreshOrder();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderDetailProvider(widget.orderId));
    final reviews = ref.watch(reviewsControllerProvider);
    final orders = ref.watch(ordersControllerProvider);
    return Scaffold(
      backgroundColor: CommerceColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const CommerceHeader(current: 'orders'),
            Expanded(
              child: order.when(
                loading: () => const CommerceLoadingState(message: '正在加载订单详情'),
                error: (error, _) => CommerceErrorState(
                  message: '订单详情暂时无法加载',
                  onRetry: _refreshOrder,
                ),
                data: (value) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(orderDetailProvider(widget.orderId));
                    await ref.read(orderDetailProvider(widget.orderId).future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 64),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: _DetailContent(
                            order: value,
                            reviews: reviews,
                            actionBusy: orders.busyOrderId == value.id,
                            actionError: orders.errorMessage,
                            onPay: () => _confirmPay(value),
                            onCancel: () => _confirmCancel(value),
                            onConfirm: () => _confirmReceipt(value),
                            onExpired: _refreshOrder,
                            onReloadReviews: () => ref
                                .read(reviewsControllerProvider.notifier)
                                .loadMyReviews(force: true),
                            onReview: (line, existing) =>
                                _editReview(line, existing),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshOrder() async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    ref.invalidate(orderDetailProvider(widget.orderId));
    try {
      await ref.read(orderDetailProvider(widget.orderId).future);
    } catch (_) {
      // The provider exposes the error state to the shared error widget.
    } finally {
      _refreshing = false;
    }
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
    if (confirmed != true || !mounted) return;
    final success = await ref
        .read(ordersControllerProvider.notifier)
        .payOrder(order);
    if (!mounted) return;
    if (!success) {
      _showOrderError('支付失败，请稍后再试');
      return;
    }
    await _refreshOrder();
    if (!mounted) return;
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
    if (confirmed != true || !mounted) return;
    final success = await ref
        .read(ordersControllerProvider.notifier)
        .cancelOrder(order);
    if (!mounted) return;
    if (!success) {
      _showOrderError('取消订单失败，请稍后再试');
      return;
    }
    await _refreshOrder();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('订单已取消')));
  }

  void _showOrderError(String fallback) {
    final message = ref.read(ordersControllerProvider).errorMessage ?? fallback;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    if (confirmed != true || !mounted) return;
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
    ref.invalidate(orderDetailProvider(order.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已确认收货，现在可以评价商品了')));
  }

  Future<void> _editReview(OrderLine line, UserReview? existing) async {
    final result = await showDialog<_ReviewDraft>(
      context: context,
      builder: (context) => _ReviewDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    final saved = await ref
        .read(reviewsControllerProvider.notifier)
        .saveReview(
          orderItemId: line.id,
          rating: result.rating,
          content: result.content,
          existing: existing,
        );
    if (!mounted) return;
    if (saved == null) {
      final message = ref.read(reviewsControllerProvider).errorMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message ?? '评价保存失败，请稍后再试')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existing == null ? '评价已提交' : '评价已修改')),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.order,
    required this.reviews,
    required this.actionBusy,
    required this.actionError,
    required this.onPay,
    required this.onCancel,
    required this.onConfirm,
    required this.onExpired,
    required this.onReloadReviews,
    required this.onReview,
  });

  final BookOrder order;
  final ReviewsState reviews;
  final bool actionBusy;
  final String? actionError;
  final VoidCallback onPay;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback onExpired;
  final VoidCallback onReloadReviews;
  final void Function(OrderLine line, UserReview? existing) onReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '返回订单列表',
              onPressed: () => context.go('/orders'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '订单详情  ${order.orderNo}',
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StatusBadge(status: order.status),
          ],
        ),
        const SizedBox(height: 22),
        if (actionError != null) ...[
          CommerceNotice(message: actionError!),
          const SizedBox(height: 16),
        ],
        if (order.canPay && order.expireTime != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: CommerceColors.danger.withValues(alpha: .06),
              border: Border.all(
                color: CommerceColors.danger.withValues(alpha: .2),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: CommerceCountdown(
              expireTime: order.expireTime!,
              onExpired: onExpired,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (order.status == 'COMPLETED' &&
            reviews.status == ReviewsStatus.loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
        ],
        if (order.status == 'COMPLETED' &&
            reviews.status == ReviewsStatus.failure) ...[
          CommerceNotice(message: reviews.errorMessage ?? '评价暂时无法加载'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onReloadReviews,
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text('重新加载评价'),
          ),
          const SizedBox(height: 16),
        ],
        _Section(
          title: '商品明细',
          child: Column(
            children: [
              for (var index = 0; index < order.items.length; index++) ...[
                _DetailLine(
                  line: order.items[index],
                  review: reviews.reviewFor(order.items[index].id),
                  reviewBusy: reviews.busyOrderItemId == order.items[index].id,
                  canReview:
                      order.status == 'COMPLETED' &&
                      reviews.status == ReviewsStatus.ready,
                  onReview: () => onReview(
                    order.items[index],
                    reviews.reviewFor(order.items[index].id),
                  ),
                ),
                if (index < order.items.length - 1) const Divider(height: 28),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: '收货信息',
          child: Wrap(
            spacing: 26,
            runSpacing: 12,
            children: [
              _Meta(icon: Icons.person_outline, text: order.receiverName),
              _Meta(icon: Icons.phone_outlined, text: order.receiverPhone),
              _Meta(
                icon: Icons.location_on_outlined,
                text: order.receiverAddress,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: '订单信息',
          child: Wrap(
            spacing: 26,
            runSpacing: 12,
            children: [
              _Meta(
                icon: Icons.schedule_outlined,
                text: '下单时间 ${_dateTime(order.createTime)}',
              ),
              if (order.paidTime != null)
                _Meta(
                  icon: Icons.payments_outlined,
                  text: '支付时间 ${_dateTime(order.paidTime)}',
                ),
              if (order.shippedTime != null)
                _Meta(
                  icon: Icons.local_shipping_outlined,
                  text: '发货时间 ${_dateTime(order.shippedTime)}',
                ),
              if (order.completedTime != null)
                _Meta(
                  icon: Icons.check_circle_outline,
                  text: '完成时间 ${_dateTime(order.completedTime)}',
                ),
              if (order.remark.isNotEmpty)
                _Meta(icon: Icons.notes_outlined, text: '备注 ${order.remark}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: '订单金额',
          child: Column(
            children: [
              _AmountRow(label: '商品合计', amount: order.totalAmount),
              _AmountRow(label: '优惠', amount: -order.discountAmount),
              _AmountRow(label: '运费', amount: order.shippingFee),
              const Divider(height: 22),
              _AmountRow(
                label: '实付金额',
                amount: order.payableAmount,
                emphasized: true,
              ),
            ],
          ),
        ),
        if (order.canPay || order.canCancel || order.canConfirmReceipt) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: actionBusy
                ? const SizedBox.square(
                    dimension: 26,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (order.canCancel)
                        OutlinedButton(
                          onPressed: onCancel,
                          child: const Text('取消订单'),
                        ),
                      if (order.canPay)
                        FilledButton.icon(
                          onPressed: onPay,
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('模拟支付'),
                        ),
                      if (order.canConfirmReceipt)
                        FilledButton.icon(
                          onPressed: onConfirm,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('确认收货'),
                        ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.line,
    required this.review,
    required this.reviewBusy,
    required this.canReview,
    required this.onReview,
  });

  final OrderLine line;
  final UserReview? review;
  final bool reviewBusy;
  final bool canReview;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 76,
          alignment: Alignment.center,
          color: CommerceColors.sand,
          child: const Icon(Icons.auto_stories_outlined),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.bookTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                'ISBN ${line.isbn}  ·  ${money(line.unitPrice)} × ${line.quantity}',
                style: const TextStyle(
                  color: CommerceColors.muted,
                  fontSize: 12,
                ),
              ),
              if (review != null) ...[
                const SizedBox(height: 9),
                Text(
                  '${'★' * review!.rating}  ${review!.content.isEmpty ? '未填写文字评价' : review!.content}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CommerceColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(line.subtotal)),
            if (canReview) ...[
              const SizedBox(height: 10),
              reviewBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton(
                      onPressed: onReview,
                      child: Text(review == null ? '去评价' : '修改评价'),
                    ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReviewDraft {
  const _ReviewDraft(this.rating, this.content);

  final int rating;
  final String content;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({this.existing});

  final UserReview? existing;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late int _rating;
  late final TextEditingController _contentController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 5;
    _contentController = TextEditingController(text: widget.existing?.content);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '提交评价' : '修改评价'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('评分'),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var score = 1; score <= 5; score++)
                  IconButton(
                    tooltip: '$score 分',
                    onPressed: () => setState(() => _rating = score),
                    color: score <= _rating
                        ? const Color(0xFFC58B26)
                        : CommerceColors.placeholder,
                    icon: const Icon(Icons.star),
                  ),
              ],
            ),
            TextField(
              controller: _contentController,
              maxLength: 1000,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '分享这本书带给你的感受（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: CommerceColors.danger),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存评价')),
      ],
    );
  }

  void _submit() {
    final content = _contentController.text.trim();
    if (content.length > 1000) {
      setState(() => _error = '评价内容不能超过 1000 个字符');
      return;
    }
    Navigator.pop(context, _ReviewDraft(_rating, content));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: CommerceColors.muted)),
          const Spacer(),
          Text(
            money(amount),
            style: TextStyle(
              fontSize: emphasized ? 20 : 14,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
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
        Icon(icon, size: 16, color: CommerceColors.placeholder),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: CommerceColors.muted)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_statusLabel(status)),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'PENDING_PAYMENT' => '待支付',
  'PENDING_SHIPMENT' => '待发货',
  'SHIPPED' => '待收货',
  'COMPLETED' => '已完成',
  'CANCELLED' => '已取消',
  _ => status,
};

String _dateTime(DateTime? value) => value == null
    ? '--'
    : DateFormat('yyyy.MM.dd HH:mm').format(value.toLocal());
