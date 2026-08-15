import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/book_detail.dart';
import '../../../data/models/common/page_response.dart';
import '../../cart/presentation/commerce_widgets.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import 'admin_page.dart';
import 'admin_providers.dart';

class AdminBooksPage extends ConsumerStatefulWidget {
  const AdminBooksPage({super.key});
  @override
  ConsumerState<AdminBooksPage> createState() => _AdminBooksPageState();
}

class _AdminBooksPageState extends ConsumerState<AdminBooksPage> {
  String? _status;
  int _page = 1;
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminBooksProvider((status: _status, page: _page)));
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageActions(
            title: '图书管理',
            actionLabel: '新增图书',
            onAdd: () => _edit(),
            trailing: DropdownButton<String?>(
              value: _status,
              hint: const Text('全部状态'),
              items: const [
                DropdownMenuItem(value: null, child: Text('全部状态')),
                DropdownMenuItem(value: 'ON_SALE', child: Text('在售')),
                DropdownMenuItem(value: 'OFF_SALE', child: Text('下架')),
              ],
              onChanged: (value) => setState(() => _status = value),
            ),
          ),
          const SizedBox(height: 16),
          AdminPanel(
            child: AdminAsync(
              value: value,
              retry: _refresh,
              data: (page) => page.records.isEmpty
                  ? const _Empty(text: '暂无图书')
                  : AdminWideTable(
                      child: Column(
                        children: [
                          for (final book in page.records)
                            _BookRow(
                              book: book,
                              onEdit: () => _edit(book),
                              onStatus: () => _statusBook(book),
                              onStock: () => _stock(book),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          value.when(data: (page) => AdminPagination(page: page, onPage: (p) => setState(() => _page = p)), loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink()),
        ],
      ),
    );
  }

  void _refresh() => ref.invalidate(adminBooksProvider((status: _status, page: _page)));

  Future<void> _edit([Book? book]) async {
    final repo = ref.read(adminRepositoryProvider);
    try {
      final results = await Future.wait<Object>([
        repo.authors(),
        repo.publishers(),
        repo.categories(),
        if (book != null) repo.book(book.id),
      ]);
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BookDialog(
          repository: repo,
          authors: (results[0] as PageResponse<AdminAuthor>).records,
          publishers: (results[1] as PageResponse<AdminPublisher>).records,
          categories: results[2] as List<AdminCategory>,
          book: book == null ? null : results[3] as BookDetail,
        ),
      );
      if (saved == true) {
        _refresh();
        if (mounted)
          showAdminMessage(context, book == null ? '图书已新增' : '图书已更新');
      }
    } catch (error) {
      if (mounted) showAdminMessage(context, error.toString());
    }
  }

  Future<void> _statusBook(Book book) async {
    final next = book.status == 'ON_SALE' ? 'OFF_SALE' : 'ON_SALE';
    if (!await confirmAdminAction(
      context,
      title: next == 'ON_SALE' ? '上架图书' : '下架图书',
      message: '确定${next == 'ON_SALE' ? '上架' : '下架'}《${book.title}》吗？',
    ))
      return;
    try {
      await ref.read(adminRepositoryProvider).setBookStatus(book.id, next);
      _refresh();
    } catch (error) {
      if (mounted) showAdminMessage(context, error.toString());
    }
  }

  Future<void> _stock(Book book) async {
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _StockDialog(book: book),
    );
    if (result == null) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .adjustStock(book.id, result.$1, result.$2);
      _refresh();
      if (mounted) showAdminMessage(context, '库存已调整');
    } catch (error) {
      if (mounted) showAdminMessage(context, error.toString());
    }
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.onEdit,
    required this.onStatus,
    required this.onStock,
  });
  final Book book;
  final VoidCallback onEdit;
  final VoidCallback onStatus;
  final VoidCallback onStock;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AdminColors.line)),
    ),
    child: Row(
      children: [
        CommerceCover(url: book.coverUrl, width: 42),
        const SizedBox(width: 13),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'ISBN ${book.isbn} · ${book.publisherName}',
                style: const TextStyle(color: AdminColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(child: Text(money(book.salePrice))),
        SizedBox(width: 80, child: Text('库存 ${book.stock}')),
        _StateTag(active: book.status == 'ON_SALE', on: '在售', off: '下架'),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: '图书操作',
          onSelected: (value) => switch (value) {
            'edit' => onEdit(),
            'stock' => onStock(),
            _ => onStatus(),
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑图书')),
            const PopupMenuItem(value: 'stock', child: Text('调整库存')),
            PopupMenuItem(
              value: 'status',
              child: Text(book.status == 'ON_SALE' ? '下架' : '上架'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BookDialog extends StatefulWidget {
  const _BookDialog({
    required this.repository,
    required this.authors,
    required this.publishers,
    required this.categories,
    this.book,
  });
  final AdminRepository repository;
  final List<AdminAuthor> authors;
  final List<AdminPublisher> publishers;
  final List<AdminCategory> categories;
  final BookDetail? book;
  @override
  State<_BookDialog> createState() => _BookDialogState();
}

class _BookDialogState extends State<_BookDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late int? _publisherId;
  late Set<int> _authorIds;
  late Set<int> _categoryIds;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final book = widget.book;
    _publisherId = book?.publisherId == 0 ? null : book?.publisherId;
    _authorIds = book?.authors.map((e) => e.id).toSet() ?? {};
    _categoryIds = book?.categories.map((e) => e.id).toSet() ?? {};
    _fields = {
      'isbn': TextEditingController(text: book?.isbn),
      'title': TextEditingController(text: book?.title),
      'original': TextEditingController(
        text: book?.originalPrice.toStringAsFixed(2),
      ),
      'sale': TextEditingController(text: book?.salePrice.toStringAsFixed(2)),
      'stock': TextEditingController(
        text: book == null ? '0' : '${book.stock}',
      ),
      'date': TextEditingController(text: book?.publishDate),
      'edition': TextEditingController(text: book?.edition),
      'pages': TextEditingController(text: book?.pages?.toString()),
      'description': TextEditingController(text: book?.description),
      'cover': TextEditingController(text: book?.coverUrl),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.book == null ? '新增图书' : '编辑图书'),
    content: SizedBox(
      width: 760,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field('isbn', 'ISBN', required: true),
                  _field('title', '书名', required: true),
                  SizedBox(
                    width: 350,
                    child: DropdownButtonFormField<int>(
                      initialValue: _publisherId,
                      decoration: const InputDecoration(
                        labelText: '出版社',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.publishers
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _publisherId = value),
                      validator: (value) => value == null ? '请选择出版社' : null,
                    ),
                  ),
                  _field('original', '原价', required: true, number: true),
                  _field('sale', '售价', required: true, number: true),
                  if (widget.book == null)
                    _field('stock', '初始库存', number: true),
                  _field('date', '出版日期 YYYY-MM-DD'),
                  _field('edition', '版本'),
                  _field('pages', '页数', number: true),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '作者（至少选择一位）',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                children: widget.authors
                    .map(
                      (author) => FilterChip(
                        label: Text(author.name),
                        selected: _authorIds.contains(author.id),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _authorIds.add(author.id)
                              : _authorIds.remove(author.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              const Text('分类', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                children: widget.categories
                    .map(
                      (category) => FilterChip(
                        label: Text(category.name),
                        selected: _categoryIds.contains(category.id),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _categoryIds.add(category.id)
                              : _categoryIds.remove(category.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _fields['description'],
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '图书简介',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fields['cover'],
                      decoration: const InputDecoration(
                        labelText: '封面地址',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _upload,
                    icon: _uploading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file, size: 18),
                    label: const Text('上传封面'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AdminColors.red)),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? '保存中...' : '保存'),
      ),
    ],
  );

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool number = false,
  }) => SizedBox(
    width: 350,
    child: TextFormField(
      controller: _fields[key],
      keyboardType: number ? TextInputType.number : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty))
          return '请输入$label';
        if (number &&
            value != null &&
            value.isNotEmpty &&
            num.tryParse(value) == null)
          return '请输入有效数字';
        return null;
      },
    ),
  );

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final uploaded = await widget.repository.upload(file!.bytes!, file.name);
      _fields['cover']!.text = uploaded.url;
    } catch (error) {
        setState(() => _error = appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_authorIds.isEmpty) {
      setState(() => _error = '至少选择一位作者');
      return;
    }
    final original = double.parse(_fields['original']!.text);
    final sale = double.parse(_fields['sale']!.text);
    if (sale > original) {
      setState(() => _error = '售价不能高于原价');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'isbn': _fields['isbn']!.text.trim(),
      'title': _fields['title']!.text.trim(),
      'publisherId': _publisherId,
      'originalPrice': original,
      'salePrice': sale,
      if (widget.book == null)
        'stock': int.tryParse(_fields['stock']!.text) ?? 0,
      'publishDate': _nullText('date'),
      'edition': _nullText('edition'),
      'pages': int.tryParse(_fields['pages']!.text),
      'description': _nullText('description'),
      'coverUrl': _nullText('cover'),
      'authorIds': _authorIds.toList(),
      'categoryIds': _categoryIds.toList(),
    };
    try {
      await widget.repository.saveBook(data, id: widget.book?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      setState(() {
        _saving = false;
      _error = appErrorMessage(error);
      });
    }
  }

  String? _nullText(String key) {
    final value = _fields[key]!.text.trim();
    return value.isEmpty ? null : value;
  }
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.book});
  final Book book;
  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final amount = TextEditingController();
  final remark = TextEditingController();
  String? error;
  @override
  void dispose() {
    amount.dispose();
    remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('调整库存 · ${widget.book.title}'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('当前库存 ${widget.book.stock}；正数入库，负数出库。'),
          const SizedBox(height: 14),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '变动数量',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: remark,
            decoration: const InputDecoration(
              labelText: '备注',
              border: OutlineInputBorder(),
            ),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: AdminColors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final value = int.tryParse(amount.text);
          if (value == null || value == 0) {
            setState(() => error = '变动数量不能为 0');
            return;
          }
          Navigator.pop(context, (value, remark.text));
        },
        child: const Text('确认调整'),
      ),
    ],
  );
}

class AdminAuthorsPage extends ConsumerStatefulWidget {
  const AdminAuthorsPage({super.key});
  @override
  ConsumerState<AdminAuthorsPage> createState() => _AdminAuthorsPageState();
}

class _AdminAuthorsPageState extends ConsumerState<AdminAuthorsPage> {
  String keyword = '';
  int page = 1;
  @override
  Widget build(BuildContext context) => _SimpleEntityPage<AdminAuthor>(
    title: '作者管理',
    value: ref.watch(adminAuthorsProvider((keyword: keyword, page: page))),
    name: (e) => e.name,
    subtitle: (e) =>
        [e.country, e.introduction].where((e) => e.isNotEmpty).join(' · '),
    onSearch: (v) => setState(() { keyword = v; page = 1; }),
    onPage: (v) => setState(() => page = v),
    onRefresh: () => ref.invalidate(adminAuthorsProvider((keyword: keyword, page: page))),
    onEdit: _edit,
    onDelete: _delete,
  );
  Future<void> _edit([AdminAuthor? value]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AuthorDialog(value),
    );
    if (data == null) return;
    try {
      await ref.read(adminRepositoryProvider).saveAuthor(data, id: value?.id);
      ref.invalidate(adminAuthorsProvider((keyword: keyword, page: page)));
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }

  Future<void> _delete(AdminAuthor value) async {
    if (!await confirmAdminAction(
      context,
      title: '删除作者',
      message: '确定删除“${value.name}”吗？',
    ))
      return;
    try {
      await ref.read(adminRepositoryProvider).deleteAuthor(value.id);
      ref.invalidate(adminAuthorsProvider((keyword: keyword, page: page)));
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }
}

class AdminPublishersPage extends ConsumerStatefulWidget {
  const AdminPublishersPage({super.key});
  @override
  ConsumerState<AdminPublishersPage> createState() =>
      _AdminPublishersPageState();
}

class _AdminPublishersPageState extends ConsumerState<AdminPublishersPage> {
  String keyword = '';
  int page = 1;
  @override
  Widget build(BuildContext context) => _SimpleEntityPage<AdminPublisher>(
    title: '出版社管理',
    value: ref.watch(adminPublishersProvider((keyword: keyword, page: page))),
    name: (e) => e.name,
    subtitle: (e) =>
        [e.phone, e.address].where((e) => e.isNotEmpty).join(' · '),
    onSearch: (v) => setState(() { keyword = v; page = 1; }),
    onPage: (v) => setState(() => page = v),
    onRefresh: () => ref.invalidate(adminPublishersProvider((keyword: keyword, page: page))),
    onEdit: _edit,
    onDelete: _delete,
  );
  Future<void> _edit([AdminPublisher? value]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PublisherDialog(value),
    );
    if (data == null) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .savePublisher(data, id: value?.id);
      ref.invalidate(adminPublishersProvider((keyword: keyword, page: page)));
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }

  Future<void> _delete(AdminPublisher value) async {
    if (!await confirmAdminAction(
      context,
      title: '删除出版社',
      message: '确定删除“${value.name}”吗？',
    ))
      return;
    try {
      await ref.read(adminRepositoryProvider).deletePublisher(value.id);
      ref.invalidate(adminPublishersProvider((keyword: keyword, page: page)));
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }
}

class AdminCategoriesPage extends ConsumerStatefulWidget {
  const AdminCategoriesPage({super.key});
  @override
  ConsumerState<AdminCategoriesPage> createState() =>
      _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends ConsumerState<AdminCategoriesPage> {
  int? status;
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminCategoriesProvider(status));
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageActions(
            title: '分类管理',
            actionLabel: '新增分类',
            onAdd: () => _edit(),
            trailing: DropdownButton<int?>(
              value: status,
              items: const [
                DropdownMenuItem(value: null, child: Text('全部状态')),
                DropdownMenuItem(value: 1, child: Text('启用')),
                DropdownMenuItem(value: 0, child: Text('停用')),
              ],
              onChanged: (v) => setState(() => status = v),
            ),
          ),
          const SizedBox(height: 16),
          AdminPanel(
            child: AdminAsync(
              value: value,
              retry: _refresh,
              data: (items) => items.isEmpty
                  ? const _Empty(text: '暂无分类')
                  : Column(
                      children: items
                          .map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.folder_outlined),
                              title: Text(item.name),
                              subtitle: Text(
                                '上级：${item.parentName ?? '无'} · 排序 ${item.sortOrder}',
                              ),
                              trailing: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _StateTag(
                                    active: item.status == 1,
                                    on: '启用',
                                    off: '停用',
                                  ),
                                  IconButton(
                                    tooltip: '启停',
                                    onPressed: () => _toggle(item),
                                    icon: const Icon(Icons.power_settings_new),
                                  ),
                                  IconButton(
                                    tooltip: '编辑',
                                    onPressed: () => _edit(item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '删除',
                                    onPressed: () => _delete(item),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _refresh() => ref.invalidate(adminCategoriesProvider(status));
  Future<void> _edit([AdminCategory? item]) async {
    final all = await ref.read(adminRepositoryProvider).categories();
    if (!mounted) return;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CategoryDialog(item, all),
    );
    if (data == null) return;
    try {
      await ref.read(adminRepositoryProvider).saveCategory(data, id: item?.id);
      _refresh();
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }

  Future<void> _toggle(AdminCategory item) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .setCategoryStatus(item.id, item.status == 1 ? 0 : 1);
      _refresh();
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }

  Future<void> _delete(AdminCategory item) async {
    if (!await confirmAdminAction(
      context,
      title: '删除分类',
      message: '确定删除“${item.name}”吗？',
    ))
      return;
    try {
      await ref.read(adminRepositoryProvider).deleteCategory(item.id);
      _refresh();
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }
}

class _SimpleEntityPage<T> extends StatelessWidget {
  const _SimpleEntityPage({
    required this.title,
    required this.value,
    required this.name,
    required this.subtitle,
    required this.onSearch,
    required this.onPage,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });
  final String title;
  final AsyncValue<PageResponse<T>> value;
  final String Function(T) name;
  final String Function(T) subtitle;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onPage;
  final VoidCallback onRefresh;
  final void Function([T?]) onEdit;
  final ValueChanged<T> onDelete;
  @override
  Widget build(BuildContext context) => AdminPageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageActions(
          title: title,
          actionLabel: '新增',
          onAdd: () => onEdit(),
          trailing: SizedBox(
            width: 230,
            child: TextField(
              onSubmitted: onSearch,
              decoration: const InputDecoration(
                hintText: '搜索后回车',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AdminPanel(
          child: AdminAsync(
            value: value,
            retry: onRefresh,
            data: (page) => page.records.isEmpty
                ? const _Empty(text: '暂无数据')
                : Column(
                    children: [
                      ...page.records
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              name(item),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              subtitle(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: '编辑',
                                  onPressed: () => onEdit(item),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: '删除',
                                  onPressed: () => onDelete(item),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                      AdminPagination(page: page, onPage: onPage),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}

class _AuthorDialog extends _TextEntityDialog {
  _AuthorDialog(AdminAuthor? item)
    : super(
        title: item == null ? '新增作者' : '编辑作者',
        labels: const ['姓名', '国家或地区', '简介'],
        values: [
          item?.name ?? '',
          item?.country ?? '',
          item?.introduction ?? '',
        ],
        keys: const ['name', 'country', 'introduction'],
      );
}

class _PublisherDialog extends _TextEntityDialog {
  _PublisherDialog(AdminPublisher? item)
    : super(
        title: item == null ? '新增出版社' : '编辑出版社',
        labels: const ['名称', '联系电话', '地址', '简介'],
        values: [
          item?.name ?? '',
          item?.phone ?? '',
          item?.address ?? '',
          item?.introduction ?? '',
        ],
        keys: const ['name', 'phone', 'address', 'introduction'],
      );
}

class _TextEntityDialog extends StatefulWidget {
  const _TextEntityDialog({
    required this.title,
    required this.labels,
    required this.values,
    required this.keys,
  });
  final String title;
  final List<String> labels;
  final List<String> values;
  final List<String> keys;
  @override
  State<_TextEntityDialog> createState() => _TextEntityDialogState();
}

class _TextEntityDialogState extends State<_TextEntityDialog> {
  late final List<TextEditingController> controllers;
  @override
  void initState() {
    super.initState();
    controllers = widget.values
        .map((e) => TextEditingController(text: e))
        .toList();
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 450,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controllers[i],
                maxLines: i == controllers.length - 1 ? 3 : 1,
                decoration: InputDecoration(
                  labelText: widget.labels[i],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (controllers.first.text.trim().isEmpty) return;
          Navigator.pop(context, {
            for (var i = 0; i < controllers.length; i++)
              widget.keys[i]: controllers[i].text.trim(),
          });
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog(this.item, this.categories);
  final AdminCategory? item;
  final List<AdminCategory> categories;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController name;
  late final TextEditingController sort;
  int? parentId;
  int status = 1;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.item?.name);
    sort = TextEditingController(text: '${widget.item?.sortOrder ?? 0}');
    parentId = widget.item?.parentId;
    status = widget.item?.status ?? 1;
  }

  @override
  void dispose() {
    name.dispose();
    sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? '新增分类' : '编辑分类'),
    content: SizedBox(
      width: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: '分类名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: parentId,
            decoration: const InputDecoration(
              labelText: '上级分类',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('无上级分类')),
              ...widget.categories
                  .where((e) => e.id != widget.item?.id)
                  .map(
                    (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
                  ),
            ],
            onChanged: (v) => setState(() => parentId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: sort,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '排序值',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('启用')),
              ButtonSegment(value: 0, label: Text('停用')),
            ],
            selected: {status},
            onSelectionChanged: (v) => setState(() => status = v.first),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (name.text.trim().isEmpty) return;
          Navigator.pop(context, {
            'name': name.text.trim(),
            'parentId': parentId,
            'sortOrder': int.tryParse(sort.text) ?? 0,
            'status': status,
          });
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _PageActions extends StatelessWidget {
  const _PageActions({
    required this.title,
    required this.actionLabel,
    required this.onAdd,
    this.trailing,
  });
  final String title;
  final String actionLabel;
  final VoidCallback onAdd;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 260,
        child: Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
      ),
      if (trailing != null) trailing!,
      FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 18),
        label: Text(actionLabel),
      ),
    ],
  );
}

class _StateTag extends StatelessWidget {
  const _StateTag({required this.active, required this.on, required this.off});
  final bool active;
  final String on;
  final String off;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    color: (active ? AdminColors.green : AdminColors.red).withValues(alpha: .1),
    child: Text(
      active ? on : off,
      style: TextStyle(
        color: active ? AdminColors.green : AdminColors.red,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 180,
    child: Center(
      child: Text(text, style: const TextStyle(color: AdminColors.muted)),
    ),
  );
}
