import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_bookstore/data/models/book/book.dart';
import 'package:flutter_application_bookstore/features/books/presentation/homepage_controller.dart';
import 'package:flutter_application_bookstore/features/books/presentation/homepage_sections.dart';
import 'package:flutter_application_bookstore/features/books/data/promotion_models.dart';
import 'package:flutter_application_bookstore/features/recommendations/data/recommendation_models.dart';

Book _book(int id, {bool preSale = false, DateTime? release}) {
  return Book(
    id: id,
    isbn: 'isbn-$id',
    title: '图书 $id',
    publisherId: 1,
    publisherName: '出版社',
    originalPrice: 50,
    salePrice: 40,
    stock: 10,
    status: 'ON_SALE',
    preSale: preSale,
    preSaleReleaseTime: release,
  );
}

void main() {
  test('limit accepts filtered book iterables and caps the result', () {
    final books = List.generate(12, (index) => _book(index + 1));

    final result = HomepageSections.limit(
      books.where((book) => book.id.isOdd),
      count: 3,
    );

    expect(result.map((book) => book.id), [1, 3, 5]);
  });

  test('promotion page index wraps around at both ends', () {
    expect(HomepageSections.promotionPageIndex(0, 3, -1), 2);
    expect(HomepageSections.promotionPageIndex(2, 3, 1), 0);
    expect(HomepageSections.promotionPageIndex(0, 0, 1), 0);
  });

  test('random candidates keep each loaded book only once', () {
    final candidates = HomepageSections.randomCandidates([
      _book(1),
      _book(2),
      _book(1),
      _book(3),
    ]);

    expect(candidates.map((book) => book.id), [1, 2, 3]);
  });

  test('upcoming books are future-only, date ordered, and capped at ten', () {
    final now = DateTime(2026, 9, 2, 12);
    final books = [
      _book(1, preSale: true, release: now.add(const Duration(days: 3))),
      _book(2, preSale: true, release: now.subtract(const Duration(hours: 1))),
      _book(3, preSale: true, release: now.add(const Duration(days: 1))),
      ...List.generate(
        12,
        (index) => _book(
          index + 4,
          preSale: true,
          release: now.add(Duration(days: index + 4)),
        ),
      ),
    ];

    final result = HomepageSections.upcoming(books, now: now);

    expect(result, hasLength(10));
    expect(result.first.id, 3);
    expect(result.any((book) => book.id == 2), isFalse);
    expect(result.last.id, 11);
  });

  test(
    'categories keep roots first and prioritize common shopping categories',
    () {
      final categories = [
        const BookCategory(id: 1, name: '其他', parentId: null),
        const BookCategory(id: 2, name: '文学小说', parentId: null),
        const BookCategory(id: 3, name: '文学小说', parentId: 2),
        const BookCategory(id: 4, name: '计算机', parentId: null),
      ];

      final result = HomepageSections.categories(categories);

      expect(result.map((category) => category.id), [2, 4, 1]);
      expect(result.every((category) => category.parentId == null), isTrue);
    },
  );

  test(
    'homepage controller loads independent feeds and caps each ranking',
    () async {
      final calls = <String>[];
      final controller = HomepageController(
        loadBooks: ({required sortBy, required size}) async {
          calls.add('$sortBy:$size');
          return List.generate(12, (index) => _book(index + 1));
        },
        loadCategories: () async => const [BookCategory(id: 1, name: '文学')],
      );

      await controller.load();

      expect(controller.state.status, HomepageStatus.success);
      expect(controller.state.newReleases, hasLength(10));
      expect(controller.state.bestSellers, hasLength(10));
      expect(calls, containsAll(['latest:60', 'sales:20']));
    },
  );

  testWidgets(
    'homepage sections expose calendar, rankings, and recommendations',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomepageSectionsView(
            data: HomepageState(
              status: HomepageStatus.success,
              newReleases: [_book(1)],
              bestSellers: [_book(2)],
              upcoming: [
                _book(3, preSale: true, release: DateTime(2026, 9, 5)),
              ],
            ),
            recommendation: const RecommendationHome(
              source: 'POPULAR',
              books: [
                RecommendationBook(
                  id: 9,
                  isbn: 'isbn-9',
                  title: '推荐',
                  publisherId: 1,
                  publisherName: '出版社',
                  originalPrice: 20,
                  salePrice: 18,
                  stock: 3,
                  status: 'ON_SALE',
                  reason: '热门畅销书',
                ),
              ],
            ),
            baseUrl: '',
            onBookTap: (_) {},
          ),
        ),
      );

      expect(find.text('发售日历'), findsOneWidget);
      expect(find.text('热门'), findsOneWidget);
      expect(find.text('折扣与活动'), findsNothing);
      expect(find.text('按类别浏览'), findsNothing);
      expect(find.text('为你推荐'), findsOneWidget);
    },
  );

  testWidgets(
    'homepage places promotion before rankings and release calendar',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomepageSectionsView(
            data: HomepageState(
              status: HomepageStatus.success,
              promotions: PromotionHome(
                discountedBooks: [
                  const PromotionBook(
                    id: 8,
                    title: '活动图书',
                    salePrice: 20,
                    baseSalePrice: 30,
                  ),
                ],
              ),
              newReleases: [_book(1)],
              bestSellers: [_book(2)],
              upcoming: [
                _book(3, preSale: true, release: DateTime(2026, 9, 5)),
              ],
            ),
            baseUrl: '',
            onBookTap: (_) {},
          ),
        ),
      );

      final promotionTop = tester.getTopLeft(find.text('折扣与活动')).dy;
      final rankingTop = tester.getTopLeft(find.text('热门')).dy;
      final calendarTop = tester.getTopLeft(find.text('发售日历')).dy;

      expect(promotionTop, lessThan(rankingTop));
      expect(rankingTop, lessThan(calendarTop));
      expect(find.text('按类别浏览'), findsNothing);
    },
  );

  testWidgets('release calendar provides previous and next navigation arrows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomepageSectionsView(
          data: HomepageState(
            status: HomepageStatus.success,
            upcoming: [
              for (var index = 1; index <= 4; index++)
                _book(
                  index,
                  preSale: true,
                  release: DateTime(2026, 9, index + 4),
                ),
            ],
          ),
          baseUrl: '',
          onBookTap: (_) {},
        ),
      ),
    );

    expect(find.byTooltip('上一组发售图书'), findsOneWidget);
    expect(find.byTooltip('下一组发售图书'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byTooltip('上一组发售图书'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byTooltip('下一组发售图书'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });
}
