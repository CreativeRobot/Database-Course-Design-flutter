import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_models.dart';
import 'admin_page.dart';
import 'admin_providers.dart';

class AdminRefundsPage extends ConsumerStatefulWidget {
  const AdminRefundsPage({super.key});
  @override
  ConsumerState<AdminRefundsPage> createState() => _AdminRefundsPageState();
}

class _AdminRefundsPageState extends ConsumerState<AdminRefundsPage> {
  String? status;
  String? type;
  int page = 1;
  bool busy = false;
  AdminRefundFilter get filter => (status: status, type: type, page: page);
  void refresh() => ref.invalidate(adminRefundsProvider(filter));

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminRefundsProvider(filter));
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            DropdownButton<String?>(
              value: status,
              hint: const Text('全部状态'),
              items: const [
                DropdownMenuItem(value: null, child: Text('全部状态')),
                DropdownMenuItem(value: 'PENDING', child: Text('待审核')),
                DropdownMenuItem(value: 'APPROVED', child: Text('已同意')),
                DropdownMenuItem(value: 'REJECTED', child: Text('已拒绝')),
              ],
              onChanged: (v) => setState(() {
                status = v;
                page = 1;
              }),
            ),
            const SizedBox(width: 12),
            DropdownButton<String?>(
              value: type,
              hint: const Text('全部类型'),
              items: const [
                DropdownMenuItem(value: null, child: Text('全部类型')),
                DropdownMenuItem(value: 'REFUND_ONLY', child: Text('仅退款')),
                DropdownMenuItem(value: 'RETURN_REFUND', child: Text('退货退款')),
              ],
              onChanged: (v) => setState(() {
                type = v;
                page = 1;
              }),
            ),
            const Spacer(),
            IconButton(
              onPressed: refresh,
              tooltip: '刷新',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminPanel(
          child: AdminAsync(
            value: value,
            retry: refresh,
            data: (response) {
              if (response.records.isEmpty)
                return const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: Text('暂无售后申请')),
                );
              return Column(
                children: response.records
                    .map(
                      (r) => _RefundRow(
                        request: r,
                        onDetail: () => _detail(r),
                        onReview: r.pending ? () => _review(r) : null,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        value.when(
          data: (response) => AdminPagination(
            page: response,
            onPage: (p) => setState(() => page = p),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Future<void> _detail(AdminRefundRequest request) async {
    try {
      final detail = await ref.read(adminRepositoryProvider).refund(request.id);
      if (mounted)
        await showDialog<void>(
          context: context,
          builder: (_) => _RefundDialog(detail),
        );
    } catch (e) {
      if (mounted) showAdminMessage(context, e);
    }
  }

  Future<void> _review(AdminRefundRequest request) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('审核售后 · ${request.refundNo}'),
        content: Text(
          '确定${request.typeLabel} ${request.amount.toStringAsFixed(2)} 元吗？同意后将原子更新退款、订单明细、库存和库存流水。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('同意'),
          ),
        ],
      ),
    );
    if (approved == null || busy) return;
    setState(() => busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .reviewRefund(
            request.id,
            approved: approved,
            remark: approved ? '管理员审核通过' : '管理员审核拒绝',
          );
      refresh();
      if (mounted) showAdminMessage(context, approved ? '售后已同意' : '售后已拒绝');
    } catch (e) {
      if (mounted) showAdminMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _RefundRow extends StatelessWidget {
  const _RefundRow({
    required this.request,
    required this.onDetail,
    required this.onReview,
  });
  final AdminRefundRequest request;
  final VoidCallback onDetail;
  final VoidCallback? onReview;
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
                request.refundNo,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${request.username} · ${request.orderNo}',
                style: const TextStyle(color: AdminColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            request.bookTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 95, child: Text(request.typeLabel)),
        SizedBox(
          width: 80,
          child: Text('¥${request.amount.toStringAsFixed(2)}'),
        ),
        SizedBox(width: 70, child: Text(request.statusLabel)),
        IconButton(
          tooltip: '详情',
          onPressed: onDetail,
          icon: const Icon(Icons.visibility_outlined),
        ),
        if (onReview != null)
          FilledButton(onPressed: onReview, child: const Text('审核')),
      ],
    ),
  );
}

class _RefundDialog extends StatelessWidget {
  const _RefundDialog(this.request);
  final AdminRefundRequest request;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('售后详情 · ${request.refundNo}'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('订单：${request.orderNo}'),
            Text('用户：${request.username}'),
            Text('图书：${request.bookTitle}'),
            Text('类型：${request.typeLabel}'),
            Text('数量：${request.quantity} / ${request.itemQuantity}'),
            Text('金额：¥${request.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            Text('原因：${request.reason}'),
            if (request.reviewRemark.isNotEmpty)
              Text('审核备注：${request.reviewRemark}'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
    ],
  );
}
