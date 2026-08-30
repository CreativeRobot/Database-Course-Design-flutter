import 'package:flutter/material.dart';

import '../../../core/utils/book_presale.dart';
import '../../../data/models/book/book.dart';
import '../../cart/presentation/commerce_widgets.dart';

class BookCatalogGrid extends StatelessWidget {
  const BookCatalogGrid({
    required this.books,
    required this.baseUrl,
    required this.compact,
    required this.onBookTap,
    this.onLoadMore,
    this.loadingMore = false,
    super.key,
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
            : constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 760
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
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: compact ? .66 : .74,
              ),
              itemBuilder: (context, index) {
                final book = books[index];
                return _CatalogBookCard(
                  book: book,
                  baseUrl: baseUrl,
                  onTap: () => onBookTap(book.id),
                );
              },
            ),
            if (onLoadMore != null) ...[
              const SizedBox(height: 24),
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

class _CatalogBookCard extends StatelessWidget {
  const _CatalogBookCard({
    required this.book,
    required this.baseUrl,
    required this.onTap,
  });

  final Book book;
  final String baseUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final releaseTime = book.preSaleReleaseTime;
    final preSale = isActivePreSale(book.preSale, releaseTime);
    return InkWell(
      onTap: onTap,
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
            const SizedBox(height: 10),
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
              book.publisherName.isEmpty ? '未知出版社' : book.publisherName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CommerceColors.placeholder,
                fontSize: 11,
              ),
            ),
            if (preSale && releaseTime != null) ...[
              const SizedBox(height: 6),
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
            const SizedBox(height: 6),
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
    );
  }
}
