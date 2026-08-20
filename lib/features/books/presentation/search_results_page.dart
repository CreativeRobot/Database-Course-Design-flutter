import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../cart/presentation/commerce_widgets.dart';
import 'book_catalog_grid.dart';
import 'search_results_controller.dart';

class SearchResultsPage extends ConsumerStatefulWidget {
  const SearchResultsPage({required this.initialKeyword, super.key});

  final String initialKeyword;

  @override
  ConsumerState<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends ConsumerState<SearchResultsPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialKeyword);
    Future<void>.microtask(
      () => ref
          .read(searchResultsControllerProvider(widget.initialKeyword).notifier)
          .loadInitial(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  SearchResultsController get _controller =>
      ref.read(searchResultsControllerProvider(widget.initialKeyword).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      searchResultsControllerProvider(widget.initialKeyword),
    );
    final baseUrl = ref.watch(appConfigProvider).baseUrl;
    return Scaffold(
      backgroundColor: CommerceColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '搜索结果',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: '返回书店',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/books');
            }
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 800;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? 20 : 56,
                16,
                compact ? 20 : 56,
                56,
              ),
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _controller.submitKeyword(value),
                  decoration: InputDecoration(
                    hintText: '搜索书名',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: '搜索',
                      onPressed: () =>
                          _controller.submitKeyword(_searchController.text),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: CommerceColors.line),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SearchFilters(
                  state: state,
                  onCategory: (value) => _controller.updateFilters(
                    categoryId: value,
                    clearCategory: value == null,
                  ),
                  onAuthor: (value) => _controller.updateFilters(
                    authorId: value,
                    clearAuthor: value == null,
                  ),
                  onPublisher: (value) => _controller.updateFilters(
                    publisherId: value,
                    clearPublisher: value == null,
                  ),
                  onStock: (value) => _controller.updateFilters(inStock: value),
                  onSort: (value) => _controller.updateFilters(sortBy: value),
                  onPrice: (min, max) => _controller.updateFilters(
                    minPrice: min,
                    maxPrice: max,
                    clearMinPrice: min == null,
                    clearMaxPrice: max == null,
                  ),
                ),
                if (state.optionsError != null) ...[
                  const SizedBox(height: 10),
                  CommerceNotice(message: state.optionsError!),
                ],
                if (state.errorMessage != null && state.books.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  CommerceNotice(message: state.errorMessage!),
                ],
                const SizedBox(height: 18),
                Text(
                  state.total == 0 ? '搜索结果' : '找到 ${state.total} 本图书',
                  style: const TextStyle(
                    color: CommerceColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.status == SearchResultsStatus.loading &&
                    state.books.isEmpty)
                  const CommerceLoadingState(message: '正在搜索图书')
                else if (state.status == SearchResultsStatus.failure &&
                    state.books.isEmpty)
                  CommerceErrorState(
                    message: state.errorMessage ?? '搜索暂时无法加载',
                    onRetry: _controller.retry,
                  )
                else if (state.books.isEmpty)
                  const CommerceEmptyState(
                    icon: Icons.search_off_rounded,
                    message: '没有找到符合条件的图书',
                  )
                else
                  BookCatalogGrid(
                    books: state.books,
                    baseUrl: baseUrl,
                    compact: compact,
                    onBookTap: (id) => context.push('/books/$id'),
                    onLoadMore: state.hasMore ? _controller.loadMore : null,
                    loadingMore: state.loadingMore,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchFilters extends StatelessWidget {
  const _SearchFilters({
    required this.state,
    required this.onCategory,
    required this.onAuthor,
    required this.onPublisher,
    required this.onStock,
    required this.onSort,
    required this.onPrice,
  });

  final SearchResultsState state;
  final ValueChanged<int?> onCategory;
  final ValueChanged<int?> onAuthor;
  final ValueChanged<int?> onPublisher;
  final ValueChanged<bool> onStock;
  final ValueChanged<String> onSort;
  final void Function(double?, double?) onPrice;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String>(
          value: state.sortBy,
          items: const [
            DropdownMenuItem(value: 'latest', child: Text('最新上架')),
            DropdownMenuItem(value: 'price', child: Text('价格排序')),
            DropdownMenuItem(value: 'sales', child: Text('销量排序')),
          ],
          onChanged: (value) {
            if (value != null) onSort(value);
          },
        ),
        _optionDropdown(
          value: state.categoryId,
          hint: '全部分类',
          options: state.categories
              .map((item) => (item.id, item.name))
              .toList(),
          onChanged: onCategory,
        ),
        _optionDropdown(
          value: state.authorId,
          hint: '全部作者',
          options: state.authors.map((item) => (item.id, item.name)).toList(),
          onChanged: onAuthor,
        ),
        _optionDropdown(
          value: state.publisherId,
          hint: '全部出版社',
          options: state.publishers
              .map((item) => (item.id, item.name))
              .toList(),
          onChanged: onPublisher,
        ),
        FilterChip(
          label: const Text('只看有库存'),
          selected: state.inStock,
          onSelected: onStock,
        ),
        _PriceField(
          label: '最低价',
          value: state.minPrice,
          onSubmitted: (value) => onPrice(value, state.maxPrice),
        ),
        _PriceField(
          label: '最高价',
          value: state.maxPrice,
          onSubmitted: (value) => onPrice(state.minPrice, value),
        ),
      ],
    );
  }

  Widget _optionDropdown({
    required int? value,
    required String hint,
    required List<(int, String)> options,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButton<int?>(
      value: value,
      hint: Text(hint),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(hint)),
        ...options.map(
          (item) =>
              DropdownMenuItem<int?>(value: item.$1, child: Text(item.$2)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.value,
    required this.onSubmitted,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: TextEditingController(text: value?.toString() ?? ''),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
        onSubmitted: (text) => onSubmitted(double.tryParse(text)),
      ),
    );
  }
}
