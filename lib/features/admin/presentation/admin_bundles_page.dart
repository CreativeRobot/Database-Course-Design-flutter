import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book/book.dart';
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
      await ref
          .read(bundleRepositoryProvider)
          .changeStatus(bundle.id, active ? 'INACTIVE' : 'ACTIVE');
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
                Text(
                  bundle.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (bundle.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    bundle.description!,
                    style: const TextStyle(color: AdminColors.muted),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  bundle.items
                      .map(
                        (item) => item.isbn.isEmpty
                            ? item.title
                            : '${item.title}（ISBN ${item.isbn}）',
                      )
                      .join('  /  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${bundle.bundlePrice.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '省 ¥${bundle.savings.toStringAsFixed(2)}',
                style: const TextStyle(color: AdminColors.green, fontSize: 12),
              ),
              const SizedBox(height: 5),
              Text(
                purchasable ? '当前可购买' : (bundle.unavailableReason ?? '当前不可购买'),
                style: TextStyle(
                  color: purchasable ? AdminColors.green : AdminColors.red,
                  fontSize: 11,
                ),
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
  const _BundleFormResult({
    required this.name,
    required this.description,
    required this.bundlePrice,
    required this.bookIds,
  });

  final String name;
  final String? description;
  final double bundlePrice;
  final List<int> bookIds;
}

class _BundleBookOption {
  const _BundleBookOption({
    required this.id,
    required this.title,
    required this.isbn,
    this.status,
  });

  factory _BundleBookOption.fromBook(Book book) => _BundleBookOption(
    id: book.id,
    title: book.title,
    isbn: book.isbn,
    status: book.status,
  );

  factory _BundleBookOption.fromBundleItem(BundleItem item) =>
      _BundleBookOption(id: item.bookId, title: item.title, isbn: item.isbn);

  final int id;
  final String title;
  final String isbn;
  final String? status;
}

class _BundleFormDialog extends ConsumerStatefulWidget {
  const _BundleFormDialog({this.bundle});

  final BookBundle? bundle;

  @override
  ConsumerState<_BundleFormDialog> createState() => _BundleFormDialogState();
}

class _BundleFormDialogState extends ConsumerState<_BundleFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  final TextEditingController _bookSearch = TextEditingController();
  late final List<_BundleBookOption> _selectedBooks;
  List<_BundleBookOption> _searchResults = const [];
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    final bundle = widget.bundle;
    _name = TextEditingController(text: bundle?.name ?? '');
    _description = TextEditingController(text: bundle?.description ?? '');
    _price = TextEditingController(text: bundle?.bundlePrice.toString() ?? '');
    _selectedBooks =
        bundle?.items
            .map(_BundleBookOption.fromBundleItem)
            .toList(growable: true) ??
        <_BundleBookOption>[];
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _bookSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.bundle == null ? '新增组合包' : '编辑组合包'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '组合包名称'),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: '说明（可选）'),
              ),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '固定组合价'),
              ),
              const SizedBox(height: 18),
              Text(
                '已选择 ${_selectedBooks.length}/10 本',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_selectedBooks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '请搜索并添加 2～10 本图书',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              else
                ..._selectedBooks.map(
                  (book) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(book.title),
                    subtitle: book.isbn.isEmpty
                        ? null
                        : Text('ISBN ${book.isbn}'),
                    trailing: IconButton(
                      tooltip: '移除${book.title}',
                      onPressed: () => _removeBook(book.id),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bookSearch,
                      decoration: const InputDecoration(
                        labelText: '按图书名称搜索',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _searchBooks(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _searching ? null : _searchBooks,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: const Text('搜索图书'),
                  ),
                ],
              ),
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _searchError!,
                    style: const TextStyle(color: AdminColors.red),
                  ),
                ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._searchResults.map((book) {
                  final selected = _selectedBooks.any(
                    (item) => item.id == book.id,
                  );
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(book.title),
                    subtitle: Text(
                      [
                        if (book.isbn.isNotEmpty) 'ISBN ${book.isbn}',
                        if (book.status != null) _bookStatusLabel(book.status!),
                      ].join(' · '),
                    ),
                    trailing: TextButton.icon(
                      onPressed: selected || _selectedBooks.length >= 10
                          ? null
                          : () => _addBook(book),
                      icon: Icon(selected ? Icons.check : Icons.add),
                      label: Text(selected ? '已添加' : '添加'),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }

  Future<void> _searchBooks() async {
    final keyword = _bookSearch.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = const [];
        _searchError = '请输入图书名称';
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final response = await ref
          .read(adminRepositoryProvider)
          .books(keyword: keyword, page: 1, size: 10);
      if (!mounted) return;
      setState(() {
        _searchResults = response.records
            .map(_BundleBookOption.fromBook)
            .toList(growable: false);
        if (_searchResults.isEmpty) {
          _searchError = '未找到名称包含“$keyword”的图书';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _searchError = '搜索失败：$error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addBook(_BundleBookOption book) {
    if (_selectedBooks.length >= 10 ||
        _selectedBooks.any((item) => item.id == book.id)) {
      return;
    }
    setState(() => _selectedBooks.add(book));
  }

  void _removeBook(int bookId) {
    setState(() => _selectedBooks.removeWhere((book) => book.id == bookId));
  }

  void _submit() {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    if (name.isEmpty ||
        price == null ||
        price <= 0 ||
        _selectedBooks.length < 2 ||
        _selectedBooks.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写名称、有效组合价，并选择 2～10 本不同图书')),
      );
      return;
    }
    Navigator.pop(
      context,
      _BundleFormResult(
        name: name,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        bundlePrice: price,
        bookIds: _selectedBooks.map((book) => book.id).toList(growable: false),
      ),
    );
  }
}

String _bookStatusLabel(String status) => switch (status) {
  'ON_SALE' => '在售',
  'OFF_SALE' => '下架',
  'SOLD_OUT' => '售罄',
  _ => status,
};
