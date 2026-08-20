import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_bookstore/features/recommendations/data/recommendation_models.dart';
import 'package:flutter_application_bookstore/features/recommendations/presentation/recommendation_section.dart';

void main() {
  testWidgets('renders the recommendation reason returned by the service', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecommendationBooks(
          home: const RecommendationHome(
            source: 'PERSONALIZED',
            books: [
              RecommendationBook(
                id: 7,
                isbn: '9780000000007',
                title: '算法导论',
                publisherId: 3,
                publisherName: '机械工业出版社',
                originalPrice: 128,
                salePrice: 99.5,
                stock: 8,
                status: 'ON_SALE',
                reason: '与你喜欢的分类相似',
              ),
            ],
          ),
          baseUrl: 'http://localhost:8080',
          onBookTap: (_) {},
        ),
      ),
    );

    expect(find.text('为你推荐'), findsOneWidget);
    expect(find.text('与你喜欢的分类相似'), findsOneWidget);
    expect(find.text('算法导论'), findsOneWidget);
  });
}
