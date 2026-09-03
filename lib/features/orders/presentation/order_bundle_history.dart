import 'package:flutter/material.dart';

import '../data/order_models.dart';
import '../../cart/presentation/commerce_widgets.dart';

/// Renders the immutable bundle pricing snapshot stored with an order.
///
/// This widget deliberately reads only [OrderBundleApplication] values. It
/// never looks up current book or bundle prices, so historical orders remain
/// stable after catalog changes.
class OrderBundleHistory extends StatelessWidget {
  const OrderBundleHistory({required this.bundles, super.key});

  final List<OrderBundleApplication> bundles;

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '组合包优惠记录',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < bundles.length; index++) ...[
          _OrderBundleCard(bundle: bundles[index]),
          if (index < bundles.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _OrderBundleCard extends StatelessWidget {
  const _OrderBundleCard({required this.bundle});

  final OrderBundleApplication bundle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CommerceColors.canvas,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bundle.bundleName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '组合价 ${money(bundle.bundlePrice)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '历史售价 ${money(bundle.regularAmount)}  ·  '
            '节省 ${money(bundle.discountAmount)}',
            style: const TextStyle(color: CommerceColors.muted, fontSize: 12),
          ),
          if (bundle.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final item in bundle.items)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.menu_book_outlined, size: 15),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${item.bookTitle} · ${item.isbn}\n'
                        '历史售价 ${money(item.salePrice)}  ·  '
                        '优惠分摊 ${money(item.allocatedDiscount)}',
                        style: const TextStyle(
                          color: CommerceColors.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
