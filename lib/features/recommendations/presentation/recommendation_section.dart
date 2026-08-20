import 'package:flutter/material.dart';

import '../../cart/presentation/commerce_widgets.dart';
import '../data/recommendation_models.dart';

class RecommendationBooks extends StatelessWidget {
  const RecommendationBooks({
    required this.home,
    required this.baseUrl,
    required this.onBookTap,
    super.key,
  });

  final RecommendationHome home;
  final String baseUrl;
  final ValueChanged<int> onBookTap;

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
        SizedBox(
          height: 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: home.books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final book = home.books[index];
              return SizedBox(
                width: 190,
                child: Material(
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
                          Text(
                            money(book.salePrice),
                            style: const TextStyle(
                              color: CommerceColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
