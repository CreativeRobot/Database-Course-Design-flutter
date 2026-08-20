import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_bookstore/features/recommendations/data/recommendation_models.dart';

void main() {
  test('parses a personalized recommendation and its explanation', () {
    final home = RecommendationHome.fromJson({
      'source': 'PERSONALIZED',
      'books': [
        {
          'id': 7,
          'isbn': '9780000000007',
          'title': '算法导论',
          'publisherId': 3,
          'publisherName': '机械工业出版社',
          'originalPrice': 128,
          'salePrice': 99.5,
          'stock': 8,
          'status': 'ON_SALE',
          'coverUrl': '/uploads/algorithm.png',
          'reason': '与你喜欢的分类相似',
        },
      ],
    });

    expect(home.isPersonalized, isTrue);
    expect(home.books.single.id, 7);
    expect(home.books.single.salePrice, 99.5);
    expect(home.books.single.reason, '与你喜欢的分类相似');
  });
}
