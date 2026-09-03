import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/providers.dart';
import '../../../data/models/book/book.dart';
import '../../auth/presentation/auth_controller.dart';
import 'community_controller.dart';
import 'community_widgets.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNeeded);
    Future<void>.microtask(() {
      ref.read(communityFeedProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (_scrollController.position.extentAfter < 360) {
      ref.read(communityFeedProvider.notifier).loadMore();
    }
  }

  Future<void> _search({int? bookId, bool clearBook = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    return ref
        .read(communityFeedProvider.notifier)
        .load(
          keyword: _searchController.text,
          bookId: bookId,
          clearBook: clearBook,
        );
  }

  void _openEditor() {
    final auth = ref.read(authControllerProvider);
    context.go(
      auth.isAuthenticated
          ? AppRoutePaths.newCommunityPost
          : AppRoutePaths.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityFeedProvider);
    final bookOptions = ref.watch(communityBookOptionsProvider);
    final baseUrl = ref.watch(appConfigProvider).baseUrl;
    final selectedBook = state.bookId;

    return Scaffold(
      backgroundColor: CommunityColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('社区交流'),
        leading: IconButton(
          tooltip: '返回图书',
          onPressed: () => context.go(AppRoutePaths.books),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('发布'),
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: _CommunityFilters(
                      searchController: _searchController,
                      selectedBookId: selectedBook,
                      books: bookOptions.asData?.value ?? const <Book>[],
                      onSearch: _search,
                      onBookChanged: (value) => value == null
                          ? _search(clearBook: true)
                          : _search(bookId: value),
                    ),
                  ),
                ),
              ),
            ),
            if (state.status == CommunityFeedStatus.loading &&
                state.posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.status == CommunityFeedStatus.failure &&
                state.posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CommunityMessage(
                  icon: Icons.cloud_off_outlined,
                  message: state.errorMessage ?? '社区内容暂时无法加载',
                  actionLabel: '重新加载',
                  onAction: _search,
                ),
              )
            else if (state.posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _CommunityMessage(
                  icon: Icons.forum_outlined,
                  message: '还没有匹配的帖子，来发布第一篇吧',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList.separated(
                  itemCount: state.posts.length + (state.loadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index == state.posts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final post = state.posts[index];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: CommunityPostCard(
                          post: post,
                          baseUrl: baseUrl,
                          onTap: () =>
                              context.go(AppRoutePaths.communityPost(post.id)),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFilters extends StatelessWidget {
  const _CommunityFilters({
    required this.searchController,
    required this.selectedBookId,
    required this.books,
    required this.onSearch,
    required this.onBookChanged,
  });

  final TextEditingController searchController;
  final int? selectedBookId;
  final List<Book> books;
  final Future<void> Function() onSearch;
  final ValueChanged<int?> onBookChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: CommunityColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 650;
            final search = TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: InputDecoration(
                labelText: '按标题关键词搜索',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: '搜索',
                  onPressed: onSearch,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                border: const OutlineInputBorder(),
              ),
            );
            final book = DropdownButtonFormField<int>(
              initialValue: selectedBookId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: '按图书筛选',
                prefixIcon: const Icon(Icons.menu_book_outlined),
                suffixIcon: selectedBookId == null
                    ? null
                    : IconButton(
                        tooltip: '清除图书筛选',
                        onPressed: () => onBookChanged(null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final item in books)
                  DropdownMenuItem<int>(
                    value: item.id,
                    child: Text(item.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onBookChanged,
            );
            if (narrow) {
              return Column(
                children: [search, const SizedBox(height: 12), book],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: search),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: book),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CommunityMessage extends StatelessWidget {
  const _CommunityMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: CommunityColors.muted),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel ?? '重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
