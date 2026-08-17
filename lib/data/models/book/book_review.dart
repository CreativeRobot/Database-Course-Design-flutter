import '../common/page_response.dart';

class BookReviewSummary {
  const BookReviewSummary({
    required this.bookId,
    required this.averageRating,
    required this.reviewCount,
    required this.reviews,
  });

  factory BookReviewSummary.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('评价响应格式不正确');
    }
    return BookReviewSummary(
      bookId: (json['bookId'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      reviews: PageResponse.fromJson(
        json['reviews'],
        itemParser: BookReview.fromJson,
      ),
    );
  }

  final int bookId;
  final double averageRating;
  final int reviewCount;
  final PageResponse<BookReview> reviews;

  BookReviewSummary withReviews(List<BookReview> records) => BookReviewSummary(
    bookId: bookId,
    averageRating: averageRating,
    reviewCount: reviewCount,
    reviews: PageResponse(
      records: records,
      total: reviews.total,
      page: reviews.page,
      size: reviews.size,
      totalPages: reviews.totalPages,
    ),
  );
}

class BookReview {
  const BookReview({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.reviewerName,
    required this.rating,
    required this.content,
    required this.createTime,
  });

  factory BookReview.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('评价记录格式不正确');
    }
    return BookReview(
      id: (json['id'] as num?)?.toInt() ?? 0,
      bookId: (json['bookId'] as num?)?.toInt() ?? 0,
      bookTitle: json['bookTitle'] as String? ?? '',
      reviewerName: json['reviewerName'] as String? ?? '匿名读者',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      createTime: json['createTime'] as String? ?? '',
    );
  }

  final int id;
  final int bookId;
  final String bookTitle;
  final String reviewerName;
  final int rating;
  final String content;
  final String createTime;
}
