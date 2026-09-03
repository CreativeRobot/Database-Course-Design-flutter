import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../data/models/book/book.dart';
import '../../cart/presentation/commerce_widgets.dart';
import 'book_catalog_grid.dart';
import 'books_controller.dart';

class CategoryBooksPage extends ConsumerStatefulWidget {
  const CategoryBooksPage({required this.categoryId, super.key});

  final int categoryId;

  @override
  ConsumerState<CategoryBooksPage> createState() => _CategoryBooksPageState();
}

class _CategoryBooksPageState extends ConsumerState<CategoryBooksPage> {
  List<Book> _books = const [];
  int _page = 1;
  int _totalPages = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _errorMessage;

  bool get _hasMore => _page < _totalPages;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _loadPage());
  }

  Future<void> _loadPage({int page = 1}) async {
    if (page == 1) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await ref
          .read(bookRepositoryProvider)
          .getBooks(
            categoryId: widget.categoryId,
            inStock: true,
            sortBy: 'sales',
            page: page,
            size: 12,
          );
      if (!mounted) return;
      setState(() {
        _books = page == 1 ? result.records : [..._books, ...result.records];
        _page = result.page;
        _totalPages = result.totalPages;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorMessage = page == 1 ? '分类图书暂时无法加载' : '更多图书暂时无法加载';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ref.watch(appConfigProvider).baseUrl;
    return Scaffold(
      backgroundColor: CommerceColors.canvas,
      appBar: AppBar(
        title: const Text('分类图书'),
        backgroundColor: CommerceColors.canvas,
        foregroundColor: CommerceColors.ink,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: _loading && _books.isEmpty
            ? const CommerceLoadingState(message: '正在加载分类图书')
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '分类 #${widget.categoryId}',
                      style: const TextStyle(
                        color: CommerceColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_errorMessage != null && _books.isEmpty)
                      CommerceErrorState(
                        message: _errorMessage!,
                        onRetry: _loadPage,
                      )
                    else if (_books.isEmpty)
                      const CommerceEmptyState(
                        icon: Icons.auto_stories_outlined,
                        message: '该分类暂时没有在售图书',
                      )
                    else
                      BookCatalogGrid(
                        books: _books,
                        baseUrl: baseUrl,
                        compact: MediaQuery.sizeOf(context).width < 800,
                        onBookTap: (bookId) => context.push('/books/$bookId'),
                        onLoadMore: _hasMore ? _loadMore : null,
                        loadingMore: _loadingMore,
                      ),
                    if (_errorMessage != null && _books.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: CommerceNotice(message: _errorMessage!),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _loadMore() => _loadPage(page: _page + 1);
}
