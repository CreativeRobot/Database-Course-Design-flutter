import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/media_url.dart';
import '../../../data/models/profile/user_address.dart';
import '../../../data/models/profile/user_profile.dart';
import '../../../data/models/auth/security_question.dart';
import '../../../data/models/auth/security_question_catalog.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/commerce_widgets.dart';
import '../../community/data/community_models.dart';
import '../../community/presentation/community_controller.dart';
import '../../community/presentation/community_widgets.dart';
import '../../orders/data/order_models.dart';
import '../../orders/presentation/orders_controller.dart';
import '../../orders/presentation/orders_page.dart';
import 'profile_controller.dart';

String addressFieldValue({String? existing, String? fallback}) {
  final current = existing?.trim() ?? '';
  if (current.isNotEmpty) {
    return current;
  }
  return fallback?.trim() ?? '';
}

final myCommunityPostsProvider =
    FutureProvider.autoDispose<List<CommunityPost>>((ref) async {
      final result = await ref
          .watch(communityRepositoryProvider)
          .listMyPosts(size: 50);
      return result.records;
    });

enum ProfileSection { overview, orders, posts, security }

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
        message: state.errorMessage ?? '用户中心暂时无法加载',
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
              addresses: state.addresses,
              busyAddressId: state.busyAddressId,
              shippedOrders: shippedOrders,
              submitting: state.submitting,
              onEditNickname: _saveNickname,
              onEditEmail: _saveEmail,
              onEditPhone: _savePhone,
              onManageAddresses: _manageAddresses,
              onAddAddress: () => _editAddress(),
              onEditAddress: _editAddress,
              onSetDefaultAddress: _setDefaultAddress,
              onDeleteAddress: _deleteAddress,
              onRetryShippedOrders: () => ref.invalidate(shippedOrdersProvider),
            ),
            ProfileSection.orders => OrdersContent(embedded: true),
            ProfileSection.posts => const _MyPostsSection(),
            ProfileSection.security => _SecuritySection(
              submitting: state.submitting,
              onChangePassword: _changePassword,
              securityConfigured: profile.securityQuestionsConfigured,
              onManageSecurityQuestions: _manageSecurityQuestions,
            ),
          },
        ),
      ),
    );
  }

  void _selectSection(ProfileSection section) {
    setState(() => _section = section);
  }

  Future<bool> _saveNickname(String nickname) async {
    final profile = ref.read(profileControllerProvider).profile;
    if (profile == null) {
      return false;
    }
    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(
          nickname: nickname,
          email: profile.email,
          phone: profile.phone,
        );
    if (success && mounted) {
      _showSuccess('昵称已保存');
    }
    return success;
  }

  Future<bool> _saveEmail(String email) async {
    final profile = ref.read(profileControllerProvider).profile;
    if (profile == null) {
      return false;
    }
    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(
          nickname: profile.nickname,
          email: email,
          phone: profile.phone,
        );
    if (success && mounted) {
      _showSuccess('邮箱已保存');
    }
    return success;
  }

  Future<bool> _savePhone(String phone) async {
    final profile = ref.read(profileControllerProvider).profile;
    if (profile == null) {
      return false;
    }
    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(
          nickname: profile.nickname,
          email: profile.email,
          phone: phone,
        );
    if (success && mounted) {
      _showSuccess('手机号已保存');
    }
    return success;
  }

  Future<void> _manageAddresses() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _AddressManagementDialog(
        onAdd: () => _editAddress(),
        onEdit: _editAddress,
        onSetDefault: _setDefaultAddress,
        onDelete: _deleteAddress,
      ),
    );
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
      _showSuccess('密码已修改');
    }
    return success;
  }

  Future<void> _editAddress([UserAddress? address]) async {
    final input = await showDialog<UserAddressInput>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddressDialog(
        address: address,
        profile: ref.read(profileControllerProvider).profile,
      ),
    );
    if (input == null) {
      return;
    }
    final success = await ref
        .read(profileControllerProvider.notifier)
        .saveAddress(input: input, addressId: address?.id);
    if (success && mounted) {
      _showSuccess(address == null ? '收货地址已添加' : '收货地址已更新');
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
      _showSuccess('默认收货地址已更新');
    }
  }

  Future<void> _deleteAddress(UserAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收货地址'),
        content: Text('确定删除 ${address.receiverName} 的收货地址吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
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
      _showSuccess('收货地址已删除');
    }
  }

  Future<void> _manageSecurityQuestions() async {
    final result = await showDialog<List<SecurityAnswer>>(
      context: context,
      builder: (_) => _SecurityQuestionsDialog(),
    );
    if (result == null || !mounted) return;
    final success = await ref
        .read(profileControllerProvider.notifier)
        .updateSecurityQuestions(questions: result);
    if (success && mounted) _showSuccess('密保问题已保存');
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
          const _SidebarLabel('我的账户'),
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
            label: '返回书店',
            onPressed: () => context.go('/books'),
          ),
          _SidebarCommand(
            icon: Icons.logout_rounded,
            label: '退出登录',
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
            tooltip: '返回书店',
            onPressed: () => context.go('/books'),
            icon: const Icon(Icons.storefront_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: '账户菜单',
            onSelected: (value) {
              if (value == 'logout') {
                onLogout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('退出登录')),
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
    required this.addresses,
    required this.busyAddressId,
    required this.shippedOrders,
    required this.submitting,
    required this.onEditNickname,
    required this.onEditEmail,
    required this.onEditPhone,
    required this.onManageAddresses,
    required this.onAddAddress,
    required this.onEditAddress,
    required this.onSetDefaultAddress,
    required this.onDeleteAddress,
    required this.onRetryShippedOrders,
  });

  final UserProfile profile;
  final String? avatarUrl;
  final UserAddress? defaultAddress;
  final List<UserAddress> addresses;
  final int? busyAddressId;
  final AsyncValue<List<BookOrder>> shippedOrders;
  final bool submitting;
  final Future<bool> Function(String nickname) onEditNickname;
  final Future<bool> Function(String email) onEditEmail;
  final Future<bool> Function(String phone) onEditPhone;
  final VoidCallback onManageAddresses;
  final VoidCallback onAddAddress;
  final ValueChanged<UserAddress> onEditAddress;
  final ValueChanged<UserAddress> onSetDefaultAddress;
  final ValueChanged<UserAddress> onDeleteAddress;
  final VoidCallback onRetryShippedOrders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          eyebrow: 'OVERVIEW  ·  账户概览',
          title: '个人中心',
          subtitle: '查看默认收货地址、发货进度和账户状态。',
        ),
        const SizedBox(height: 34),
        _AccountHero(
          profile: profile,
          avatarUrl: avatarUrl,
          submitting: submitting,
          onEditNickname: onEditNickname,
          onEditEmail: onEditEmail,
          onEditPhone: onEditPhone,
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
                  label: '默认地址',
                  value: defaultAddress == null
                      ? '未设置'
                      : defaultAddress!.receiverName,
                  detail: defaultAddress == null ? '请点击管理地址添加' : '下单时优先使用此地址',
                ),
                _MetricTile(
                  width: tileWidth,
                  icon: Icons.verified_user_outlined,
                  label: '账户状态',
                  value: profile.isEnabled ? '正常' : '停用',
                  detail: profile.isAdmin ? '管理员账户' : '普通用户',
                ),
                _MetricTile(
                  width: tileWidth,
                  icon: Icons.calendar_today_outlined,
                  label: '加入书店',
                  value: _dateOf(profile.createTime),
                  detail: '阅读档案持续记录中',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _DefaultAddressPanel(
          address: defaultAddress,
          onManageAddresses: onManageAddresses,
        ),
        const SizedBox(height: 38),
        _ShippingOrdersPanel(
          orders: shippedOrders,
          onRetry: onRetryShippedOrders,
        ),
      ],
    );
  }
}

enum _AccountField { nickname, email, phone }

class _AccountHero extends StatefulWidget {
  const _AccountHero({
    required this.profile,
    required this.avatarUrl,
    required this.submitting,
    required this.onEditNickname,
    required this.onEditEmail,
    required this.onEditPhone,
  });

  final UserProfile profile;
  final String? avatarUrl;
  final bool submitting;
  final Future<bool> Function(String nickname) onEditNickname;
  final Future<bool> Function(String email) onEditEmail;
  final Future<bool> Function(String phone) onEditPhone;

  @override
  State<_AccountHero> createState() => _AccountHeroState();
}

class _AccountHeroState extends State<_AccountHero> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  _AccountField? _editingField;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.profile.nickname);
    _emailController = TextEditingController(text: widget.profile.email);
    _phoneController = TextEditingController(text: widget.profile.phone);
  }

  @override
  void didUpdateWidget(covariant _AccountHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editingField != _AccountField.nickname &&
        oldWidget.profile.nickname != widget.profile.nickname) {
      _nicknameController.text = widget.profile.nickname;
    }
    if (_editingField != _AccountField.email &&
        oldWidget.profile.email != widget.profile.email) {
      _emailController.text = widget.profile.email;
    }
    if (_editingField != _AccountField.phone &&
        oldWidget.profile.phone != widget.profile.phone) {
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

  Future<void> _save() async {
    final field = _editingField;
    if (field == null) {
      return;
    }

    final value = switch (field) {
      _AccountField.nickname => _nicknameController.text.trim(),
      _AccountField.email => _emailController.text.trim(),
      _AccountField.phone => _phoneController.text.trim(),
    };
    if (field == _AccountField.nickname && value.length > 30) {
      _showValidationMessage('昵称不能超过 30 个字符');
      return;
    }
    if (field == _AccountField.email &&
        (value.isEmpty || !value.contains('@'))) {
      _showValidationMessage('请输入有效的邮箱地址');
      return;
    }
    if (field == _AccountField.phone && value.isEmpty) {
      _showValidationMessage('手机号不能为空');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final success = switch (field) {
      _AccountField.nickname => await widget.onEditNickname(value),
      _AccountField.email => await widget.onEditEmail(value),
      _AccountField.phone => await widget.onEditPhone(value),
    };
    if (success && mounted) {
      setState(() => _editingField = null);
    }
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _editableContact({
    required _AccountField field,
    required String label,
    required String value,
    required String emptyText,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    if (_editingField == field) {
      return SizedBox(
        width: 260,
        child: TextField(
          controller: controller,
          autofocus: true,
          enabled: !widget.submitting,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            suffixIcon: _saveSuffixIcon('保存$label'),
          ),
        ),
      );
    }

    final displayText = value.isEmpty ? emptyText : value;
    final contactText = label == '手机号' ? '$label $displayText' : displayText;
    return InkWell(
      onTap: widget.submitting
          ? null
          : () => setState(() => _editingField = field),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              contactText,
              style: const TextStyle(color: ProfileColors.muted, fontSize: 13),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.edit_outlined,
              size: 14,
              color: ProfileColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveSuffixIcon(String tooltip) {
    if (widget.submitting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: _save,
      icon: const Icon(Icons.check_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editingNickname = _editingField == _AccountField.nickname;
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
            name: widget.profile.displayName,
            imageUrl: widget.avatarUrl,
            size: 64,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (editingNickname)
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _nicknameController,
                      autofocus: true,
                      maxLength: 30,
                      enabled: !widget.submitting,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        labelText: '昵称',
                        suffixIcon: _saveSuffixIcon('保存昵称'),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: widget.submitting
                        ? null
                        : () => setState(
                            () => _editingField = _AccountField.nickname,
                          ),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.profile.displayName,
                            style: const TextStyle(
                              color: ProfileColors.ink,
                              fontFamily: 'serif',
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.edit_outlined,
                            size: 17,
                            color: ProfileColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '@${widget.profile.username}',
                      style: const TextStyle(
                        color: ProfileColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    _editableContact(
                      field: _AccountField.email,
                      label: '邮箱',
                      value: widget.profile.email,
                      emptyText: '未填写邮箱',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _editableContact(
                      field: _AccountField.phone,
                      label: '手机号',
                      value: widget.profile.phone,
                      emptyText: '手机号 未填写',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ],
            ),
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
  const _DefaultAddressPanel({
    required this.address,
    required this.onManageAddresses,
  });

  final UserAddress? address;
  final VoidCallback onManageAddresses;

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
                  '默认收货地址',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  address == null
                      ? '还没有收货地址，下单前记得添加。'
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
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onManageAddresses,
            icon: const Icon(Icons.settings_outlined, size: 17),
            label: const Text('管理地址'),
          ),
        ],
      ),
    );
  }
}

class _AddressManagementDialog extends ConsumerWidget {
  const _AddressManagementDialog({
    required this.onAdd,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  final VoidCallback onAdd;
  final ValueChanged<UserAddress> onEdit;
  final ValueChanged<UserAddress> onSetDefault;
  final ValueChanged<UserAddress> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final addresses = state.addresses;
    final busy = state.busyAddressId;

    return AlertDialog(
      title: const Text('管理收货地址'),
      content: SizedBox(
        width: 520,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: addresses.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('暂无收货地址，请先添加一个。'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: addresses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    final disabled = busy != null;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        address.defaultAddress
                            ? Icons.check_circle
                            : Icons.location_on_outlined,
                        color: address.defaultAddress
                            ? ProfileColors.ink
                            : ProfileColors.muted,
                      ),
                      title: Text(
                        '${address.receiverName}  ${address.receiverPhone}',
                      ),
                      subtitle: Text(
                        address.fullAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        enabled: !disabled,
                        onSelected: (value) {
                          switch (value) {
                            case 'default':
                              onSetDefault(address);
                              break;
                            case 'edit':
                              onEdit(address);
                              break;
                            case 'delete':
                              onDelete(address);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          if (!address.defaultAddress)
                            const PopupMenuItem(
                              value: 'default',
                              child: Text('设为默认'),
                            ),
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: busy == null ? onAdd : null,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('新增地址'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
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
                  '正在发货',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '已出库的图书会在这里显示。',
              style: TextStyle(color: ProfileColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            if (shippedItems.isEmpty)
              const Text(
                '当前没有正在发货的图书。',
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
                                  '订单 ${entry.order.orderNo}  ·  数量 x${entry.item.quantity}',
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
              '正在发货的图书暂时无法加载。',
              style: TextStyle(color: ProfileColors.muted),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );
}

class _MyPostsSection extends ConsumerWidget {
  const _MyPostsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(myCommunityPostsProvider);
    final baseUrl = ref.watch(appConfigProvider).baseUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '我的帖子',
          style: TextStyle(
            color: ProfileColors.ink,
            fontFamily: 'serif',
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '查看你在图书社区发布的全部讨论。',
          style: TextStyle(color: ProfileColors.muted),
        ),
        const SizedBox(height: 24),
        posts.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _MyPostsFeedback(
            icon: Icons.cloud_off_outlined,
            message: error is ApiException && error.message.isNotEmpty
                ? error.message
                : '我的帖子暂时无法加载',
            actionLabel: '重新加载',
            onAction: () => ref.invalidate(myCommunityPostsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _MyPostsFeedback(
                icon: Icons.forum_outlined,
                message: '你还没有发布过帖子，去社区分享一本喜欢的书吧。',
                actionLabel: '前往社区',
                onAction: () => context.go(AppRoutePaths.community),
              );
            }
            return Column(
              children: [
                for (final post in items) ...[
                  if (post.status != 1)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5E7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '该帖子已被屏蔽，仅你自己可见。',
                        style: TextStyle(color: ProfileColors.muted),
                      ),
                    ),
                  CommunityPostCard(
                    post: post,
                    baseUrl: baseUrl,
                    onTap: () =>
                        context.go(AppRoutePaths.communityPost(post.id)),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MyPostsFeedback extends StatelessWidget {
  const _MyPostsFeedback({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ProfileColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: ProfileColors.muted, size: 34),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ProfileColors.muted),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel),
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
    required this.securityConfigured,
    required this.onManageSecurityQuestions,
  });

  final bool submitting;
  final Future<bool> Function({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  })
  onChangePassword;
  final bool securityConfigured;
  final VoidCallback onManageSecurityQuestions;

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
          eyebrow: 'SECURITY  ·  账户安全',
          title: '修改密码',
          subtitle: '定期更换密码，保持账户和订单信息安全。',
        ),
        const SizedBox(height: 34),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              widget.securityConfigured
                  ? Icons.verified_user_outlined
                  : Icons.warning_amber_outlined,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.securityConfigured
                    ? '已设置 3 个密保问题'
                    : '尚未设置密保问题；未设置时无法修改或找回密码',
                style: const TextStyle(
                  color: ProfileColors.muted,
                  fontSize: 13,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: widget.onManageSecurityQuestions,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: Text(widget.securityConfigured ? '修改密保' : '设置密保'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _FormSurface(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PasswordField(
                  controller: _oldPasswordController,
                  label: '当前密码',
                  visible: _showOldPassword,
                  onToggle: () =>
                      setState(() => _showOldPassword = !_showOldPassword),
                  validator: (value) =>
                      (value ?? '').isEmpty ? '请输入当前密码' : null,
                ),
                const SizedBox(height: 20),
                _PasswordField(
                  controller: _newPasswordController,
                  label: '新密码',
                  visible: _showNewPassword,
                  onToggle: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                  validator: (value) =>
                      (value ?? '').length < 6 ? '新密码至少需要 6 个字符' : null,
                ),
                const SizedBox(height: 20),
                _PasswordField(
                  controller: _confirmPasswordController,
                  label: '确认新密码',
                  visible: _showConfirmPassword,
                  onToggle: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                  validator: (value) => value != _newPasswordController.text
                      ? '两次输入的新密码不一致'
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
                    label: Text(widget.submitting ? '正在提交' : '更新密码'),
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
              '新密码建议同时包含字母、数字和符号，不要与其他网站共用。',
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
  const _AddressDialog({this.address, this.profile});

  final UserAddress? address;
  final UserProfile? profile;

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
    final profile = widget.profile;
    _nameController = TextEditingController(
      text: addressFieldValue(
        existing: address?.receiverName,
        fallback: profile?.displayName,
      ),
    );
    _phoneController = TextEditingController(
      text: addressFieldValue(
        existing: address?.receiverPhone,
        fallback: profile?.phone,
      ),
    );
    _provinceController = TextEditingController(
      text: addressFieldValue(existing: address?.province),
    );
    _cityController = TextEditingController(
      text: addressFieldValue(existing: address?.city),
    );
    _districtController = TextEditingController(
      text: addressFieldValue(existing: address?.district),
    );
    _detailController = TextEditingController(
      text: addressFieldValue(existing: address?.detailAddress),
    );
    _postalCodeController = TextEditingController(
      text: addressFieldValue(existing: address?.postalCode),
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
                            widget.address == null ? '新增收货地址' : '编辑收货地址',
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '请填写完整信息，编辑时将整体更新地址。',
                            style: TextStyle(
                              color: ProfileColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
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
                        label: '收货人',
                        hintText: '输入收货人姓名',
                        icon: Icons.person_outline,
                        validator: _required('请输入收货人'),
                      ),
                      _ProfileTextField(
                        controller: _phoneController,
                        label: '联系电话',
                        hintText: '输入收货电话',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: _required('请输入联系电话'),
                      ),
                      _ProfileTextField(
                        controller: _provinceController,
                        label: '省份',
                        hintText: '例如：广东省',
                        icon: Icons.map_outlined,
                        validator: _required('请输入省份'),
                      ),
                      _ProfileTextField(
                        controller: _cityController,
                        label: '城市',
                        hintText: '例如：深圳市',
                        icon: Icons.location_city_outlined,
                        validator: _required('请输入城市'),
                      ),
                      _ProfileTextField(
                        controller: _districtController,
                        label: '区 / 县',
                        hintText: '例如：南山区（可选）',
                        icon: Icons.place_outlined,
                      ),
                      _ProfileTextField(
                        controller: _postalCodeController,
                        label: '邮政编码',
                        hintText: '例如：518000（可选）',
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
                  label: '详细地址',
                  hintText: '街道、楼栋、门牌号',
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  validator: _required('请输入详细地址'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _defaultAddress,
                  onChanged: (value) {
                    setState(() => _defaultAddress = value);
                  },
                  title: const Text(
                    '设为默认收货地址',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    '下单时优先选中这个地址',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('保存地址'),
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
  });

  final String eyebrow;
  final String title;
  final String subtitle;

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
    return text;
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
            hintText: '请输入$label',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              tooltip: visible ? '隐藏密码' : '显示密码',
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
        text.isEmpty ? '读' : text.substring(0, 1),
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
          Text('正在整理你的账户资料', style: TextStyle(color: ProfileColors.muted)),
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
              label: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}

String _sectionLabel(ProfileSection section) {
  return switch (section) {
    ProfileSection.overview => '账户概览',
    ProfileSection.orders => '我的订单',
    ProfileSection.posts => '我的帖子',
    ProfileSection.security => '账户安全',
  };
}

IconData _sectionIcon(ProfileSection section) {
  return switch (section) {
    ProfileSection.overview => Icons.dashboard_outlined,
    ProfileSection.orders => Icons.receipt_long_outlined,
    ProfileSection.posts => Icons.forum_outlined,
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

class _SecurityQuestionsDialog extends StatefulWidget {
  const _SecurityQuestionsDialog({this.initialQuestions = const []});

  final List<SecurityQuestion> initialQuestions;
  @override
  State<_SecurityQuestionsDialog> createState() =>
      _SecurityQuestionsDialogState();
}

class _SecurityQuestionsDialogState extends State<_SecurityQuestionsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<String> _keys;

  @override
  void initState() {
    super.initState();
    _keys = widget.initialQuestions.length == 3
        ? widget.initialQuestions.map((item) => item.key).toList()
        : ['Q1', 'Q2', 'Q3'];
  }

  final _answers = List.generate(3, (_) => TextEditingController());

  @override
  void dispose() {
    for (final controller in _answers) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('设置密保问题'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (var index = 0; index < 3; index++) ...[
                DropdownButtonFormField<String>(
                  value: _keys[index],
                  decoration: InputDecoration(labelText: '问题 ${index + 1}'),
                  items: securityQuestionCatalog
                      .map(
                        (q) => DropdownMenuItem(
                          value: q.key,
                          child: Text(q.question),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _keys[index] = value!),
                  validator: (v) => v == null ? '请选择问题' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _answers[index],
                  decoration: const InputDecoration(labelText: '答案'),
                  validator: (v) => (v ?? '').trim().isEmpty ? '请输入答案' : null,
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate() || _keys.toSet().length != 3)
            return;
          Navigator.pop(context, [
            for (var i = 0; i < 3; i++)
              SecurityAnswer(
                questionKey: _keys[i],
                answer: _answers[i].text.trim(),
              ),
          ]);
        },
        child: const Text('保存'),
      ),
    ],
  );
}
