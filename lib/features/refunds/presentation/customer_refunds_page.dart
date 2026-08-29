import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../cart/presentation/commerce_widgets.dart';
import 'refunds_providers.dart';

class CustomerRefundsPage extends ConsumerWidget {
  const CustomerRefundsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refunds = ref.watch(customerRefundsProvider);
    return Scaffold(
      backgroundColor: CommerceColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const CommerceHeader(current: 'orders'),
            Expanded(
              child: refunds.when(
                loading: () => const CommerceLoadingState(message: '正在加载售后记录'),
                error: (_, _) => CommerceErrorState(
                  message: '售后记录暂时无法加载',
                  onRetry: () => ref.invalidate(customerRefundsProvider),
                ),
                data: (page) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(customerRefundsProvider);
                    await ref.read(customerRefundsProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        '我的售后记录',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (page.records.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: Text('暂无售后申请')),
                        ),
                      for (final refund in page.records)
                        Card(
                          child: ListTile(
                            title: Text(refund.bookTitle),
                            subtitle: Text(
                              '${refund.typeLabel} · ${refund.statusLabel}\n${refund.refundNo}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              '¥${refund.amount.toStringAsFixed(2)}',
                            ),
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('售后详情 · ${refund.refundNo}'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('订单：${refund.orderNo}'),
                                      Text('类型：${refund.typeLabel}'),
                                      Text('状态：${refund.statusLabel}'),
                                      Text('数量：${refund.quantity}'),
                                      Text(
                                        '金额：¥${refund.amount.toStringAsFixed(2)}',
                                      ),
                                      Text('原因：${refund.reason}'),
                                      if (refund.reviewRemark?.isNotEmpty ??
                                          false)
                                        Text('审核备注：${refund.reviewRemark}'),
                                      if (refund.createTime != null)
                                        Text(
                                          '申请时间：${DateFormat('yyyy.MM.dd HH:mm').format(refund.createTime!.toLocal())}',
                                        ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('关闭'),
                                  ),
                                ],
                              ),
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
}
