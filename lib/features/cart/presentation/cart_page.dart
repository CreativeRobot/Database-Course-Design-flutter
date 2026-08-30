import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/utils/book_presale.dart';
import '../data/cart_models.dart';
import 'cart_controller.dart';
import 'commerce_widgets.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(cartControllerProvider.notifier).loadCart(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cartControllerProvider);
    final cart = state.cart;
    final baseUrl = ref.watch(appConfigProvider).baseUrl;
    final controller = ref.read(cartControllerProvider.notifier);

    return Scaffold(
      backgroundColor: CommerceColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const CommerceHeader(current: 'cart'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.loadCart,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 64),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CommerceTitle(
                            eyebrow: 'CART  ·  购物车',
                            title: '准备带走的书',
                            subtitle: '确认数量与库存，选择本次要结算的图书。',
                            trailing: OutlinedButton.icon(
                              onPressed: () => context.go('/books'),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('继续选书'),
                            ),
                          ),
                          const SizedBox(height: 30),
                          if (state.errorMessage != null) ...[
                            CommerceNotice(message: state.errorMessage!),
                            const SizedBox(height: 18),
                          ],
                          if (state.status == CartStatus.loading &&
                              cart.items.isEmpty)
                            const CommerceLoadingState(message: '正在加载购物车')
                          else if (state.status == CartStatus.failure &&
                              cart.items.isEmpty)
                            CommerceErrorState(
                              message: state.errorMessage ?? '购物车暂时无法加载',
                              onRetry: controller.loadCart,
                            )
                          else if (cart.items.isEmpty)
                            const _EmptyCart()
                          else ...[
                            _SelectionBar(
                              cart: cart,
                              disabled: state.isBusy,
                              onToggleAll: controller.toggleAll,
                              onDeleteSelected: () => _confirmDeleteSelected(
                                cart.selectedItems.length,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final items = _CartItems(
                                  cart: cart,
                                  baseUrl: baseUrl,
                                  busyBookIds: state.busyBookIds,
                                  busyAll: state.busyAll,
                                  onToggle: controller.toggleItem,
                                  onQuantity: controller.updateQuantity,
                                  onDelete: _confirmDeleteItem,
                                );
                                final summary = _CartSummary(
                                  cart: cart,
                                  disabled: state.isBusy,
                                  onCheckout: cart.canCheckout
                                      ? () => context.push('/checkout')
                                      : null,
                                );
                                if (constraints.maxWidth < 880) {
                                  return Column(
                                    children: [
                                      items,
                                      const SizedBox(height: 18),
                                      summary,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: items),
                                    const SizedBox(width: 24),
                                    SizedBox(width: 310, child: summary),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteItem(CartItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出购物车'),
        content: Text('确定删除《${item.title}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(cartControllerProvider.notifier).removeItem(item);
    }
  }

  Future<void> _confirmDeleteSelected(int count) async {
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除已选商品'),
        content: Text('将 $count 件已选商品移出购物车？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(cartControllerProvider.notifier).removeSelected();
    }
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.cart,
    required this.disabled,
    required this.onToggleAll,
    required this.onDeleteSelected,
  });

  final ShoppingCart cart;
  final bool disabled;
  final Future<bool> Function() onToggleAll;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Checkbox(
            value: cart.allSelected,
            onChanged: disabled ? null : (_) => onToggleAll(),
          ),
          const Text('全选', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '共 ${cart.items.length} 种 / ${cart.totalQuantity} 件',
              style: const TextStyle(color: CommerceColors.muted, fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: disabled || cart.selectedItems.isEmpty
                ? null
                : onDeleteSelected,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('删除已选'),
          ),
        ],
      ),
    );
  }
}

class _CartItems extends StatelessWidget {
  const _CartItems({
    required this.cart,
    required this.baseUrl,
    required this.busyBookIds,
    required this.busyAll,
    required this.onToggle,
    required this.onQuantity,
    required this.onDelete,
  });

  final ShoppingCart cart;
  final String baseUrl;
  final Set<int> busyBookIds;
  final bool busyAll;
  final Future<bool> Function(CartItem item) onToggle;
  final Future<bool> Function(CartItem item, int quantity) onQuantity;
  final ValueChanged<CartItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < cart.items.length; index++) ...[
          _CartItemTile(
            item: cart.items[index],
            imageUrl: commerceImageUrl(baseUrl, cart.items[index].coverUrl),
            busy: busyAll || busyBookIds.contains(cart.items[index].bookId),
            onToggle: () => onToggle(cart.items[index]),
            onQuantity: (value) => onQuantity(cart.items[index], value),
            onDelete: () => onDelete(cart.items[index]),
          ),
          if (index != cart.items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.imageUrl,
    required this.busy,
    required this.onToggle,
    required this.onQuantity,
    required this.onDelete,
  });

  final CartItem item;
  final String? imageUrl;
  final bool busy;
  final VoidCallback onToggle;
  final ValueChanged<int> onQuantity;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 540;
          final information = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item.selected,
                onChanged: busy || !item.available ? null : (_) => onToggle(),
              ),
              const SizedBox(width: 4),
              CommerceCover(url: imageUrl, width: narrow ? 66 : 76),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'ISBN ${item.isbn}',
                      style: const TextStyle(
                        color: CommerceColors.placeholder,
                        fontSize: 11,
                      ),
                    ),
                    if (isActivePreSale(
                      item.preSale,
                      item.preSaleReleaseTime,
                    )) ...[
                      const SizedBox(height: 8),
                      Text(
                        preSaleNotice(item.preSaleReleaseTime!),
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      item.available ? '库存 ${item.stock} 本' : '暂不可购买',
                      style: TextStyle(
                        color: item.available
                            ? CommerceColors.success
                            : CommerceColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuantityStepper(
                quantity: item.quantity,
                maximum: item.stock > 999 ? 999 : item.stock,
                disabled: busy || !item.available,
                onChanged: onQuantity,
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 82,
                child: Text(
                  money(item.subtotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: '删除商品',
                onPressed: busy ? null : onDelete,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          );
          if (narrow) {
            return Column(
              children: [
                information,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: information),
              const SizedBox(width: 18),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.maximum,
    required this.disabled,
    required this.onChanged,
  });

  final int quantity;
  final int maximum;
  final bool disabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(
            tooltip: '减少数量',
            icon: Icons.remove_rounded,
            enabled: !disabled && quantity > 1,
            onPressed: () => onChanged(quantity - 1),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          _button(
            tooltip: '增加数量',
            icon: Icons.add_rounded,
            enabled: !disabled && quantity < maximum,
            onPressed: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required String tooltip,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 36),
      icon: Icon(icon, size: 17),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.cart,
    required this.disabled,
    required this.onCheckout,
  });

  final ShoppingCart cart;
  final bool disabled;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final unavailable = cart.selectedItems.any((item) => !item.available);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: CommerceColors.ink,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本次结算',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'serif',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          _SummaryLine(label: '已选数量', value: '${cart.selectedQuantity} 件'),
          const SizedBox(height: 12),
          _SummaryLine(label: '商品金额', value: money(cart.selectedAmount)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('合计', style: TextStyle(color: Colors.white70)),
              const Spacer(),
              Text(
                money(cart.selectedAmount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: disabled ? null : onCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: CommerceColors.ink,
                disabledBackgroundColor: Colors.white24,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('去结算'),
            ),
          ),
          if (unavailable) ...[
            const SizedBox(height: 12),
            const Text(
              '已选商品中存在无货或下架图书，请取消勾选后结算。',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 42,
            color: CommerceColors.placeholder,
          ),
          const SizedBox(height: 16),
          const Text(
            '购物车还是空的',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          const Text(
            '从书库挑几本想读的书吧。',
            style: TextStyle(color: CommerceColors.muted),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => context.go('/books'),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('浏览书库'),
          ),
        ],
      ),
    );
  }
}

class _CartLoading extends StatelessWidget {
  const _CartLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _CartFailure extends StatelessWidget {
  const _CartFailure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 38),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}
