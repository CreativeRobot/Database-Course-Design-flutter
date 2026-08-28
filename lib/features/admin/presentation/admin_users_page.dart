import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import 'admin_page.dart';
import 'admin_providers.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _keywordController = TextEditingController();
  String _keyword = '';
  int? _status;
  String? _role;
  int _page = 1;
  final Set<int> _pendingIds = <int>{};

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  AdminUserFilter get _filter => (
        keyword: _keyword,
        status: _status,
        role: _role,
        page: _page,
      );

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminUsersProvider(_filter));
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          AdminPanel(
            child: AdminAsync(
              value: value,
              retry: _refresh,
              data: (page) => page.records.isEmpty
                  ? const _EmptyUsers()
                  : AdminWideTable(
                      minWidth: 980,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AdminColors.canvas,
                        ),
                        columns: const [
                          DataColumn(label: Text('用户')),
                          DataColumn(label: Text('联系方式')),
                          DataColumn(label: Text('角色')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('注册时间')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: [
                          for (final user in page.records)
                            DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 170,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.username,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (user.nickname.isNotEmpty)
                                          Text(
                                            user.nickname,
                                            style: const TextStyle(
                                              color: AdminColors.muted,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 210,
                                    child: Text(
                                      _contactOf(user),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(user.roleLabel)),
                                DataCell(_StatusChip(user: user)),
                                DataCell(Text(_formatDate(user.createTime))),
                                DataCell(
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      TextButton(
                                        onPressed: () => _showDetails(user),
                                        child: const Text('详情'),
                                      ),
                                      if (user.role != 'ADMIN')
                                        TextButton(
                                          onPressed: _pendingIds.contains(user.id)
                                              ? null
                                              : () => _toggleStatus(user),
                                          child: Text(
                                            user.isActive ? '停用' : '启用',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          value.when(
            data: (page) => AdminPagination(
              page: page,
              onPage: (pageNumber) => setState(() => _page = pageNumber),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            '用户管理',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(
            width: 250,
            child: TextField(
              controller: _keywordController,
              onSubmitted: (_) => _applyKeyword(),
              decoration: const InputDecoration(
                hintText: '搜索用户名、昵称、邮箱或手机号',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          DropdownButton<int?>(
            value: _status,
            hint: const Text('全部状态'),
            items: const [
              DropdownMenuItem<int?>(value: null, child: Text('全部状态')),
              DropdownMenuItem<int?>(value: 1, child: Text('正常')),
              DropdownMenuItem<int?>(value: 0, child: Text('已停用')),
            ],
            onChanged: (value) => setState(() {
              _status = value;
              _page = 1;
            }),
          ),
          DropdownButton<String?>(
            value: _role,
            hint: const Text('全部角色'),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('全部角色')),
              DropdownMenuItem<String?>(value: 'CUSTOMER', child: Text('普通用户')),
              DropdownMenuItem<String?>(value: 'ADMIN', child: Text('管理员')),
            ],
            onChanged: (value) => setState(() {
              _role = value;
              _page = 1;
            }),
          ),
          OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh),
            label: const Text('重置'),
          ),
        ],
      );

  void _applyKeyword() => setState(() {
        _keyword = _keywordController.text.trim();
        _page = 1;
      });

  void _resetFilters() {
    _keywordController.clear();
    setState(() {
      _keyword = '';
      _status = null;
      _role = null;
      _page = 1;
    });
  }

  void _refresh() => ref.invalidate(adminUsersProvider(_filter));

  Future<void> _toggleStatus(AdminUser user) async {
    final nextStatus = user.isActive ? 0 : 1;
    final confirmed = await confirmAdminAction(
      context,
      title: user.isActive ? '停用用户' : '启用用户',
      message: user.isActive
          ? '停用后该用户将无法继续使用需要登录的功能，确定继续吗？'
          : '确定恢复该用户的登录和购物权限吗？',
    );
    if (!confirmed || !mounted) return;

    setState(() => _pendingIds.add(user.id));
    try {
      await ref.read(adminRepositoryProvider).setUserStatus(user.id, nextStatus);
      if (!mounted) return;
      showAdminMessage(context, nextStatus == 1 ? '用户已启用' : '用户已停用');
      ref.invalidate(adminUsersProvider(_filter));
    } catch (error) {
      if (mounted) showAdminError(context, error);
    } finally {
      if (mounted) setState(() => _pendingIds.remove(user.id));
    }
  }

  Future<void> _showDetails(AdminUser user) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(user.username),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('昵称', user.nickname),
                _detail('邮箱', user.email),
                _detail('手机号', user.phone),
                _detail('角色', user.roleLabel),
                _detail('状态', user.statusLabel),
                _detail('注册时间', _formatDate(user.createTime)),
                _detail('更新时间', _formatDate(user.updateTime)),
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
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              child: Text(label, style: const TextStyle(color: AdminColors.muted)),
            ),
            Expanded(child: Text(value.isEmpty ? '未填写' : value)),
          ],
        ),
      );

  String _contactOf(AdminUser user) {
    final values = [user.email, user.phone].where((value) => value.isNotEmpty);
    return values.isEmpty ? '未填写' : values.join('\n');
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: user.isActive
              ? AdminColors.green.withValues(alpha: .1)
              : AdminColors.red.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          user.statusLabel,
          style: TextStyle(
            color: user.isActive ? AdminColors.green : AdminColors.red,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 180,
        child: Center(child: Text('暂无用户')),
      );
}
