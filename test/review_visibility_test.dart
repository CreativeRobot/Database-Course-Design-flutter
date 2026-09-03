import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_application_bookstore/core/network/api_client.dart';
import 'package:flutter_application_bookstore/core/storage/token_storage.dart';
import 'package:flutter_application_bookstore/data/models/book/book_review.dart';
import 'package:flutter_application_bookstore/data/models/common/page_response.dart';
import 'package:flutter_application_bookstore/features/auth/data/auth_repository.dart';
import 'package:flutter_application_bookstore/features/auth/presentation/auth_controller.dart';
import 'package:flutter_application_bookstore/features/books/data/book_repository.dart';
import 'package:flutter_application_bookstore/features/books/presentation/books_controller.dart';
import 'package:flutter_application_bookstore/features/reviews/data/review_models.dart';
import 'package:flutter_application_bookstore/features/reviews/data/review_repository.dart';
import 'package:flutter_application_bookstore/features/reviews/presentation/reviews_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saving a review refreshes the public reviews for its book', () async {
    final books = _FakeBookRepository();
    final reviews = _FakeReviewRepository(
      onCreate: () => books.hasReview = true,
    );
    final auth = AuthController(
      repository: AuthRepository(_testApiClient()),
      tokenStorage: TokenStorage(),
    );
    final container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWithValue(books),
        reviewRepositoryProvider.overrideWithValue(reviews),
        authControllerProvider.overrideWith((ref) => auth),
      ],
    );
    addTearDown(container.dispose);

    const key = (bookId: 7, page: 1);
    final before = await container.read(bookReviewsProvider(key).future);
    expect(before.reviewCount, 0);

    final saved = await container
        .read(reviewsControllerProvider.notifier)
        .saveReview(orderItemId: 11, rating: 5, content: '值得推荐');

    expect(saved, isNotNull);
    final after = await container.read(bookReviewsProvider(key).future);
    expect(after.reviewCount, 1);
    expect(after.reviews.records.single.content, '值得推荐');
  });
}

class _FakeReviewRepository extends ReviewRepository {
  _FakeReviewRepository({required this.onCreate}) : super(_testApiClient());

  final void Function() onCreate;

  @override
  Future<UserReview> createReview({
    required int orderItemId,
    required int rating,
    required String content,
  }) async {
    onCreate();
    return UserReview(
      id: 20,
      bookId: 7,
      bookTitle: '测试图书',
      orderItemId: orderItemId,
      rating: rating,
      content: content,
      status: 1,
    );
  }
}

class _FakeBookRepository extends BookRepository {
  _FakeBookRepository() : super(_testApiClient());

  bool hasReview = false;

  @override
  Future<BookReviewSummary> getReviews(
    int bookId, {
    int page = 1,
    int size = 10,
  }) async {
    final records = hasReview
        ? [
            const BookReview(
              id: 20,
              bookId: 7,
              bookTitle: '测试图书',
              reviewerName: '读者',
              rating: 5,
              content: '值得推荐',
              createTime: '2026-09-03T10:00:00',
            ),
          ]
        : const <BookReview>[];
    return BookReviewSummary(
      bookId: bookId,
      averageRating: hasReview ? 5 : 0,
      reviewCount: records.length,
      reviews: PageResponse(
        records: records,
        total: records.length,
        page: page,
        size: size,
        totalPages: records.isEmpty ? 0 : 1,
      ),
    );
  }
}

ApiClient _testApiClient() => ApiClient(
  config: const AppConfig(baseUrl: 'http://localhost'),
  tokenStorage: TokenStorage(),
);
