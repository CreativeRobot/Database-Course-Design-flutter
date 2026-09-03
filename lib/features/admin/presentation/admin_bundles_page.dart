import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/data/bundle_models.dart';
import 'admin_page.dart';
import 'admin_providers.dart';

class AdminBundlesPage extends ConsumerWidget {
  const AdminBundlesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundles = ref.watch(adminBundlesProvider);
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '组合包管理',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('新增组合包'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '配置 2～10 本图书的固定组合价；系统会根据最新售价自动判断是否仍可购买。',
            style: TextStyle(color: AdminColors.muted),
          ),
          const SizedBox(height: 18),
          AdminPanel(
            child: AdminAsync<List<BookBundle>>(
              value: bundles,
              retry: () => ref.invalidate(adminBundlesProvider),
              data: (records) => records.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: Text('暂无组合包')),
                    )
                  : Column(
                      children: [
                        for (final bundle in records)
                          _BundleRow(
                            bundle: bundle,
                            onEdit: () => _edit(context, ref, bundle),
                            onToggle: () => _toggle(context, ref, bundle),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    BookBundle? bundle,
  ]) async {
    final result = await showDialog<_BundleFormResult>(
      context: context,
      builder: (_) => _BundleFormDialog(bundle: bundle),
    );
    if (result == null) return;
    final repository = ref.read(bundleRepositoryProvider);
    try {
      if (bundle == null) {
        await repository.create(
          name: result.name,
          description: result.description,
          bundlePrice: result.bundlePrice,
          bookIds: result.bookIds,
        );
      } else {
        await repository.update(
          bundle.id,
          name: result.name,
          description: result.description,
          bundlePrice: result.bundlePrice,
          bookIds: result.bookIds,
          version: bundle.version ?? 0,
        );
      }
      ref.invalidate(adminBundlesProvider);
      if (context.mounted) showAdminMessage(context, '组合包已保存');
    } catch (error) {
      if (context.mounted) showAdminError(context, error);
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    BookBundle bundle,
  ) async {
    final active = bundle.status == 'ACTIVE';
    final confirmed = await confirmAdminAction(
      context,
      title: active ? '停用组合包' : '启用组合包',
      message: '确定${active ? '停用' : '启用'}“${bundle.name}”吗？',
    );
    if (!confirmed) return;
    try {
      await ref.read(bundleRepositoryProvider).changeStatus(
            bundle.id,
            active ? 'INACTIVE' : 'ACTIVE',
          );
      ref.invalidate(adminBundlesProvider);
      if (context.mounted) showAdminMessage(context, '状态已更新');
    } catch (error) {
      if (context.mounted) showAdminError(context, error);
    }
  }
}

class _BundleRow extends StatelessWidget {
  const _BundleRow({
    required this.bundle,
    required this.onEdit,
    required this.onToggle,
  });

  final BookBundle bundle;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final active = bundle.status == 'ACTIVE';
    final purchasable = bundle.purchasable ?? bundle.priceValid ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bundle.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (bundle.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(bundle.description!, style: const TextStyle(color: AdminColors.muted)),
                ],
                const SizedBox(height: 8),
                Text(
                  bundle.items.map((item) => '${item.bookId} · ${item.title}').join('  /  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AdminColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('¥${bundle.bundlePrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('省 ¥${bundle.savings.toStringAsFixed(2)}', style: const TextStyle(color: AdminColors.green, fontSize: 12)),
              const SizedBox(height: 5),
              Text(
                purchasable ? '当前可购买' : (bundle.unavailableReason ?? '当前不可购买'),
                style: TextStyle(color: purchasable ? AdminColors.green : AdminColors.red, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'toggle') onToggle();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'toggle', child: Text(active ? '停用' : '启用')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BundleFormResult {
  const _BundleFormResult({required this.name, required this.description, required this.bundlePrice, required this.bookIds});
  final String name;
  final String? description;
  final double bundlePrice;
  final List<int> bookIds;
}

class _BundleFormDialog extends StatefulWidget {
  const _BundleFormDialog({this.bundle});
  final BookBundle? bundle;
  @override
  State<_BundleFormDialog> createState() => _BundleFormDialogState();
}

class _BundleFormDialogState extends State<_BundleFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _bookIds;

  @override
  void initState() {
    super.initState();
    final bundle = widget.bundle;
    _name = TextEditingController(text: bundle?.name ?? '');
    _description = TextEditingController(text: bundle?.description ?? '');
    _price = TextEditingController(text: bundle?.bundlePrice.toString() ?? '');
    _bookIds = TextEditingController(text: bundle?.items.map((item) => item.bookId).join(',') ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _bookIds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.bundle == null ? '新增组合包' : '编辑组合包'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: '组合包名称')),
              TextField(controller: _description, decoration: const InputDecoration(labelText: '说明（可选）')),
              TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '固定组合价')),
              TextField(controller: _bookIds, decoration: const InputDecoration(labelText: '图书 ID（逗号分隔，2～10 本）')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }

  void _submit() {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    final ids = _bookIds.text
        .split(RegExp(r'[,，\s]+'))
        .where((value) => value.isNotEmpty)
        .map(int.tryParse)
        .whereType<int>()
        .toSet()
        .toList();
    if (name.isEmpty || price == null || price <= 0 || ids.length < 2 || ids.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写名称、有效组合价，并输入 2～10 个不同图书 ID')));
      return;
    }
    Navigator.pop(
      context,
      _BundleFormResult(
        name: name,
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        bundlePrice: price,
        bookIds: ids,
      ),
    );
  }
}