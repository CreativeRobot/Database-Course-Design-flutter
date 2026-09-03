import 'package:flutter/material.dart';

import '../../cart/data/bundle_models.dart';
import '../../cart/presentation/commerce_widgets.dart';

/// Displays currently purchasable bundles related to the book detail page.
///
/// An empty list intentionally renders nothing so the detail page does not
/// reserve space for a promotion that is not available.
class BookBundleOffers extends StatelessWidget {
  const BookBundleOffers({
    required this.bundles,
    required this.onAddBundle,
    this.addingBundleId,
    super.key,
  });

  final List<BookBundle> bundles;
  final Future<bool> Function(int bundleId) onAddBundle;
  final int? addingBundleId;

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '组合购买更优惠',
          style: TextStyle(
            color: CommerceColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < bundles.length; index++) ...[
          _BookBundleOfferCard(
            bundle: bundles[index],
            adding: addingBundleId == bundles[index].id,
            disabled: addingBundleId != null,
            onAdd: () => onAddBundle(bundles[index].id),
          ),
          if (index < bundles.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BookBundleOfferCard extends StatelessWidget {
  const _BookBundleOfferCard({
    required this.bundle,
    required this.adding,
    required this.disabled,
    required this.onAdd,
  });

  final BookBundle bundle;
  final bool adding;
  final bool disabled;
  final Future<bool> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final memberTitles = bundle.items.map((item) => item.title).join('、');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  bundle.name,
                  style: const TextStyle(
                    color: CommerceColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '节省 ${money(bundle.savings)}',
                style: const TextStyle(
                  color: CommerceColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (bundle.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 7),
            Text(
              bundle.description!,
              style: const TextStyle(color: CommerceColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            memberTitles.isEmpty ? '组合成员信息待补充' : memberTitles,
            style: const TextStyle(
              color: CommerceColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '组合价 ${money(bundle.bundlePrice)}',
                style: const TextStyle(
                  color: CommerceColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                money(bundle.regularAmount),
                style: const TextStyle(
                  color: CommerceColors.placeholder,
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: disabled ? null : () => onAdd(),
                icon: adding
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_bag_outlined, size: 17),
                label: Text(adding ? '正在加入' : '整套加入购物车'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
