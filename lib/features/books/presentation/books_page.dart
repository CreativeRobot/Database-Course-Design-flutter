import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/providers.dart';
import '../../../data/models/auth/auth_session.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/category.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_controller.dart';
import 'books_controller.dart';

class BooksPage extends ConsumerStatefulWidget {
  const BooksPage({super.key});

  @override
  ConsumerState<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends ConsumerState<BooksPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(booksControllerProvider.notifier).loadInitial(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    FocusManager.instance.primaryFocus?.unfocus();
    ref
        .read(booksControllerProvider.notifier)
        .loadBooks(keyword: _searchController.text, clearCategory: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(booksControllerProvider);
    final session = ref.watch(authControllerProvider).session;
    final baseUrl = ref.watch(appConfigProvider).baseUrl;

    return Scaffold(
      backgroundColor: BookStoreColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 800;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _BooksHeader(
                    compact: compact,
                    session: session,
                    onCart: () => _protectedAction(context, '/cart'),
                    onOrders: () => _protectedAction(context, '/orders'),
                    onProfile: () => _protectedAction(context, '/profile'),
                    onLogin: () => context.go('/login'),
                    onLogout: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 20 : 56,
                    compact ? 28 : 48,
                    compact ? 20 : 56,
                    64,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _BooksHero(
                        compact: compact,
                        total: state.total,
                        searchController: _searchController,
                        onSearch: _search,
                      ),
                      const SizedBox(height: 36),
                      _CategoryBar(
                        categories: state.categories,
                        selectedCategoryId: state.categoryId,
                        onSelected: (categoryId) {
                          ref
                              .read(booksControllerProvider.notifier)
                              .loadBooks(
                                keyword: '',
                                categoryId: categoryId,
                                clearCategory: categoryId == null,
                              );
                          _searchController.clear();
                        },
                      ),
                      const SizedBox(height: 30),
                      _BookFilters(
                        sortBy: state.sortBy,
                        inStock: state.inStock,
                        minPrice: state.minPrice,
                        maxPrice: state.maxPrice,
                        onPrice: (min, max) => ref.read(booksControllerProvider.notifier).loadBooks(minPrice: min, maxPrice: max),
                        onSort: (value) => ref
                            .read(booksControllerProvider.notifier)
                            .loadBooks(sortBy: value),
                        onStock: (value) => ref
                            .read(booksControllerProvider.notifier)
                            .loadBooks(inStock: value),
                      ),
                      const SizedBox(height: 18),
                      if (state.errorMessage != null &&
                          state.books.isNotEmpty) ...[
                        _InlineNotice(message: state.errorMessage!),
                        const SizedBox(height: 18),
                      ],
                      if (state.status == BooksStatus.loading &&
                          state.books.isEmpty)
                        const _BooksLoading()
                      else if (state.status == BooksStatus.failure &&
                          state.books.isEmpty)
                        _BooksFailure(
                          message: state.errorMessage ?? '图书暂时无法加载',
                          onRetry: () => ref
                              .read(booksControllerProvider.notifier)
                              .loadBooks(),
                        )
                      else if (state.books.isEmpty)
                        const _BooksEmpty()
                      else
                        _BooksGrid(
                          books: state.books,
                          baseUrl: baseUrl,
                          compact: compact,
                          onBookTap: (bookId) => context.push('/books/$bookId'),
                          onLoadMore: state.hasMore
                              ? () => ref
                                    .read(booksControllerProvider.notifier)
                                    .loadMore()
                              : null,
                          loadingMore: state.status == BooksStatus.refreshing,
                        ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _protectedAction(BuildContext context, String path) {
    if (ref.read(authControllerProvider).isAuthenticated) {
      context.go(path);
      return;
    }
    context.push('/login');
  }
}

class BookDetailPage extends ConsumerStatefulWidget {
  const BookDetailPage({required this.bookId, super.key});

  final int bookId;

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  int reviewPage = 1;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final bookId = widget.bookId;
    final detail = ref.watch(bookDetailProvider(bookId));
    final reviews = ref.watch(bookReviewsProvider((bookId: bookId, page: reviewPage)));
    final baseUrl = ref.watch(appConfigProvider).baseUrl;
    final authState = ref.watch(authControllerProvider);
    final cartState = ref.watch(cartControllerProvider);

    return Scaffold(
      backgroundColor: BookStoreColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '书间',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/books'),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('返回书店'),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailFailure(
          message: appErrorMessage(error, fallback: '图书详情暂时无法加载'),
          onRetry: () => ref.invalidate(bookDetailProvider(bookId)),
        ),
        data: (book) => _BookDetailContent(
          book: book,
          reviews: reviews,
          onLoadMoreReviews: () => setState(() => reviewPage++),
          imageUrl: _coverUrl(baseUrl, book.coverUrl),
          adding: cartState.busyBookIds.contains(bookId),
          onAdd: book.stock <= 0 || book.status != 'ON_SALE'
              ? null
              : () async {
                  if (!authState.isAuthenticated) {
                    context.push('/login');
                    return;
                  }
                  final success = await ref
                      .read(cartControllerProvider.notifier)
                      .addItem(bookId: bookId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '已加入购物袋' : '加入购物袋失败'),
                      action: success
                          ? SnackBarAction(
                              label: '查看',
                              onPressed: () => context.go('/cart'),
                            )
                          : null,
                    ),
                  );
                },
        ),
      ),
    );
  }
}

class _BookFilters extends StatelessWidget {
  const _BookFilters({required this.sortBy, required this.inStock, required this.onSort, required this.onStock, required this.minPrice, required this.maxPrice, required this.onPrice});
  final String sortBy;
  final bool inStock;
  final ValueChanged<String> onSort;
  final ValueChanged<bool> onStock;
  final double? minPrice;
  final double? maxPrice;
  final void Function(double?, double?) onPrice;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      DropdownButton<String>(
        value: sortBy,
        items: const [
          DropdownMenuItem(value: 'latest', child: Text('最新上架')),
          DropdownMenuItem(value: 'price', child: Text('价格排序')),
          DropdownMenuItem(value: 'sales', child: Text('销量排序')),
        ],
        onChanged: (value) { if (value != null) onSort(value); },
      ),
      FilterChip(
        label: const Text('只看有库存'),
        selected: inStock,
        onSelected: onStock,
      ),
      SizedBox(
        width: 110,
        child: TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '最低价', isDense: true),
          onSubmitted: (value) => onPrice(double.tryParse(value), maxPrice),
        ),
      ),
      SizedBox(
        width: 110,
        child: TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '最高价', isDense: true),
          onSubmitted: (value) => onPrice(minPrice, double.tryParse(value)),
        ),
      ),
    ],
  );
}

class _BooksHeader extends StatelessWidget {
  const _BooksHeader({
    required this.compact,
    required this.session,
    required this.onCart,
    required this.onOrders,
    required this.onProfile,
    required this.onLogin,
    required this.onLogout,
  });

  final bool compact;
  final AuthSession? session;
  final VoidCallback onCart;
  final VoidCallback onOrders;
  final VoidCallback onProfile;
  final VoidCallback onLogin;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = session != null && session!.token.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 20 : 56, 18, compact ? 20 : 56, 0),
      child: Row(
        children: [
          const _BookStoreMark(),
          const SizedBox(width: 12),
          const Text(
            '书间',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          if (!compact) ...[
            TextButton.icon(
              onPressed: onCart,
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('购物袋'),
            ),
            TextButton.icon(
              onPressed: onOrders,
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('订单'),
            ),
            const SizedBox(width: 10),
          ],
          if (isAuthenticated)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'profile') {
                  onProfile();
                } else {
                  onLogout();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'profile', child: Text('个人中心')),
                PopupMenuItem(value: 'logout', child: Text('退出登录')),
              ],
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: BookStoreColors.sand,
                    child: Text(
                      _initialOf(
                        session!.nickname.isNotEmpty
                            ? session!.nickname
                            : session!.username,
                      ),
                      style: const TextStyle(
                        color: BookStoreColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 9),
                    Text(
                      session!.nickname.isNotEmpty
                          ? session!.nickname
                          : session!.username,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ],
              ),
            )
          else
            TextButton(onPressed: onLogin, child: const Text('登录 / 注册')),
        ],
      ),
    );
  }

  static String _initialOf(String value) {
    final text = value.trim();
    return text.isEmpty ? '读' : text.substring(0, 1);
  }
}

class _BooksHero extends StatelessWidget {
  const _BooksHero({
    required this.compact,
    required this.total,
    required this.searchController,
    required this.onSearch,
  });

  final bool compact;
  final int total;
  final TextEditingController searchController;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BOOKS  ·  在线书库',
          style: TextStyle(
            color: BookStoreColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          compact ? '把下一本好书，放进书架。' : '把下一本好书，\n放进你的书架。',
          style: TextStyle(
            color: BookStoreColors.ink,
            fontFamily: 'serif',
            fontSize: compact ? 42 : 60,
            height: 1.03,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                '从经典教材到值得收藏的小说，慢一点挑选，\n让每一次阅读都留下清晰的回响。',
                style: TextStyle(
                  color: BookStoreColors.muted,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),
            ),
            if (!compact)
              Text(
                '$total 本在售',
                style: const TextStyle(
                  color: BookStoreColors.placeholder,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          constraints: const BoxConstraints(maxWidth: 760),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: BookStoreColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: searchController,
            onSubmitted: (_) => onSearch(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索书名，例如：数据库、文学、设计',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: '搜索',
                onPressed: onSearch,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 17,
              ),
              hintStyle: const TextStyle(color: BookStoreColors.placeholder),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<BookCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CategoryChip(
            label: '全部',
            selected: selectedCategoryId == null,
            onTap: () => onSelected(null),
          ),
          ...categories.map(
            (category) => _CategoryChip(
              label: category.name,
              selected: selectedCategoryId == category.id,
              onTap: () => onSelected(category.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          color: selected ? Colors.white : BookStoreColors.muted,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: BookStoreColors.ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: BookStoreColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
    );
  }
}

class _BooksGrid extends StatelessWidget {
  const _BooksGrid({
    required this.books,
    required this.baseUrl,
    required this.compact,
    required this.onBookTap,
    required this.onLoadMore,
    required this.loadingMore,
  });

  final List<Book> books;
  final String baseUrl;
  final bool compact;
  final ValueChanged<int> onBookTap;
  final VoidCallback? onLoadMore;
  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = compact
            ? 2
            : constraints.maxWidth >= 1250
            ? 4
            : constraints.maxWidth >= 860
            ? 3
            : 2;
        return Column(
          children: [
            GridView.builder(
              itemCount: books.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: compact ? .62 : .69,
              ),
              itemBuilder: (context, index) {
                final book = books[index];
                return _BookCard(
                  book: book,
                  imageUrl: _coverUrl(baseUrl, book.coverUrl),
                  onTap: () => onBookTap(book.id),
                );
              },
            ),
            if (onLoadMore != null) ...[
              const SizedBox(height: 30),
              OutlinedButton.icon(
                onPressed: loadingMore ? null : onLoadMore,
                icon: loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded, size: 18),
                label: Text(loadingMore ? '正在加载' : '继续浏览'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.imageUrl,
    required this.onTap,
  });

  final dynamic book;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final salePrice = (book.salePrice as num).toDouble();
    final originalPrice = (book.originalPrice as num).toDouble();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BookStoreColors.line),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _BookCover(url: imageUrl),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              book.title as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BookStoreColors.ink,
                fontSize: 15,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              (book.publisherName as String).isEmpty
                  ? '未知出版社'
                  : book.publisherName as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BookStoreColors.placeholder,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '¥${salePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: BookStoreColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (originalPrice > salePrice) ...[
                  const SizedBox(width: 7),
                  Text(
                    '¥${originalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: BookStoreColors.placeholder,
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
                const Spacer(),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 17,
                  color: BookStoreColors.muted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookDetailContent extends StatelessWidget {
  const _BookDetailContent({
    required this.book,
    required this.reviews,
    required this.imageUrl,
    required this.adding,
    required this.onAdd,
    required this.onLoadMoreReviews,
  });

  final dynamic book;
  final AsyncValue<dynamic> reviews;
  final String? imageUrl;
  final bool adding;
  final Future<void> Function()? onAdd;
  final VoidCallback onLoadMoreReviews;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final cover = SizedBox(
                    width: compact ? double.infinity : 300,
                    height: compact ? 360 : 420,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _BookCover(url: imageUrl, large: true),
                    ),
                  );
                  final summary = _BookSummary(
                    book: book,
                    adding: adding,
                    onAdd: onAdd,
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            cover,
                            const SizedBox(height: 28),
                            summary,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            cover,
                            const SizedBox(width: 48),
                            Expanded(child: summary),
                          ],
                        );
                },
              ),
              const SizedBox(height: 52),
              const Text(
                'READERS  ·  读者评价',
                style: TextStyle(
                  color: BookStoreColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 18),
              reviews.when(
                loading: () => const _ReviewLoading(),
                error: (error, _) => _InlineNotice(
                  message: appErrorMessage(error, fallback: '评价暂时无法加载'),
                ),
                data: (summary) => _ReviewsPanel(
                  summary: summary,
                  onLoadMore: summary.reviews.totalPages > summary.reviews.page
                      ? onLoadMoreReviews
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookSummary extends StatelessWidget {
  const _BookSummary({
    required this.book,
    required this.adding,
    required this.onAdd,
  });

  final dynamic book;
  final bool adding;
  final Future<void> Function()? onAdd;

  @override
  Widget build(BuildContext context) {
    final salePrice = (book.salePrice as num).toDouble();
    final originalPrice = (book.originalPrice as num).toDouble();
    final authors = (book.authors as List).map((item) => item.name).join('、');
    final categories = (book.categories as List)
        .map((item) => item.name)
        .join(' / ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title as String,
          style: const TextStyle(
            color: BookStoreColors.ink,
            fontFamily: 'serif',
            fontSize: 44,
            height: 1.08,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          authors.isEmpty ? '作者信息待补充' : authors,
          style: const TextStyle(color: BookStoreColors.muted, fontSize: 16),
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥${salePrice.toStringAsFixed(2)}',
              style: const TextStyle(
                color: BookStoreColors.ink,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (originalPrice > salePrice) ...[
              const SizedBox(width: 10),
              Text(
                '¥${originalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: BookStoreColors.placeholder,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: adding || onAdd == null ? null : () => onAdd!(),
            icon: adding
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shopping_bag_outlined, size: 19),
            label: Text(
              adding
                  ? '正在加入'
                  : onAdd == null
                  ? '暂不可购买'
                  : '加入购物袋',
            ),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: BookStoreColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _MetaLine(label: '出版社', value: book.publisherName as String),
              _MetaLine(label: 'ISBN', value: book.isbn as String),
              _MetaLine(label: '出版日期', value: book.publishDate ?? '未提供'),
              _MetaLine(
                label: '版次 / 页数',
                value: [
                  if ((book.edition as String?)?.isNotEmpty == true)
                    book.edition,
                  if (book.pages != null) '${book.pages} 页',
                ].join('  ·  '),
              ),
              _MetaLine(
                label: '分类',
                value: categories.isEmpty ? '未分类' : categories,
              ),
              _MetaLine(
                label: '库存',
                value: (book.stock as int) > 0
                    ? '有货 · ${book.stock} 本'
                    : '暂时缺货',
              ),
            ],
          ),
        ),
        if ((book.description as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 28),
          Text(
            book.description as String,
            style: const TextStyle(
              color: BookStoreColors.muted,
              fontSize: 15,
              height: 1.8,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: BookStoreColors.placeholder,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '未提供' : value,
              style: const TextStyle(
                color: BookStoreColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsPanel extends StatelessWidget {
  const _ReviewsPanel({required this.summary, this.onLoadMore});

  final dynamic summary;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final reviews = summary.reviews.records as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: BookStoreColors.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Text(
                summary.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '读者平均评分',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  _Stars(
                    rating: summary.averageRating.round(),
                    color: BookStoreColors.gold,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${summary.reviewCount} 条评价',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (reviews.isEmpty)
          const _BooksEmpty(message: '暂时还没有公开评价')
        else
          ...reviews.map(
            (review) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BookStoreColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: BookStoreColors.sand,
                          child: Text(
                            _initialOf(review.reviewerName),
                            style: const TextStyle(
                              color: BookStoreColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          review.reviewerName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        _Stars(rating: review.rating),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Text(
                      review.content,
                      style: const TextStyle(
                        color: BookStoreColors.muted,
                        fontSize: 14,
                        height: 1.65,
                      ),
                    ),
                    if (review.createTime.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _formatDate(review.createTime),
                        style: const TextStyle(
                          color: BookStoreColors.placeholder,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (onLoadMore != null)
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: const Text('加载更多评价'),
            ),
          ),
      ],
    );
  }

  static String _initialOf(String value) {
    final text = value.trim();
    return text.isEmpty ? '读' : text.substring(0, 1);
  }

  static String _formatDate(String raw) {
    try {
      return DateFormat('yyyy.MM.dd').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.color = BookStoreColors.gold});

  final int rating;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 16,
          color: color,
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.url, this.large = false});

  final String? url;
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _CoverPlaceholder(large: large);
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (context, url) => const _CoverPlaceholder(),
      errorWidget: (context, url, error) => _CoverPlaceholder(large: large),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE9E5DC),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -18,
            child: Icon(
              Icons.auto_stories_rounded,
              size: large ? 180 : 100,
              color: const Color(0xFFD9D2C5),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            right: 18,
            child: Text(
              'BOOK\nSTORE',
              style: TextStyle(
                color: BookStoreColors.ink.withValues(alpha: .72),
                fontFamily: 'serif',
                fontSize: large ? 28 : 18,
                height: .9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookStoreMark extends StatelessWidget {
  const _BookStoreMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BookStoreColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '册',
        style: TextStyle(
          color: BookStoreColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BooksLoading extends StatelessWidget {
  const _BooksLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ReviewLoading extends StatelessWidget {
  const _ReviewLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 140,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _BooksEmpty extends StatelessWidget {
  const _BooksEmpty({this.message = '没有找到符合条件的图书'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BookStoreColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 38,
            color: BookStoreColors.placeholder,
          ),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: BookStoreColors.muted)),
        ],
      ),
    );
  }
}

class _BooksFailure extends StatelessWidget {
  const _BooksFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BookStoreColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 38,
            color: BookStoreColors.placeholder,
          ),
          const SizedBox(height: 13),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BookStoreColors.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        border: Border.all(color: const Color(0xFFF0C8C1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF8B3B33), fontSize: 13),
      ),
    );
  }
}

class _DetailFailure extends StatelessWidget {
  const _DetailFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _BooksFailure(message: message, onRetry: onRetry),
    );
  }
}

String? _coverUrl(String baseUrl, String? coverUrl) {
  if (coverUrl == null || coverUrl.trim().isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(coverUrl);
  if (parsed != null && parsed.hasScheme) {
    return coverUrl;
  }
  return '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/${coverUrl.replaceFirst(RegExp(r'^/'), '')}';
}

abstract final class BookStoreColors {
  static const canvas = Color(0xFFF7F6F2);
  static const ink = Color(0xFF171717);
  static const muted = Color(0xFF777570);
  static const placeholder = Color(0xFFA7A49D);
  static const line = Color(0xFFE5E3DE);
  static const sand = Color(0xFFEAE8E1);
  static const gold = Color(0xFFD4A845);
}

class ProtectedPlaceholderPage extends StatelessWidget {
  const ProtectedPlaceholderPage({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BookStoreColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => context.go('/books'),
            child: const Text('返回图书'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: BookStoreColors.line),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BookStoreColors.muted,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
