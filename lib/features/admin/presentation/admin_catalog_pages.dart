import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/providers.dart';
import '../../../core/utils/book_pricing.dart';
import '../../../core/utils/media_url.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/book_detail.dart';
import '../../../data/models/common/page_response.dart';
import '../../cart/presentation/commerce_widgets.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import 'admin_book_filter.dart';
import 'admin_page.dart';
import 'admin_providers.dart';

part 'admin_catalog_entity_pages.dart';

class AdminBooksPage extends ConsumerStatefulWidget {
  const AdminBooksPage({super.key});
  @override
  ConsumerState<AdminBooksPage> createState() => _AdminBooksPageState();
}

class _AdminBooksPageState extends ConsumerState<AdminBooksPage> {
  String _keyword = '';
  String? _status;
  int _page = 1;
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminBookFilterProvider);
    final value = ref.watch(
      adminBooksProvider((
        keyword: _keyword,
        status: _status,
        authorId: filter?.authorId,
        publisherId: filter?.publisherId,
        categoryId: filter?.categoryId,
        page: _page,
      )),
    );
    final baseUrl = ref.watch(appConfigProvider).baseUrl;
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageActions(
            title: '图书管理',
            actionLabel: '新增图书',
            onAdd: () => _edit(),
            trailing: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 230,
                  child: TextField(
                    onSubmitted: (value) => setState(() {
                      _keyword = value;
                      _page = 1;
                    }),
                    decoration: const InputDecoration(
                      hintText: '按书名搜索后回车',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                DropdownButton<String?>(
                  value: _status,
                  hint: const Text('全部状态'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('全部状态')),
                    DropdownMenuItem(value: 'ON_SALE', child: Text('在售')),
                    DropdownMenuItem(value: 'OFF_SALE', child: Text('下架')),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value;
                    _page = 1;
                  }),
                ),
              ],
            ),
          ),
          if (filter != null) ...[
            const SizedBox(height: 12),
            _BookFilterNotice(
              label: filter.managementLabel,
              onClear: () {
                setState(() => _page = 1);
                ref.read(adminBookFilterProvider.notifier).state = null;
              },
            ),
          ],
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
                              coverUrl: resolveMediaUrl(baseUrl, book.coverUrl),
                              onEdit: () => _edit(book),
                              onStatus: () => _statusBook(book),
                              onStock: () => _stock(book),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          value.when(
            data: (page) => AdminPagination(
              page: page,
              onPage: (p) => setState(() => _page = p),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _refresh() {
    final filter = ref.read(adminBookFilterProvider);
    ref.invalidate(
      adminBooksProvider((
        keyword: _keyword,
        status: _status,
        authorId: filter?.authorId,
        publisherId: filter?.publisherId,
        categoryId: filter?.categoryId,
        page: _page,
      )),
    );
  }

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
    required this.coverUrl,
    required this.onEdit,
    required this.onStatus,
    required this.onStock,
  });
  final Book book;
  final String? coverUrl;
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
        CommerceCover(url: coverUrl, width: 42),
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
            const PopupMenuItem(value: 'edit', child: Text('编辑图书与折扣')),
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
      'discount': TextEditingController(
        text: _initialDiscountPercent(book).toStringAsFixed(2),
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
    _syncSalePrice();
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
                  _field(
                    'original',
                    '原价',
                    required: true,
                    number: true,
                    onChanged: (_) => _syncSalePrice(),
                  ),
                  _field(
                    'discount',
                    '折扣（%）',
                    required: true,
                    number: true,
                    helperText: '100 为原价，80 表示 8 折',
                    onChanged: (_) => _syncSalePrice(),
                  ),
                  _field('sale', '折后售价（自动计算）', number: true, readOnly: true),
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
    bool readOnly = false,
    String? helperText,
    ValueChanged<String>? onChanged,
  }) => SizedBox(
    width: 350,
    child: TextFormField(
      controller: _fields[key],
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      readOnly: readOnly,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
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
    if (!original.isFinite || original < 0) {
      setState(() => _error = '原价不能为负数');
      return;
    }
    final discount = double.tryParse(_fields['discount']!.text);
    if (discount == null) {
      setState(() => _error = '请输入有效折扣');
      return;
    }
    late final double sale;
    try {
      sale = BookPricing.salePrice(
        originalPrice: original,
        discountPercent: discount,
      );
    } on ArgumentError {
      setState(() => _error = '折扣必须在 0 到 100 之间');
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

  double _initialDiscountPercent(BookDetail? book) {
    if (book == null) return 100;
    try {
      return BookPricing.discountPercent(
        originalPrice: book.originalPrice,
        salePrice: book.salePrice,
      );
    } on ArgumentError {
      return 100;
    }
  }

  void _syncSalePrice() {
    final original = double.tryParse(_fields['original']!.text);
    final discount = double.tryParse(_fields['discount']!.text);
    if (original == null || discount == null) {
      _fields['sale']!.text = '';
      return;
    }
    try {
      _fields['sale']!.text = BookPricing.salePrice(
        originalPrice: original,
        discountPercent: discount,
      ).toStringAsFixed(2);
    } on ArgumentError {
      _fields['sale']!.text = '';
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

class _BookFilterNotice extends StatelessWidget {
  const _BookFilterNotice({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7F3),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFB9D7C5)),
    ),
    child: Row(
      children: [
        const Icon(Icons.filter_alt_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear, size: 16),
          label: const Text('查看全部图书'),
        ),
      ],
    ),
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
