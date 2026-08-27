import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/utils/media_url.dart';
import '../../../data/models/profile/user_address.dart';
import '../../../data/models/profile/user_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/commerce_widgets.dart';
import '../../orders/data/order_models.dart';
import '../../orders/presentation/orders_controller.dart';
import 'profile_controller.dart';

enum ProfileSection { overview, profile, security }

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  ProfileSection _section = ProfileSection.overview;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(profileControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final baseUrl = ref.watch(appConfigProvider).baseUrl;
    ref.listen<ProfileState>(profileControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && message != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      backgroundColor: ProfileColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            if (compact) {
              return Column(
                children: [
                  _MobileHeader(onLogout: _logout),
                  _MobileSectionBar(
                    selected: _section,
                    onSelected: _selectSection,
                  ),
                  const Divider(height: 1, color: ProfileColors.line),
                  Expanded(child: _buildMain(state, compact: true)),
                ],
              );
            }
            return Row(
              children: [
                SizedBox(
                  width: 276,
                  child: _ProfileSidebar(
                    profile: state.profile,
                    avatarUrl: resolveMediaUrl(
                      baseUrl,
                      state.profile?.avatarUrl,
                    ),
                    selected: _section,
                    onSelected: _selectSection,
                    onLogout: _logout,
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: ProfileColors.line,
                ),
                Expanded(child: _buildMain(state, compact: false)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMain(ProfileState state, {required bool compact}) {
    if (state.status == ProfileStatus.loading && state.profile == null) {
      return const _ProfileLoading();
    }
    if (state.status == ProfileStatus.failure && state.profile == null) {
      return _ProfileFailure(
        message:
            state.errorMessage ??
            '\u7528\u6237\u4e2d\u5fc3\u6682\u65f6\u65e0\u6cd5\u52a0\u8f7d',
        onRetry: () => ref.read(profileControllerProvider.notifier).load(),
      );
    }
    final profile = state.profile;
    if (profile == null) {
      return const _ProfileLoading();
    }
    final shippedOrders = ref.watch(shippedOrdersProvider);
    final avatarUrl = resolveMediaUrl(
      ref.watch(appConfigProvider).baseUrl,
      profile.avatarUrl,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 56,
        compact ? 30 : 48,
        compact ? 20 : 56,
        64,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: switch (_section) {
            ProfileSection.overview => _OverviewSection(
              profile: profile,
              avatarUrl: avatarUrl,
              defaultAddress: state.defaultAddress,
              shippedOrders: shippedOrders,
              onOpenProfile: () => _selectSection(ProfileSection.profile),
              onRetryShippedOrders: () => ref.invalidate(shippedOrdersProvider),
            ),
            ProfileSection.profile => _ProfileEditor(
              profile: profile,
              avatarUrl: avatarUrl,
              submitting: state.submitting,
              onSave: _saveProfile,
              onUploadAvatar: _uploadAvatar,
              addresses: state.addresses,
              busyAddressId: state.busyAddressId,
              onAddAddress: () => _editAddress(),
              onEditAddress: _editAddress,
              onSetDefaultAddress: _setDefaultAddress,
              onDeleteAddress: _deleteAddress,
            ),
            ProfileSection.security => _SecuritySection(
              submitting: state.submitting,
              onChangePassword: _changePassword,
            ),
          },
        ),
      ),
    );
  }

  void _selectSection(ProfileSection section) {
    setState(() => _section = section);
  }

  Future<bool> _saveProfile({
    required String nickname,
    required String email,
    required String phone,
  }) async {
    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(nickname: nickname, email: email, phone: phone);
    if (success && mounted) {
      _showSuccess('\u4e2a\u4eba\u8d44\u6599\u5df2\u4fdd\u5b58');
    }
    return success;
  }

  Future<void> _uploadAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) {
      return;
    }

    final success = await ref
        .read(profileControllerProvider.notifier)
        .uploadAvatar(bytes: file!.bytes!, filename: file.name);
    if (success && mounted) {
      _showSuccess('头像已更新');
    }
  }

  Future<bool> _changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final success = await ref
        .read(profileControllerProvider.notifier)
        .changePassword(
          oldPassword: oldPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );
    if (success && mounted) {
      _showSuccess('\u5bc6\u7801\u5df2\u4fee\u6539');
    }
    return success;
  }

  Future<void> _editAddress([UserAddress? address]) async {
    final input = await showDialog<UserAddressInput>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddressDialog(address: address),
    );
    if (input == null) {
      return;
    }
    final success = await ref
        .read(profileControllerProvider.notifier)
        .saveAddress(input: input, addressId: address?.id);
    if (success && mounted) {
      _showSuccess(
        address == null
            ? '\u6536\u8d27\u5730\u5740\u5df2\u6dfb\u52a0'
            : '\u6536\u8d27\u5730\u5740\u5df2\u66f4\u65b0',
      );
    }
  }

  Future<void> _setDefaultAddress(UserAddress address) async {
    if (address.defaultAddress) {
      return;
    }
    final success = await ref
        .read(profileControllerProvider.notifier)
        .setDefaultAddress(address.id);
    if (success && mounted) {
      _showSuccess('\u9ed8\u8ba4\u6536\u8d27\u5730\u5740\u5df2\u66f4\u65b0');
    }
  }

  Future<void> _deleteAddress(UserAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\u5220\u9664\u6536\u8d27\u5730\u5740'),
        content: Text(
          '\u786e\u5b9a\u5220\u9664 ${address.receiverName} \u7684\u6536\u8d27\u5730\u5740\u5417\uff1f',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('\u5220\u9664'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final success = await ref
        .read(profileControllerProvider.notifier)
        .deleteAddress(address.id);
    if (success && mounted) {
      _showSuccess('\u6536\u8d27\u5730\u5740\u5df2\u5220\u9664');
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) {
      context.go('/login');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Text(message),
            ],
          ),
        ),
      );
  }
}

class _ProfileSidebar extends StatelessWidget {
  const _ProfileSidebar({
    required this.profile,
    required this.avatarUrl,
    required this.selected,
    required this.onSelected,
    required this.onLogout,
  });

  final UserProfile? profile;
  final String? avatarUrl;
  final ProfileSection selected;
  final ValueChanged<ProfileSection> onSelected;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BookstoreBrand(),
          const SizedBox(height: 34),
          if (profile != null) ...[
            Row(
              children: [
                _ProfileAvatar(
                  name: profile!.displayName,
                  imageUrl: avatarUrl,
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile!.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ProfileColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${profile!.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ProfileColors.placeholder,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
          const _SidebarLabel('\u6211\u7684\u8d26\u6237'),
          const SizedBox(height: 8),
          for (final section in ProfileSection.values)
            _SidebarItem(
              section: section,
              selected: selected == section,
              onPressed: () => onSelected(section),
            ),
          const Spacer(),
          const Divider(color: ProfileColors.line),
          const SizedBox(height: 8),
          _SidebarCommand(
            icon: Icons.arrow_back_rounded,
            label: '\u8fd4\u56de\u4e66\u5e97',
            onPressed: () => context.go('/books'),
          ),
          _SidebarCommand(
            icon: Icons.logout_rounded,
            label: '\u9000\u51fa\u767b\u5f55',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          const BookstoreBrand(),
          const Spacer(),
          IconButton(
            tooltip: '\u8fd4\u56de\u4e66\u5e97',
            onPressed: () => context.go('/books'),
            icon: const Icon(Icons.storefront_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: '\u8d26\u6237\u83dc\u5355',
            onSelected: (value) {
              if (value == 'logout') {
                onLogout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logout',
                child: Text('\u9000\u51fa\u767b\u5f55'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileSectionBar extends StatelessWidget {
  const _MobileSectionBar({required this.selected, required this.onSelected});

  final ProfileSection selected;
  final ValueChanged<ProfileSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
      child: Row(
        children: ProfileSection.values
            .map((section) {
              final active = section == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton.icon(
                  onPressed: () => onSelected(section),
                  icon: Icon(_sectionIcon(section), size: 17),
                  label: Text(_sectionLabel(section)),
                  style: TextButton.styleFrom(
                    foregroundColor: active
                        ? Colors.white
                        : ProfileColors.muted,
                    backgroundColor: active
                        ? ProfileColors.ink
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: ProfileColors.placeholder,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.onPressed,
  });

  final ProfileSection section;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedColor: ProfileColors.ink,
        selectedTileColor: Colors.white,
        leading: Icon(_sectionIcon(section), size: 20),
        title: Text(
          _sectionLabel(section),
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.arrow_forward_rounded, size: 16)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onPressed,
      ),
    );
  }
}

class _SidebarCommand extends StatelessWidget {
  const _SidebarCommand({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: ProfileColors.muted,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.profile,
    required this.avatarUrl,
    required this.defaultAddress,
    required this.shippedOrders,
    required this.onOpenProfile,
    required this.onRetryShippedOrders,
  });

  final UserProfile profile;
  final String? avatarUrl;
  final UserAddress? defaultAddress;
  final AsyncValue<List<BookOrder>> shippedOrders;
  final VoidCallback onOpenProfile;
  final VoidCallback onRetryShippedOrders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          eyebrow: 'OVERVIEW  \u00b7  \u8d26\u6237\u6982\u89c8',
          title: '\u4e2a\u4eba\u4e2d\u5fc3',
          subtitle:
              '\u67e5\u770b\u9ed8\u8ba4\u6536\u8d27\u5730\u5740\u3001\u53d1\u8d27\u8fdb\u5ea6\u548c\u8d26\u6237\u72b6\u6001\u3002',
        ),
        const SizedBox(height: 34),
        _AccountHero(
          profile: profile,
          avatarUrl: avatarUrl,
          onEdit: onOpenProfile,
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final tileWidth = width >= 780 ? (width - 32) / 3 : width;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricTile(
                  width: tileWidth,
                  icon: Icons.location_on_outlined,
                  label: '\u9ed8\u8ba4\u5730\u5740',
                  value: defaultAddress == null
                      ? '\u672a\u8bbe\u7f6e'
                      : defaultAddress!.receiverName,
                  detail: defaultAddress == null
                      ? '\u8bf7\u5728\u4e2a\u4eba\u8d44\u6599\u4e2d\u7ba1\u7406\u5730\u5740'
                      : '\u4e0b\u5355\u65f6\u4f18\u5148\u4f7f\u7528\u6b64\u5730\u5740',
                ),
                _MetricTile(
                  width: tileWidth,
                  icon: Icons.verified_user_outlined,
                  label: '\u8d26\u6237\u72b6\u6001',
                  value: profile.isEnabled ? '\u6b63\u5e38' : '\u505c\u7528',
                  detail: profile.isAdmin
                      ? '\u7ba1\u7406\u5458\u8d26\u6237'
                      : '\u666e\u901a\u7528\u6237',
                ),
                _MetricTile(
                  width: tileWidth,
                  icon: Icons.calendar_today_outlined,
                  label: '\u52a0\u5165\u4e66\u5e97',
                  value: _dateOf(profile.createTime),
                  detail:
                      '\u9605\u8bfb\u6863\u6848\u6301\u7eed\u8bb0\u5f55\u4e2d',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _DefaultAddressPanel(address: defaultAddress),
        const SizedBox(height: 38),
        _ShippingOrdersPanel(
          orders: shippedOrders,
          onRetry: onRetryShippedOrders,
        ),
      ],
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({
    required this.profile,
    required this.avatarUrl,
    required this.onEdit,
  });

  final UserProfile profile;
  final String? avatarUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ProfileColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ProfileAvatar(
            name: profile.displayName,
            imageUrl: avatarUrl,
            size: 64,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: ProfileColors.ink,
                    fontFamily: 'serif',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '@${profile.username}  \u00b7  ${profile.email.isEmpty ? '\u672a\u586b\u5199\u90ae\u7bb1' : profile.email}',
                  style: const TextStyle(
                    color: ProfileColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('\u7f16\u8f91\u8d44\u6599'),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: ProfileColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ProfileColors.sand,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 21),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: ProfileColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ProfileColors.placeholder,
                      fontSize: 11,
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

class _DefaultAddressPanel extends StatelessWidget {
  const _DefaultAddressPanel({required this.address});

  final UserAddress? address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 18, 20),
      decoration: BoxDecoration(
        border: Border.all(color: ProfileColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, size: 23),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\u9ed8\u8ba4\u6536\u8d27\u5730\u5740',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  address == null
                      ? '\u8fd8\u6ca1\u6709\u6536\u8d27\u5730\u5740\uff0c\u4e0b\u5355\u524d\u8bb0\u5f97\u6dfb\u52a0\u3002'
                      : '${address!.receiverName}  ${address!.receiverPhone}\n${address!.fullAddress}',
                  style: const TextStyle(
                    color: ProfileColors.muted,
                    fontSize: 13,
                    height: 1.55,
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

class _ShippingOrdersPanel extends StatelessWidget {
  const _ShippingOrdersPanel({required this.orders, required this.onRetry});

  final AsyncValue<List<BookOrder>> orders;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => orders.when(
    data: (orders) {
      final shippedItems = <({BookOrder order, OrderLine item})>[
        for (final order in orders)
          for (final item in order.items) (order: order, item: item),
      ];
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: ProfileColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 21),
                SizedBox(width: 10),
                Text(
                  '\u6b63\u5728\u53d1\u8d27',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '\u5df2\u51fa\u5e93\u7684\u56fe\u4e66\u4f1a\u5728\u8fd9\u91cc\u663e\u793a\u3002',
              style: TextStyle(color: ProfileColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            if (shippedItems.isEmpty)
              const Text(
                '\u5f53\u524d\u6ca1\u6709\u6b63\u5728\u53d1\u8d27\u7684\u56fe\u4e66\u3002',
                style: TextStyle(color: ProfileColors.muted),
              )
            else
              ...shippedItems.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => context.go('/orders/${entry.order.id}'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_outlined, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.item.bookTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '\u8ba2\u5355 ${entry.order.orderNo}  \u00b7  \u6570\u91cf x${entry.item.quantity}',
                                  style: const TextStyle(
                                    color: ProfileColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
    loading: () => const SizedBox(
      height: 132,
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (_, _) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        border: Border.all(color: ProfileColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '\u6b63\u5728\u53d1\u8d27\u7684\u56fe\u4e66\u6682\u65f6\u65e0\u6cd5\u52a0\u8f7d\u3002',
              style: TextStyle(color: ProfileColors.muted),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('\u91cd\u8bd5'),
          ),
        ],
      ),
    ),
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({
    required this.profile,
    required this.avatarUrl,
    required this.submitting,
    required this.onSave,
    required this.onUploadAvatar,
    required this.addresses,
    required this.busyAddressId,
    required this.onAddAddress,
    required this.onEditAddress,
    required this.onSetDefaultAddress,
    required this.onDeleteAddress,
  });

  final UserProfile profile;
  final String? avatarUrl;
  final bool submitting;
  final Future<bool> Function({
    required String nickname,
    required String email,
    required String phone,
  })
  onSave;
  final Future<void> Function() onUploadAvatar;
  final List<UserAddress> addresses;
  final int? busyAddressId;
  final VoidCallback onAddAddress;
  final ValueChanged<UserAddress> onEditAddress;
  final ValueChanged<UserAddress> onSetDefaultAddress;
  final ValueChanged<UserAddress> onDeleteAddress;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.profile.nickname);
    _emailController = TextEditingController(text: widget.profile.email);
    _phoneController = TextEditingController(text: widget.profile.phone);
  }

  @override
  void didUpdateWidget(covariant _ProfileEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.profile, widget.profile)) {
      _nicknameController.text = widget.profile.nickname;
      _emailController.text = widget.profile.email;
      _phoneController.text = widget.profile.phone;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await widget.onSave(
      nickname: _nicknameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          eyebrow: 'PROFILE  \u00b7  \u4e2a\u4eba\u8d44\u6599',
          title: '\u7f16\u8f91\u8d44\u6599',
          subtitle:
              '\u5b8c\u5584\u8054\u7cfb\u65b9\u5f0f\uff0c\u8ba9\u8ba2\u5355\u4e0e\u6536\u8d27\u4fe1\u606f\u66f4\u6e05\u6670\u3002',
        ),
        const SizedBox(height: 34),
        _FormSurface(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ProfileAvatar(
                          name: widget.profile.displayName,
                          imageUrl: widget.avatarUrl,
                          size: 96,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Tooltip(
                            message: '上传头像',
                            child: Material(
                              color: ProfileColors.ink,
                              shape: const CircleBorder(),
                              child: IconButton(
                                onPressed: widget.submitting
                                    ? null
                                    : widget.onUploadAvatar,
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                iconSize: 18,
                                color: Colors.white,
                                disabledColor: ProfileColors.placeholder,
                                icon: const Icon(Icons.photo_camera_outlined),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _ReadOnlyField(
                  label: '\u7528\u6237\u540d',
                  value: widget.profile.username,
                  icon: Icons.alternate_email_rounded,
                ),
                const SizedBox(height: 20),
                _ProfileTextField(
                  controller: _nicknameController,
                  label: '\u6635\u79f0',
                  hintText:
                      '\u8f93\u5165\u4f60\u5e0c\u671b\u5c55\u793a\u7684\u540d\u5b57',
                  icon: Icons.badge_outlined,
                  validator: (value) {
                    if ((value ?? '').trim().length > 30) {
                      return '\u6635\u79f0\u4e0d\u80fd\u8d85\u8fc7 30 \u4e2a\u5b57\u7b26';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _ProfileTextField(
                  controller: _emailController,
                  label: '\u90ae\u7bb1',
                  hintText: 'name@example.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isNotEmpty &&
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return '\u8bf7\u8f93\u5165\u6b63\u786e\u7684\u90ae\u7bb1\u5730\u5740';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _ProfileTextField(
                  controller: _phoneController,
                  label: '\u624b\u673a\u53f7',
                  hintText: '\u8f93\u5165 11 \u4f4d\u624b\u673a\u53f7',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isNotEmpty &&
                        !RegExp(r'^1[3-9]\d{9}$').hasMatch(text)) {
                      return '\u8bf7\u8f93\u5165\u6b63\u786e\u7684\u624b\u673a\u53f7';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: widget.submitting ? null : _submit,
                    icon: widget.submitting
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      widget.submitting
                          ? '\u6b63\u5728\u4fdd\u5b58'
                          : '\u4fdd\u5b58\u8d44\u6599',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 52),
        _AddressSection(
          addresses: widget.addresses,
          busyAddressId: widget.busyAddressId,
          onAdd: widget.onAddAddress,
          onEdit: widget.onEditAddress,
          onSetDefault: widget.onSetDefaultAddress,
          onDelete: widget.onDeleteAddress,
        ),
      ],
    );
  }
}

class _AddressSection extends StatelessWidget {
  const _AddressSection({
    required this.addresses,
    required this.busyAddressId,
    required this.onAdd,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  final List<UserAddress> addresses;
  final int? busyAddressId;
  final VoidCallback onAdd;
  final ValueChanged<UserAddress> onEdit;
  final ValueChanged<UserAddress> onSetDefault;
  final ValueChanged<UserAddress> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          eyebrow: 'ADDRESS  \u00b7  \u6536\u8d27\u5730\u5740',
          title: '\u6536\u8d27\u5730\u5740',
          subtitle:
              '\u7ba1\u7406\u5e38\u7528\u6536\u8d27\u4fe1\u606f\uff0c\u9ed8\u8ba4\u5730\u5740\u4f1a\u5728\u4e0b\u5355\u65f6\u4f18\u5148\u663e\u793a\u3002',
          action: FilledButton.icon(
            onPressed: busyAddressId == null ? onAdd : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('\u65b0\u589e\u5730\u5740'),
          ),
        ),
        const SizedBox(height: 34),
        if (addresses.isEmpty)
          _AddressEmpty(onAdd: onAdd)
        else
          ...addresses.map(
            (address) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _AddressCard(
                address: address,
                busy: busyAddressId == address.id,
                disabled: busyAddressId != null,
                onEdit: () => onEdit(address),
                onSetDefault: () => onSetDefault(address),
                onDelete: () => onDelete(address),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.busy,
    required this.disabled,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  final UserAddress address;
  final bool busy;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 14, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: address.defaultAddress
              ? ProfileColors.ink
              : ProfileColors.line,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: busy
          ? const SizedBox(
              height: 84,
              child: Center(child: CircularProgressIndicator()),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ProfileColors.sand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_on_outlined, size: 21),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            address.receiverName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            address.receiverPhone,
                            style: const TextStyle(
                              color: ProfileColors.muted,
                              fontSize: 13,
                            ),
                          ),
                          if (address.defaultAddress)
                            const _StatusTag(label: '\u9ed8\u8ba4\u5730\u5740'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        address.fullAddress,
                        style: const TextStyle(
                          color: ProfileColors.muted,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                      if (address.postalCode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '\u90ae\u653f\u7f16\u7801 ${address.postalCode}',
                          style: const TextStyle(
                            color: ProfileColors.placeholder,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !disabled,
                  tooltip: '\u5730\u5740\u64cd\u4f5c',
                  onSelected: (value) {
                    switch (value) {
                      case 'default':
                        onSetDefault();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!address.defaultAddress)
                      const PopupMenuItem(
                        value: 'default',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.check_circle_outline, size: 19),
                          title: Text('\u8bbe\u4e3a\u9ed8\u8ba4'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined, size: 19),
                        title: Text('\u7f16\u8f91'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline, size: 19),
                        title: Text('\u5220\u9664'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _AddressEmpty extends StatelessWidget {
  const _AddressEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      decoration: BoxDecoration(
        border: Border.all(color: ProfileColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.add_location_alt_outlined,
            size: 38,
            color: ProfileColors.muted,
          ),
          const SizedBox(height: 14),
          const Text(
            '\u8fd8\u6ca1\u6709\u6536\u8d27\u5730\u5740',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          const Text(
            '\u6dfb\u52a0\u7b2c\u4e00\u4e2a\u5730\u5740\u540e\uff0c\u5b83\u4f1a\u81ea\u52a8\u6210\u4e3a\u9ed8\u8ba4\u5730\u5740\u3002',
            textAlign: TextAlign.center,
            style: TextStyle(color: ProfileColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('\u6dfb\u52a0\u5730\u5740'),
          ),
        ],
      ),
    );
  }
}

class _SecuritySection extends StatefulWidget {
  const _SecuritySection({
    required this.submitting,
    required this.onChangePassword,
  });

  final bool submitting;
  final Future<bool> Function({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  })
  onChangePassword;

  @override
  State<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<_SecuritySection> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final success = await widget.onChangePassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (success) {
      _formKey.currentState!.reset();
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          eyebrow: 'SECURITY  \u00b7  \u8d26\u6237\u5b89\u5168',
          title: '\u4fee\u6539\u5bc6\u7801',
          subtitle:
              '\u5b9a\u671f\u66f4\u6362\u5bc6\u7801\uff0c\u4fdd\u6301\u8d26\u6237\u548c\u8ba2\u5355\u4fe1\u606f\u5b89\u5168\u3002',
        ),
        const SizedBox(height: 34),
        _FormSurface(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PasswordField(
                  controller: _oldPasswordController,
                  label: '\u5f53\u524d\u5bc6\u7801',
                  visible: _showOldPassword,
                  onToggle: () =>
                      setState(() => _showOldPassword = !_showOldPassword),
                  validator: (value) => (value ?? '').isEmpty
                      ? '\u8bf7\u8f93\u5165\u5f53\u524d\u5bc6\u7801'
                      : null,
                ),
                const SizedBox(height: 20),
                _PasswordField(
                  controller: _newPasswordController,
                  label: '\u65b0\u5bc6\u7801',
                  visible: _showNewPassword,
                  onToggle: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                  validator: (value) => (value ?? '').length < 6
                      ? '\u65b0\u5bc6\u7801\u81f3\u5c11\u9700\u8981 6 \u4e2a\u5b57\u7b26'
                      : null,
                ),
                const SizedBox(height: 20),
                _PasswordField(
                  controller: _confirmPasswordController,
                  label: '\u786e\u8ba4\u65b0\u5bc6\u7801',
                  visible: _showConfirmPassword,
                  onToggle: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                  validator: (value) => value != _newPasswordController.text
                      ? '\u4e24\u6b21\u8f93\u5165\u7684\u65b0\u5bc6\u7801\u4e0d\u4e00\u81f4'
                      : null,
                ),
                const SizedBox(height: 18),
                const _SecurityNotice(),
                const SizedBox(height: 26),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: widget.submitting ? null : _submit,
                    icon: widget.submitting
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_reset_rounded, size: 19),
                    label: Text(
                      widget.submitting
                          ? '\u6b63\u5728\u63d0\u4ea4'
                          : '\u66f4\u65b0\u5bc6\u7801',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ProfileColors.sand,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '\u65b0\u5bc6\u7801\u5efa\u8bae\u540c\u65f6\u5305\u542b\u5b57\u6bcd\u3001\u6570\u5b57\u548c\u7b26\u53f7\uff0c\u4e0d\u8981\u4e0e\u5176\u4ed6\u7f51\u7ad9\u5171\u7528\u3002',
              style: TextStyle(
                color: ProfileColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.address});

  final UserAddress? address;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _provinceController;
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;
  late final TextEditingController _detailController;
  late final TextEditingController _postalCodeController;
  late bool _defaultAddress;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    _nameController = TextEditingController(text: address?.receiverName ?? '');
    _phoneController = TextEditingController(
      text: address?.receiverPhone ?? '',
    );
    _provinceController = TextEditingController(text: address?.province ?? '');
    _cityController = TextEditingController(text: address?.city ?? '');
    _districtController = TextEditingController(text: address?.district ?? '');
    _detailController = TextEditingController(
      text: address?.detailAddress ?? '',
    );
    _postalCodeController = TextEditingController(
      text: address?.postalCode ?? '',
    );
    _defaultAddress = address?.defaultAddress ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _detailController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      UserAddressInput(
        receiverName: _nameController.text.trim(),
        receiverPhone: _phoneController.text.trim(),
        province: _provinceController.text.trim(),
        city: _cityController.text.trim(),
        district: _districtController.text.trim(),
        detailAddress: _detailController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        defaultAddress: _defaultAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.address == null
                                ? '\u65b0\u589e\u6536\u8d27\u5730\u5740'
                                : '\u7f16\u8f91\u6536\u8d27\u5730\u5740',
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '\u8bf7\u586b\u5199\u5b8c\u6574\u4fe1\u606f\uff0c\u7f16\u8f91\u65f6\u5c06\u6574\u4f53\u66f4\u65b0\u5730\u5740\u3002',
                            style: TextStyle(
                              color: ProfileColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '\u5173\u95ed',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 520;
                    final fields = [
                      _ProfileTextField(
                        controller: _nameController,
                        label: '\u6536\u8d27\u4eba',
                        hintText: '\u8f93\u5165\u6536\u8d27\u4eba\u59d3\u540d',
                        icon: Icons.person_outline,
                        validator: _required(
                          '\u8bf7\u8f93\u5165\u6536\u8d27\u4eba',
                        ),
                      ),
                      _ProfileTextField(
                        controller: _phoneController,
                        label: '\u8054\u7cfb\u7535\u8bdd',
                        hintText: '\u8f93\u5165\u6536\u8d27\u7535\u8bdd',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: _required(
                          '\u8bf7\u8f93\u5165\u8054\u7cfb\u7535\u8bdd',
                        ),
                      ),
                      _ProfileTextField(
                        controller: _provinceController,
                        label: '\u7701\u4efd',
                        hintText: '\u4f8b\u5982\uff1a\u5e7f\u4e1c\u7701',
                        icon: Icons.map_outlined,
                        validator: _required('\u8bf7\u8f93\u5165\u7701\u4efd'),
                      ),
                      _ProfileTextField(
                        controller: _cityController,
                        label: '\u57ce\u5e02',
                        hintText: '\u4f8b\u5982\uff1a\u6df1\u5733\u5e02',
                        icon: Icons.location_city_outlined,
                        validator: _required('\u8bf7\u8f93\u5165\u57ce\u5e02'),
                      ),
                      _ProfileTextField(
                        controller: _districtController,
                        label: '\u533a / \u53bf',
                        hintText:
                            '\u4f8b\u5982\uff1a\u5357\u5c71\u533a\uff08\u53ef\u9009\uff09',
                        icon: Icons.place_outlined,
                      ),
                      _ProfileTextField(
                        controller: _postalCodeController,
                        label: '\u90ae\u653f\u7f16\u7801',
                        hintText:
                            '\u4f8b\u5982\uff1a518000\uff08\u53ef\u9009\uff09',
                        icon: Icons.markunread_mailbox_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ];
                    if (!twoColumns) {
                      return Column(
                        children: [
                          for (var i = 0; i < fields.length; i++) ...[
                            fields[i],
                            if (i != fields.length - 1)
                              const SizedBox(height: 16),
                          ],
                        ],
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < fields.length; i += 2) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: fields[i]),
                              const SizedBox(width: 16),
                              Expanded(child: fields[i + 1]),
                            ],
                          ),
                          if (i < fields.length - 2) const SizedBox(height: 16),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ProfileTextField(
                  controller: _detailController,
                  label: '\u8be6\u7ec6\u5730\u5740',
                  hintText:
                      '\u8857\u9053\u3001\u697c\u680b\u3001\u95e8\u724c\u53f7',
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  validator: _required(
                    '\u8bf7\u8f93\u5165\u8be6\u7ec6\u5730\u5740',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _defaultAddress,
                  onChanged: (value) {
                    setState(() => _defaultAddress = value);
                  },
                  title: const Text(
                    '\u8bbe\u4e3a\u9ed8\u8ba4\u6536\u8d27\u5730\u5740',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    '\u4e0b\u5355\u65f6\u4f18\u5148\u9009\u4e2d\u8fd9\u4e2a\u5730\u5740',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('\u53d6\u6d88'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('\u4fdd\u5b58\u5730\u5740'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FormFieldValidator<String> _required(String message) {
    return (value) => (value ?? '').trim().isEmpty ? message : null;
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: ProfileColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          title,
          style: const TextStyle(
            color: ProfileColors.ink,
            fontFamily: 'serif',
            fontSize: 42,
            height: 1.05,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
            color: ProfileColors.muted,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (action != null && constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 18), action!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            if (action != null) ...[const SizedBox(width: 18), action!],
          ],
        );
      },
    );
  }
}

class _FormSurface extends StatelessWidget {
  const _FormSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ProfileColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: ProfileColors.field,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ProfileColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ProfileColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ProfileColors.ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: ProfileColors.sand,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: ProfileColors.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(value)),
              const Text(
                '\u4e0d\u53ef\u4fee\u6539',
                style: TextStyle(
                  color: ProfileColors.placeholder,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          validator: validator,
          decoration: InputDecoration(
            hintText: '\u8bf7\u8f93\u5165$label',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              tooltip: visible
                  ? '\u9690\u85cf\u5bc6\u7801'
                  : '\u663e\u793a\u5bc6\u7801',
              onPressed: onToggle,
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            filled: true,
            fillColor: ProfileColors.field,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ProfileColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ProfileColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ProfileColors.ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ProfileColors.ink,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, required this.size, this.imageUrl});

  final String name;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: ProfileColors.line),
          shape: BoxShape.circle,
        ),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, _) => _AvatarInitials(name: name, size: size),
          errorWidget: (_, _, _) => _AvatarInitials(name: name, size: size),
        ),
      );
    }
    return _AvatarInitials(name: name, size: size);
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ProfileColors.sand,
        border: Border.all(color: ProfileColors.line),
        shape: BoxShape.circle,
      ),
      child: Text(
        text.isEmpty ? '\u8bfb' : text.substring(0, 1),
        style: TextStyle(
          color: ProfileColors.ink,
          fontFamily: 'serif',
          fontSize: size * .38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            '\u6b63\u5728\u6574\u7406\u4f60\u7684\u8d26\u6237\u8d44\u6599',
            style: TextStyle(color: ProfileColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ProfileFailure extends StatelessWidget {
  const _ProfileFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 38),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('\u91cd\u65b0\u52a0\u8f7d'),
            ),
          ],
        ),
      ),
    );
  }
}

String _sectionLabel(ProfileSection section) {
  return switch (section) {
    ProfileSection.overview => '\u8d26\u6237\u6982\u89c8',
    ProfileSection.profile => '\u4e2a\u4eba\u8d44\u6599',
    ProfileSection.security => '\u8d26\u6237\u5b89\u5168',
  };
}

IconData _sectionIcon(ProfileSection section) {
  return switch (section) {
    ProfileSection.overview => Icons.dashboard_outlined,
    ProfileSection.profile => Icons.person_outline_rounded,
    ProfileSection.security => Icons.lock_outline_rounded,
  };
}

String _dateOf(DateTime? value) {
  return value == null
      ? '--'
      : DateFormat('yyyy.MM.dd').format(value.toLocal());
}

abstract final class ProfileColors {
  static const canvas = Color(0xFFF7F6F2);
  static const field = Color(0xFFFCFCFB);
  static const ink = Color(0xFF171717);
  static const muted = Color(0xFF777570);
  static const placeholder = Color(0xFFA7A49D);
  static const line = Color(0xFFE5E3DE);
  static const sand = Color(0xFFEAE8E1);
}
