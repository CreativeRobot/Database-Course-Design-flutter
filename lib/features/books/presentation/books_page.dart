import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'books_controller.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/providers.dart';
import '../../../core/utils/book_presale.dart';
import '../../../data/models/auth/auth_session.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/book_review.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/commerce_widgets.dart';
import '../../cart/data/bundle_models.dart';
import '../../recommendations/presentation/recommendation_controller.dart';
import 'homepage_controller.dart';
import 'homepage_sections.dart';
import 'book_bundle_offers.dart';

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
    Future<void>.microtask(() {
      final auth = ref.read(authControllerProvider);
      if (auth.session?.role != 'ADMIN') {
        ref.read(recommendationControllerProvider.notifier).load();
        ref.read(homepageControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    FocusManager.instance.primaryFocus?.unfocus();
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;
    context.push('/search?keyword=${Uri.encodeQueryComponent(keyword)}');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    final baseUrl = ref.watch(appConfigProvider).baseUrl;
    final recommendation = ref.watch(recommendationControllerProvider);
    final homepage = ref.watch(homepageControllerProvider);
    final randomCandidates = HomepageSections.randomCandidates([
      ...homepage.newReleases,
      ...homepage.bestSellers,
      ...homepage.upcoming,
    ]);

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
                    searchController: _searchController,
                    onSearch: _search,
                    onRandomBook: randomCandidates.isEmpty
                        ? null
                        : () => _openRandomBook(randomCandidates),
                    onCart: () => _protectedAction(context, '/cart'),
                    onAdmin: () => _protectedAction(context, '/admin'),
                    onProfile: () => _protectedAction(context, '/profile'),
                    onLogin: () => context.go('/login'),
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
                      if (session?.role == 'ADMIN')
                        CommerceEmptyState(
                          icon: Icons.admin_panel_settings_outlined,
                          message: '管理员请进入管理台',
                          action: OutlinedButton(
                            onPressed: () => context.go('/admin'),
                            child: const Text('进入管理台'),
                          ),
                        )
                      else
                        HomepageSectionsView(
                          data: homepage,
                          recommendation: recommendation.home,
                          baseUrl: baseUrl,
                          onBookTap: (bookId) => context.push('/books/$bookId'),
                          onRecommendationLoadMore: () => ref
                              .read(recommendationControllerProvider.notifier)
                              .loadMore(),
                          recommendationLoadingMore:
                              recommendation.isLoadingMore,
                          onRetry: () {
                            ref
                                .read(homepageControllerProvider.notifier)
                                .load();
                            ref
                                .read(recommendationControllerProvider.notifier)
                                .load();
                          },
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

  void _openRandomBook(List<Book> books) {
    final book = books[Random().nextInt(books.length)];
    context.push('/books/${book.id}');
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
  final _loadedReviewIds = <int>{};
  final _loadedReviews = <BookReview>[];
  BookReviewSummary? _lastReviewSummary;

  void _mergeReviews(BookReviewSummary summary) {
    _lastReviewSummary = summary;
    var changed = false;
    for (final review in summary.reviews.records) {
      if (_loadedReviewIds.add(review.id)) {
        _loadedReviews.add(review);
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final bookId = widget.bookId;
    final detail = ref.watch(bookDetailProvider(bookId));
    final bundles = ref.watch(bookBundlesProvider(bookId));
    final reviews = ref.watch(
      bookReviewsProvider((bookId: bookId, page: reviewPage)),
    );
    reviews.whenData((summary) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mergeReviews(summary);
      });
    });
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
          bundles: bundles.asData?.value ?? const [],
          reviews: reviews,
          loadedReviews: _loadedReviews,
          cachedReviewSummary: _lastReviewSummary,
          onLoadMoreReviews: () => setState(() => reviewPage++),
          onRetryReviews: () => ref.invalidate(
            bookReviewsProvider((bookId: bookId, page: reviewPage)),
          ),
          imageUrl: _coverUrl(baseUrl, book.coverUrl),
          addingBundleId:
              cartState.busyAll && bundles.asData?.value.isNotEmpty == true
              ? bundles.asData!.value.first.id
              : null,
          onAddBundle: _addBundle,
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
                      content: Text(success ? '已加入购物车' : '加入购物车失败'),
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

  Future<bool> _addBundle(int bundleId) async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      context.push('/login');
      return false;
    }
    final success = await ref
        .read(cartControllerProvider.notifier)
        .addBundle(bundleId);
    if (!mounted) return success;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '组合包已加入购物车' : '组合包加入失败'),
        action: success
            ? SnackBarAction(label: '查看', onPressed: () => context.go('/cart'))
            : null,
      ),
    );
    return success;
  }
}

class _BooksHeader extends StatelessWidget {
  const _BooksHeader({
    required this.compact,
    required this.session,
    required this.searchController,
    required this.onSearch,
    required this.onRandomBook,
    required this.onCart,
    required this.onAdmin,
    required this.onProfile,
    required this.onLogin,
  });

  final bool compact;
  final AuthSession? session;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback? onRandomBook;
  final VoidCallback onCart;
  final VoidCallback onAdmin;
  final VoidCallback onProfile;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = session != null && session!.token.isNotEmpty;
    final isAdmin = isAuthenticated && session!.role == 'ADMIN';
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 20 : 56, 18, compact ? 20 : 56, 0),
      child: Column(
        children: [
          Row(
            children: [
              const BookstoreBrand(),
              const Spacer(),
              if (!compact) ...[
                SizedBox(
                  width: 260,
                  child: _HeaderSearch(
                    controller: searchController,
                    onSearch: onSearch,
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: '随机一本图书',
                  child: IconButton(
                    onPressed: onRandomBook,
                    icon: const Icon(Icons.casino_outlined),
                  ),
                ),
                Tooltip(
                  message: '购物车',
                  child: IconButton(
                    onPressed: onCart,
                    icon: const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
                if (isAdmin) ...[
                  TextButton.icon(
                    onPressed: onAdmin,
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 18,
                    ),
                    label: const Text('管理台'),
                  ),
                ],
              ],
              if (compact) ...[
                Tooltip(
                  message: '随机一本图书',
                  child: IconButton(
                    onPressed: onRandomBook,
                    icon: const Icon(Icons.casino_outlined),
                  ),
                ),
                Tooltip(
                  message: '购物车',
                  child: IconButton(
                    onPressed: onCart,
                    icon: const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
              ],
              if (isAuthenticated)
                Tooltip(
                  message: '个人中心',
                  child: InkWell(
                    onTap: onProfile,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                TextButton(onPressed: onLogin, child: const Text('登录 / 注册')),
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 14),
            _HeaderSearch(controller: searchController, onSearch: onSearch),
          ],
        ],
      ),
    );
  }

  static String _initialOf(String value) {
    final text = value.trim();
    return text.isEmpty ? '读' : text.substring(0, 1);
  }
}

class _HeaderSearch extends StatelessWidget {
  const _HeaderSearch({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => onSearch(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '搜索书名',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: '搜索',
          onPressed: onSearch,
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: BookStoreColors.line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: BookStoreColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: BookStoreColors.ink),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        hintStyle: const TextStyle(color: BookStoreColors.placeholder),
      ),
    );
  }
}

class _BooksHero extends StatelessWidget {
  const _BooksHero({required this.compact, required this.total});

  final bool compact;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BOOKS  ·  在线书店',
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
      ],
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
    final releaseTime = book.preSaleReleaseTime as DateTime?;
    final preSale = isActivePreSale(book.preSale as bool, releaseTime);
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
            if (preSale && releaseTime != null) ...[
              const SizedBox(height: 7),
              Text(
                preSaleNotice(releaseTime),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
    required this.bundles,
    this.addingBundleId,
    required this.onAddBundle,
    required this.reviews,
    required this.loadedReviews,
    required this.cachedReviewSummary,
    required this.imageUrl,
    required this.adding,
    required this.onAdd,
    required this.onLoadMoreReviews,
    required this.onRetryReviews,
  });

  final dynamic book;
  final List<BookBundle> bundles;
  final int? addingBundleId;
  final AsyncValue<dynamic> reviews;
  final List<BookReview> loadedReviews;
  final BookReviewSummary? cachedReviewSummary;
  final String? imageUrl;
  final bool adding;
  final Future<void> Function()? onAdd;
  final Future<bool> Function(int bundleId) onAddBundle;
  final VoidCallback onLoadMoreReviews;
  final VoidCallback onRetryReviews;

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
              if (bundles.isNotEmpty) ...[
                const SizedBox(height: 32),
                BookBundleOffers(
                  bundles: bundles,
                  addingBundleId: addingBundleId,
                  onAddBundle: (bundleId) => onAddBundle(bundleId),
                ),
              ],
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
                loading: () => cachedReviewSummary == null
                    ? const _ReviewLoading()
                    : _ReviewsPanel(
                        summary: cachedReviewSummary!,
                        reviewsOverride: loadedReviews,
                      ),
                error: (error, _) => CommerceErrorState(
                  message: appErrorMessage(error, fallback: '评价暂时无法加载'),
                  onRetry: onRetryReviews,
                ),
                data: (summary) => _ReviewsPanel(
                  summary: summary,
                  reviewsOverride: loadedReviews.isEmpty ? null : loadedReviews,
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
    final releaseTime = book.preSaleReleaseTime as DateTime?;
    final preSale = isActivePreSale(book.preSale as bool, releaseTime);
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
        if (preSale && releaseTime != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              border: Border.all(color: const Color(0xFFFDBA74)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${preSaleNotice(releaseTime)}\n'
              '现在可下单并付款，图书发售后安排发货。',
              style: const TextStyle(
                color: Color(0xFF9A3412),
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
                  : preSale
                  ? '加入预购'
                  : '加入购物车',
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F4),
              border: Border.all(color: BookStoreColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '内容简介',
                  style: TextStyle(
                    color: BookStoreColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  book.description as String,
                  style: const TextStyle(
                    color: BookStoreColors.muted,
                    fontSize: 15,
                    height: 1.8,
                  ),
                ),
              ],
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
  const _ReviewsPanel({
    required this.summary,
    this.onLoadMore,
    this.reviewsOverride,
  });

  final dynamic summary;
  final VoidCallback? onLoadMore;
  final List<BookReview>? reviewsOverride;

  @override
  Widget build(BuildContext context) {
    final reviews =
        reviewsOverride ?? (summary.reviews.records as List<BookReview>);
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
