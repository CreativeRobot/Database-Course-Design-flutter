import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../cart/presentation/commerce_widgets.dart';
import '../../orders/data/order_models.dart';
import '../../reviews/data/review_models.dart';
import '../data/admin_models.dart';
import 'admin_page.dart';
import 'admin_providers.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});
  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  final search = TextEditingController();
  final userSearch = TextEditingController();
  String orderNo = '';
  int? userId;
  String? status;
  int page = 1;
  AdminOrderFilter get filter =>
      (orderNo: orderNo, userId: userId, status: status, page: page);
  @override
  void dispose() {
    search.dispose();
    userSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminOrdersProvider(filter));
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '订单管理',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          AdminPanel(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: search,
                    onSubmitted: (_) => _apply(),
                    decoration: const InputDecoration(
                      labelText: '订单号',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: userSearch,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _apply(),
                    decoration: const InputDecoration(
                      labelText: '用户 ID',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: '订单状态',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('全部')),
                      DropdownMenuItem(
                        value: 'PENDING_PAYMENT',
                        child: Text('待支付'),
                      ),
                      DropdownMenuItem(
                        value: 'PENDING_SHIPMENT',
                        child: Text('待发货'),
                      ),
                      DropdownMenuItem(value: 'SHIPPED', child: Text('待收货')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('已完成')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('已取消')),
                    ],
                    onChanged: (v) => setState(() => status = v),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _apply,
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: const Text('查询'),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdminPanel(
            child: AdminAsync(
              value: value,
              retry: _refresh,
              data: (response) => response.records.isEmpty
                  ? const _OrdersEmpty()
                  : AdminWideTable(
                      child: Column(
                        children: response.records
                            .map(
                              (order) => _OrderRow(
                                order: order,
                                onDetail: () => _detail(order),
                                onShip: () => _ship(order),
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ),
          value.when(data: (response) => AdminPagination(page: response, onPage: (p) => setState(() => page = p)), loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink()),
        ],
      ),
    );
  }

  void _apply() => setState(() {
    orderNo = search.text.trim();
    userId = int.tryParse(userSearch.text.trim());
    page = 1;
  });
  void _refresh() => ref.invalidate(adminOrdersProvider(filter));
  Future<void> _detail(BookOrder order) async {
    try {
      final detail = await ref.read(adminRepositoryProvider).order(order.id);
      if (mounted)
        await showDialog<void>(
          context: context,
          builder: (_) => _OrderDetailDialog(detail),
        );
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }

  Future<void> _ship(BookOrder order) async {
    if (!await confirmAdminAction(
      context,
      title: '订单发货',
      message: '确定将订单 ${order.orderNo} 标记为已发货吗？',
    ))
      return;
    try {
      await ref.read(adminRepositoryProvider).shipOrder(order.id);
      _refresh();
      if (mounted) showAdminMessage(context, '订单已发货');
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.onDetail,
    required this.onShip,
  });
  final BookOrder order;
  final VoidCallback onDetail;
  final VoidCallback onShip;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AdminColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.orderNo,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                _time(order.createTime),
                style: const TextStyle(color: AdminColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(child: Text(order.receiverName)),
        Expanded(child: Text(money(order.payableAmount))),
        SizedBox(width: 86, child: _OrderTag(order.status)),
        IconButton(
          tooltip: '订单详情',
          onPressed: onDetail,
          icon: const Icon(Icons.visibility_outlined),
        ),
        if (order.status == 'PENDING_SHIPMENT')
          FilledButton.icon(
            onPressed: onShip,
            icon: const Icon(Icons.local_shipping_outlined, size: 17),
            label: const Text('发货'),
          ),
      ],
    ),
  );
}

class _OrderDetailDialog extends StatelessWidget {
  const _OrderDetailDialog(this.order);
  final BookOrder order;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('订单详情 · ${order.orderNo}'),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text('状态：${_orderLabel(order.status)}'),
                Text('下单：${_time(order.createTime)}'),
                Text('实付：${money(order.payableAmount)}'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AdminColors.canvas,
              child: Text(
                '${order.receiverName}  ${order.receiverPhone}\n${order.receiverAddress}',
              ),
            ),
            if (order.remark.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('备注：${order.remark}'),
              ),
            const Divider(height: 28),
            for (final item in order.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(item.bookTitle),
                subtitle: Text(
                  'ISBN ${item.isbn} · ${money(item.unitPrice)} × ${item.quantity}',
                ),
                trailing: Text(money(item.subtotal)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
    ],
  );
}

class AdminReviewsPage extends ConsumerStatefulWidget {
  const AdminReviewsPage({super.key});
  @override
  ConsumerState<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends ConsumerState<AdminReviewsPage> {
  final bookSearch = TextEditingController();
  final userSearch = TextEditingController();
  int? bookId;
  int? userId;
  int? status;
  int page = 1;
  AdminReviewFilter get filter =>
      (bookId: bookId, userId: userId, status: status, page: page);
  @override
  void dispose() {
    bookSearch.dispose();
    userSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminReviewsProvider(filter));
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(
                width: 240,
                child: Text(
                  '评价审核',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: bookSearch,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '图书 ID',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: userSearch,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '用户 ID',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              DropdownButton<int?>(
                value: status,
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部评价')),
                  DropdownMenuItem(value: 1, child: Text('正常')),
                  DropdownMenuItem(value: 0, child: Text('已屏蔽')),
                ],
                onChanged: (v) => setState(() => status = v),
              ),
              FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('查询'),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminPanel(
            child: AdminAsync(
              value: value,
              retry: _refresh,
              data: (response) => response.records.isEmpty
                  ? const _ReviewsEmpty()
                  : AdminWideTable(
                      child: Column(
                        children: response.records
                            .map(
                              (review) => _ReviewRow(
                                review: review,
                                onToggle: () => _toggle(review),
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ),
          value.when(data: (response) => AdminPagination(page: response, onPage: (p) => setState(() => page = p)), loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink()),
        ],
      ),
    );
  }

  void _apply() => setState(() {
    bookId = int.tryParse(bookSearch.text.trim());
    userId = int.tryParse(userSearch.text.trim());
    page = 1;
  });
  void _refresh() => ref.invalidate(adminReviewsProvider(filter));
  Future<void> _toggle(UserReview review) async {
    final next = review.status == 1 ? 0 : 1;
    if (!await confirmAdminAction(
      context,
      title: next == 0 ? '屏蔽评价' : '恢复评价',
      message: '确定${next == 0 ? '屏蔽' : '恢复'}这条评价吗？',
    ))
      return;
    try {
      await ref.read(adminRepositoryProvider).setReviewStatus(review.id, next);
      _refresh();
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review, required this.onToggle});
  final UserReview review;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AdminColors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(child: Text('${review.rating}')),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                review.bookTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(review.content.isEmpty ? '未填写文字评价' : review.content),
              const SizedBox(height: 5),
              Text(
                '${review.reviewerName} · ${_time(review.createTime)}',
                style: const TextStyle(color: AdminColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _ReviewTag(review.status),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onToggle,
          icon: Icon(
            review.status == 1
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 17,
          ),
          label: Text(review.status == 1 ? '屏蔽' : '恢复'),
        ),
      ],
    ),
  );
}

class AdminInventoryPage extends ConsumerStatefulWidget {
  const AdminInventoryPage({super.key});
  @override
  ConsumerState<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends ConsumerState<AdminInventoryPage> {
  final bookSearch = TextEditingController();
  final orderSearch = TextEditingController();
  final startSearch = TextEditingController();
  final endSearch = TextEditingController();
  int? bookId;
  int? orderId;
  String? startTime;
  String? endTime;
  String? type;
  int page = 1;
  AdminInventoryFilter get filter => (
    bookId: bookId,
    orderId: orderId,
    type: type,
    startTime: startTime,
    endTime: endTime,
    page: page,
  );
  @override
  void dispose() {
    bookSearch.dispose();
    orderSearch.dispose();
    startSearch.dispose();
    endSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminInventoryProvider(filter));
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(
                width: 220,
                child: Text(
                  '库存流水',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              _filterField(bookSearch, '图书 ID', 130),
              _filterField(orderSearch, '订单 ID', 130),
              _filterField(startSearch, '起始时间 ISO-8601', 210),
              _filterField(endSearch, '结束时间 ISO-8601', 210),
              DropdownButton<String?>(
                value: type,
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部类型')),
                  DropdownMenuItem(value: 'PURCHASE_IN', child: Text('采购入库')),
                  DropdownMenuItem(value: 'ORDER_OUT', child: Text('订单出库')),
                  DropdownMenuItem(
                    value: 'ORDER_CANCEL_RETURN',
                    child: Text('取消回库'),
                  ),
                  DropdownMenuItem(
                    value: 'MANUAL_ADJUSTMENT',
                    child: Text('手动调整'),
                  ),
                ],
                onChanged: (v) => setState(() => type = v),
              ),
              FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('查询'),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminPanel(
            child: AdminAsync(
              value: value,
              retry: _refresh,
              data: (response) => response.records.isEmpty
                  ? const _InventoryEmpty()
                  : AdminWideTable(
                      minWidth: 980,
                      child: Column(
                        children: response.records
                            .map((log) => _InventoryRow(log))
                            .toList(),
                      ),
                    ),
            ),
          ),
          value.when(data: (response) => AdminPagination(page: response, onPage: (p) => setState(() => page = p)), loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _filterField(
    TextEditingController controller,
    String label,
    double width,
  ) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  void _apply() => setState(() {
    bookId = int.tryParse(bookSearch.text.trim());
    orderId = int.tryParse(orderSearch.text.trim());
    startTime = startSearch.text.trim();
    endTime = endSearch.text.trim();
    page = 1;
  });
  void _refresh() => ref.invalidate(adminInventoryProvider(filter));
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow(this.log);
  final InventoryLog log;
  @override
  Widget build(BuildContext context) {
    final positive = log.changeQuantity > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            color: (positive ? AdminColors.green : AdminColors.red).withValues(
              alpha: .1,
            ),
            child: Icon(
              positive ? Icons.add : Icons.remove,
              color: positive ? AdminColors.green : AdminColors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.bookTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'ISBN ${log.isbn}',
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              '${positive ? '+' : ''}${log.changeQuantity}',
              style: TextStyle(
                color: positive ? AdminColors.green : AdminColors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text('${log.beforeStock} → ${log.afterStock}'),
          ),
          Expanded(child: Text(_inventoryLabel(log.changeType))),
          Expanded(
            child: Text(
              log.orderNo ?? log.remark,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              _time(log.createTime),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTag extends StatelessWidget {
  const _OrderTag(this.status);
  final String status;
  @override
  Widget build(BuildContext context) => Text(
    _orderLabel(status),
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
  );
}

class _ReviewTag extends StatelessWidget {
  const _ReviewTag(this.status);
  final int status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    color: (status == 1 ? AdminColors.green : AdminColors.red).withValues(
      alpha: .1,
    ),
    child: Text(
      status == 1 ? '正常' : '已屏蔽',
      style: TextStyle(
        color: status == 1 ? AdminColors.green : AdminColors.red,
        fontSize: 11,
      ),
    ),
  );
}

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 180, child: Center(child: Text('暂无订单')));
}

class _ReviewsEmpty extends StatelessWidget {
  const _ReviewsEmpty();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 180, child: Center(child: Text('暂无评价')));
}

class _InventoryEmpty extends StatelessWidget {
  const _InventoryEmpty();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 180, child: Center(child: Text('暂无库存流水')));
}

String _time(DateTime? value) => value == null
    ? '--'
    : DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
String _orderLabel(String status) => switch (status) {
  'PENDING_PAYMENT' => '待支付',
  'PENDING_SHIPMENT' => '待发货',
  'SHIPPED' => '待收货',
  'COMPLETED' => '已完成',
  'CANCELLED' => '已取消',
  _ => status,
};
String _inventoryLabel(String type) => switch (type) {
  'PURCHASE_IN' => '采购入库',
  'ORDER_OUT' => '订单出库',
  'ORDER_CANCEL_RETURN' => '取消回库',
  'MANUAL_ADJUSTMENT' => '手动调整',
  _ => type,
};
