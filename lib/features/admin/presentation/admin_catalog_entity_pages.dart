part of 'admin_catalog_pages.dart';

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
    onSearch: (v) => setState(() {
      keyword = v;
      page = 1;
    }),
    onPage: (v) => setState(() => page = v),
    onRefresh: () =>
        ref.invalidate(adminAuthorsProvider((keyword: keyword, page: page))),
    bookFilter: (author) =>
        AdminBookFilter.author(id: author.id, name: author.name),
    onViewBooks: _viewBooks,
    onEdit: _edit,
    onDelete: _delete,
  );

  void _viewBooks(AdminBookFilter filter) {
    ref.read(adminBookFilterProvider.notifier).state = filter;
    context.go('/admin/${AdminSection.books.path}');
  }

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
    onSearch: (v) => setState(() {
      keyword = v;
      page = 1;
    }),
    onPage: (v) => setState(() => page = v),
    onRefresh: () =>
        ref.invalidate(adminPublishersProvider((keyword: keyword, page: page))),
    bookFilter: (publisher) =>
        AdminBookFilter.publisher(id: publisher.id, name: publisher.name),
    onViewBooks: _viewBooks,
    onEdit: _edit,
    onDelete: _delete,
  );

  void _viewBooks(AdminBookFilter filter) {
    ref.read(adminBookFilterProvider.notifier).state = filter;
    context.go('/admin/${AdminSection.books.path}');
  }

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
  String keyword = '';
  int? status;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(
      adminCategoryTreeProvider((keyword: keyword, status: status)),
    );
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageActions(
            title: '分类管理',
            actionLabel: '新增分类',
            onAdd: () => _edit(),
            trailing: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 230,
                  child: TextField(
                    onSubmitted: (value) => setState(() {
                      keyword = value;
                    }),
                    decoration: const InputDecoration(
                      hintText: '按分类名称搜索后回车',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                DropdownButton<int?>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('全部状态')),
                    DropdownMenuItem(value: 1, child: Text('启用')),
                    DropdownMenuItem(value: 0, child: Text('停用')),
                  ],
                  onChanged: (v) => setState(() => status = v),
                ),
              ],
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
                            (item) => _CategoryTreeNode(
                              item: item,
                              onToggle: _toggle,
                              onEdit: _edit,
                              onDelete: _delete,
                              onViewBooks: _viewBooks,
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

  void _refresh() => ref.invalidate(
    adminCategoryTreeProvider((keyword: keyword, status: status)),
  );

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

  void _viewBooks(AdminCategory item) {
    final name = item.parentName == null || item.parentName!.isEmpty
        ? item.name
        : '${item.parentName} / ${item.name}';
    ref.read(adminBookFilterProvider.notifier).state = AdminBookFilter.category(
      id: item.id,
      name: name,
    );
    context.go('/admin/${AdminSection.books.path}');
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
    )) {
      return;
    }
    try {
      await ref.read(adminRepositoryProvider).deleteCategory(item.id);
      _refresh();
    } catch (e) {
      if (mounted) showAdminMessage(context, e.toString());
    }
  }
}

class _CategoryTreeNode extends StatelessWidget {
  const _CategoryTreeNode({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onViewBooks,
    this.depth = 0,
  });

  final AdminCategory item;
  final ValueChanged<AdminCategory> onToggle;
  final ValueChanged<AdminCategory> onEdit;
  final ValueChanged<AdminCategory> onDelete;
  final ValueChanged<AdminCategory> onViewBooks;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      item.name,
      style: depth == 0 ? const TextStyle(fontWeight: FontWeight.w700) : null,
    );
    final subtitle = Text(
      depth == 0
          ? '一级分类 · 排序 ${item.sortOrder}'
          : '二级分类 · 排序 ${item.sortOrder}',
    );
    final actions = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _StateTag(active: item.status == 1, on: '启用', off: '停用'),
        IconButton(
          tooltip: '查看图书',
          onPressed: () => onViewBooks(item),
          icon: const Icon(Icons.menu_book_outlined),
        ),
        IconButton(
          tooltip: '启停',
          onPressed: () => onToggle(item),
          icon: const Icon(Icons.power_settings_new),
        ),
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
    );

    if (item.children.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: depth * 28),
        leading: Icon(
          depth == 0 ? Icons.folder_outlined : Icons.subdirectory_arrow_right,
        ),
        title: title,
        subtitle: subtitle,
        trailing: actions,
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: depth * 28),
      leading: const Icon(Icons.folder_outlined),
      title: title,
      subtitle: subtitle,
      trailing: actions,
      children: item.children
          .map(
            (child) => _CategoryTreeNode(
              item: child,
              onToggle: onToggle,
              onEdit: onEdit,
              onDelete: onDelete,
              onViewBooks: onViewBooks,
              depth: depth + 1,
            ),
          )
          .toList(),
    );
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
    this.bookFilter,
    this.onViewBooks,
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
  final AdminBookFilter Function(T)? bookFilter;
  final ValueChanged<AdminBookFilter>? onViewBooks;
  @override
  Widget build(BuildContext context) {
    final createBookFilter = bookFilter;
    final viewBooks = onViewBooks;
    return AdminPageBody(
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
                                    if (createBookFilter != null &&
                                        viewBooks != null)
                                      IconButton(
                                        tooltip: '查看图书',
                                        onPressed: () =>
                                            viewBooks(createBookFilter(item)),
                                        icon: const Icon(
                                          Icons.menu_book_outlined,
                                        ),
                                      ),
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
  Widget build(BuildContext context) {
    final hasChildren = widget.categories.any(
      (category) => category.parentId == widget.item?.id,
    );
    final parentOptions = widget.categories
        .where(
          (category) =>
              category.parentId == null && category.id != widget.item?.id,
        )
        .toList();

    return AlertDialog(
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
                labelText: '上级分类（仅可选择一级分类）',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('无上级分类')),
                ...parentOptions.map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                ),
              ],
              onChanged: hasChildren
                  ? null
                  : (value) => setState(() => parentId = value),
            ),
            if (hasChildren) ...[
              const SizedBox(height: 8),
              const Text('包含二级分类的一级分类不能设置上级分类。'),
            ],
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
              onSelectionChanged: (value) =>
                  setState(() => status = value.first),
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
}
