import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../data/models/profile/user_address.dart';
import '../../cart/data/cart_models.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/commerce_widgets.dart';
import 'orders_controller.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _remarkController = TextEditingController();
  int? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      final state = ref.read(cartControllerProvider);
      if (state.status == CartStatus.initial) {
        ref.read(cartControllerProvider.notifier).loadCart();
      }
    });
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartControllerProvider);
    final orderState = ref.watch(ordersControllerProvider);
    final addresses = ref.watch(checkoutAddressesProvider);
    final baseUrl = ref.watch(appConfigProvider).baseUrl;
    final selectedItems = cartState.cart.selectedItems;

    return Scaffold(
      backgroundColor: CommerceColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const CommerceHeader(current: 'cart'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 64),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommerceTitle(
                          eyebrow: 'CHECKOUT  ·  确认订单',
                          title: '送到哪里？',
                          subtitle: '选择收货地址并最后确认商品，订单金额由服务端重新计算。',
                          trailing: OutlinedButton.icon(
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: const Text('返回购物袋'),
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (orderState.errorMessage != null) ...[
                          CommerceNotice(message: orderState.errorMessage!),
                          const SizedBox(height: 18),
                        ],
                        if (cartState.status == CartStatus.loading &&
                            selectedItems.isEmpty)
                          const SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (selectedItems.isEmpty)
                          _NothingToCheckout(onBack: () => context.go('/cart'))
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final form = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel(
                                    number: '01',
                                    title: '收货地址',
                                    action: TextButton.icon(
                                      onPressed: () => context.push('/profile'),
                                      icon: const Icon(
                                        Icons.settings_outlined,
                                        size: 17,
                                      ),
                                      label: const Text('管理地址'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  addresses.when(
                                    loading: () => const _AddressLoading(),
                                    error: (error, _) => _AddressFailure(
                                      onRetry: () => ref.invalidate(
                                        checkoutAddressesProvider,
                                      ),
                                    ),
                                    data: (items) => _AddressSelector(
                                      addresses: items,
                                      selectedId: _effectiveAddress(items)?.id,
                                      onSelected: (id) {
                                        setState(() => _selectedAddressId = id);
                                      },
                                      onAdd: () => context.push('/profile'),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  const _SectionLabel(
                                    number: '02',
                                    title: '订单备注',
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _remarkController,
                                    maxLength: 200,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: '选填，例如配送时间或包装说明',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(
                                          color: CommerceColors.line,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(
                                          color: CommerceColors.line,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                              final review = _CheckoutReview(
                                cart: cartState.cart,
                                baseUrl: baseUrl,
                                creating: orderState.creating,
                                addressReady:
                                    addresses.valueOrNull?.isNotEmpty == true,
                                onCreate: _createOrder,
                              );
                              if (constraints.maxWidth < 820) {
                                return Column(
                                  children: [
                                    form,
                                    const SizedBox(height: 28),
                                    review,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: form),
                                  const SizedBox(width: 28),
                                  SizedBox(width: 360, child: review),
                                ],
                              );
                            },
                          ),
                      ],
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

  UserAddress? _effectiveAddress(List<UserAddress> addresses) {
    if (addresses.isEmpty) return null;
    for (final address in addresses) {
      if (address.id == _selectedAddressId) return address;
    }
    for (final address in addresses) {
      if (address.defaultAddress) return address;
    }
    return addresses.first;
  }

  Future<void> _createOrder() async {
    final addresses =
        ref.read(checkoutAddressesProvider).valueOrNull ?? const [];
    final address = _effectiveAddress(addresses);
    if (address == null) return;
    final order = await ref
        .read(ordersControllerProvider.notifier)
        .createOrder(addressId: address.id, remark: _remarkController.text);
    if (!mounted || order == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('订单 ${order.orderNo} 已创建，请完成支付')));
    context.go('/orders');
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.number, required this.title, this.action});

  final String number;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CommerceColors.ink,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

class _AddressSelector extends StatelessWidget {
  const _AddressSelector({
    required this.addresses,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
  });

  final List<UserAddress> addresses;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CommerceColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            const Icon(Icons.location_off_outlined, size: 32),
            const SizedBox(height: 10),
            const Text('还没有收货地址'),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('添加地址'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < addresses.length; index++) ...[
          _AddressOption(
            address: addresses[index],
            selected: addresses[index].id == selectedId,
            onTap: () => onSelected(addresses[index].id),
          ),
          if (index != addresses.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final UserAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: selected ? CommerceColors.ink : CommerceColors.line,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? CommerceColors.ink
                    : CommerceColors.placeholder,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            address.receiverName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          address.receiverPhone,
                          style: const TextStyle(
                            color: CommerceColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        if (address.defaultAddress) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: CommerceColors.sand,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '默认',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      address.fullAddress,
                      style: const TextStyle(
                        color: CommerceColors.muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutReview extends StatelessWidget {
  const _CheckoutReview({
    required this.cart,
    required this.baseUrl,
    required this.creating,
    required this.addressReady,
    required this.onCreate,
  });

  final ShoppingCart cart;
  final String baseUrl;
  final bool creating;
  final bool addressReady;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '订单内容',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < cart.selectedItems.length; index++) ...[
            _ReviewLine(
              item: cart.selectedItems[index],
              imageUrl: commerceImageUrl(
                baseUrl,
                cart.selectedItems[index].coverUrl,
              ),
            ),
            if (index != cart.selectedItems.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Text(
                '共 ${cart.selectedQuantity} 件',
                style: const TextStyle(color: CommerceColors.muted),
              ),
              const Spacer(),
              Text(
                money(cart.selectedAmount),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: creating || !addressReady ? null : onCreate,
              icon: creating
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(creating ? '正在创建订单' : '提交订单'),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '提交后进入待支付状态，可在订单页使用模拟支付。',
            style: TextStyle(
              color: CommerceColors.placeholder,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.item, required this.imageUrl});

  final CartItem item;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CommerceCover(url: imageUrl, width: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '${money(item.salePrice)} × ${item.quantity}',
                style: const TextStyle(
                  color: CommerceColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(money(item.subtotal), style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _AddressLoading extends StatelessWidget {
  const _AddressLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _AddressFailure extends StatelessWidget {
  const _AddressFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CommerceNotice(message: '收货地址加载失败，请刷新后重试'),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('重新加载地址'),
        ),
      ],
    );
  }
}

class _NothingToCheckout extends StatelessWidget {
  const _NothingToCheckout({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_box_outline_blank_rounded, size: 38),
          const SizedBox(height: 14),
          const Text('没有可结算的已选商品'),
          const SizedBox(height: 18),
          FilledButton(onPressed: onBack, child: const Text('返回购物袋')),
        ],
      ),
    );
  }
}
