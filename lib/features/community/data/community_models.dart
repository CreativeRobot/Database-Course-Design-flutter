import '../../../data/models/common/page_response.dart';

class CommunityBookRef {
  const CommunityBookRef({required this.id, required this.title});
  final int id;
  final String title;
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.status,
    required this.imageUrls,
    required this.books,
    required this.commentCount,
    this.authorAvatar,
    this.createTime,
    this.updateTime,
  });

  factory CommunityPost.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('帖子响应格式不正确');
    }
    final ids = (json['bookIds'] as List? ?? const [])
        .map((value) => (value as num).toInt())
        .toList(growable: false);
    final titles = (json['bookTitles'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    return CommunityPost(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      authorName: json['authorName'] as String? ?? '读者',
      authorAvatar: json['authorAvatar'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 1,
      createTime: _date(json['createTime']),
      updateTime: _date(json['updateTime']),
      imageUrls: (json['imageUrls'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      books: List.generate(
        ids.length,
        (index) => CommunityBookRef(
          id: ids[index],
          title: index < titles.length ? titles[index] : '图书 ${ids[index]}',
        ),
        growable: false,
      ),
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final int userId;
  final String authorName;
  final String? authorAvatar;
  final String title;
  final String content;
  final int status;
  final DateTime? createTime;
  final DateTime? updateTime;
  final List<String> imageUrls;
  final List<CommunityBookRef> books;
  final int commentCount;
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.status,
    this.authorAvatar,
    this.parentId,
    this.createTime,
  });

  factory CommunityComment.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('评论响应格式不正确');
    }
    return CommunityComment(
      id: (json['id'] as num).toInt(),
      postId: (json['postId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      authorName: json['authorName'] as String? ?? '读者',
      authorAvatar: json['authorAvatar'] as String?,
      parentId: (json['parentId'] as num?)?.toInt(),
      content: json['content'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 1,
      createTime: _date(json['createTime']),
    );
  }

  final int id;
  final int postId;
  final int userId;
  final String authorName;
  final String? authorAvatar;
  final int? parentId;
  final String content;
  final int status;
  final DateTime? createTime;
  bool get isReply => parentId != null;
}

class CommunityPostDraft {
  CommunityPostDraft({
    required String title,
    required String content,
    List<String> imageUrls = const [],
    List<int> bookIds = const [],
  }) : title = title.trim(),
       content = content.trim(),
       imageUrls = List.unmodifiable(imageUrls),
       bookIds = List.unmodifiable(bookIds.toSet()) {
    if (this.title.isEmpty || this.title.length > 120) {
      throw ArgumentError('标题不能为空且不能超过120个字符');
    }
    if (this.content.isEmpty || this.content.length > 5000) {
      throw ArgumentError('正文不能为空且不能超过5000个字符');
    }
    if (this.imageUrls.length > 9) throw ArgumentError('最多添加9张图片');
  }

  final String title;
  final String content;
  final List<String> imageUrls;
  final List<int> bookIds;
  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'imageUrls': imageUrls,
    'bookIds': bookIds,
  };
}

class UploadedCommunityImage {
  const UploadedCommunityImage({required this.url, required this.filename});
  factory UploadedCommunityImage.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) throw const FormatException('上传响应格式不正确');
    return UploadedCommunityImage(
      url: json['url'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
    );
  }
  final String url;
  final String filename;
}

PageResponse<CommunityPost> communityPostPage(dynamic json) =>
    PageResponse.fromJson(json, itemParser: CommunityPost.fromJson);
PageResponse<CommunityComment> communityCommentPage(dynamic json) =>
    PageResponse.fromJson(json, itemParser: CommunityComment.fromJson);

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;
