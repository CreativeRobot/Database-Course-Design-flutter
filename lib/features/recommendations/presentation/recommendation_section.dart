import 'package:flutter/material.dart';

import '../../cart/presentation/commerce_widgets.dart';
import '../data/recommendation_models.dart';

class RecommendationBooks extends StatelessWidget {
  const RecommendationBooks({
    required this.home,
    required this.baseUrl,
    required this.onBookTap,
    this.onLoadMore,
    this.loadingMore = false,
    super.key,
  });

  final RecommendationHome home;
  final String baseUrl;
  final ValueChanged<int> onBookTap;
  final VoidCallback? onLoadMore;
  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    if (home.books.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                '为你推荐',
                style: TextStyle(
                  color: CommerceColors.ink,
                  fontFamily: 'serif',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              home.isPersonalized ? '基于你的阅读偏好' : '热门畅销书',
              style: const TextStyle(color: CommerceColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 650
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: .68,
              ),
              itemCount: home.books.length,
              itemBuilder: (context, index) {
                final book = home.books[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onBookTap(book.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: CommerceColors.line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CommerceCover(
                              url: commerceImageUrl(baseUrl, book.coverUrl),
                              width: double.infinity,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: CommerceColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            book.reason,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: CommerceColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 5),
                          _RecommendationPrice(book: book),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (onLoadMore != null && home.hasMore) ...[
          const SizedBox(height: 18),
          Center(
            child: IconButton(
              onPressed: loadingMore ? null : onLoadMore,
              tooltip: loadingMore ? '正在加载更多推荐' : '加载更多推荐',
              icon: loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecommendationPrice extends StatelessWidget {
  const _RecommendationPrice({required this.book});

  final RecommendationBook book;

  @override
  Widget build(BuildContext context) {
    final isDiscounted = book.originalPrice > book.salePrice;
    final isBundle = book.title.contains('组合包') ||
        book.reason.contains('组合包') ||
        book.reason.toLowerCase().contains('bundle');
    final badge = isBundle
        ? '组合包更优惠'
        : isDiscounted
        ? '限时折扣'
        : null;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        if (badge != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: isBundle
                  ? const Color(0xFFE7F6EF)
                  : const Color(0xFFFFE4E1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                badge,
                style: TextStyle(
                  color: isBundle
                      ? CommerceColors.success
                      : const Color(0xFFB42318),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (isDiscounted)
          Text(
            money(book.originalPrice),
            style: const TextStyle(
              color: CommerceColors.muted,
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(
          money(book.salePrice),
          style: const TextStyle(
            color: CommerceColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
