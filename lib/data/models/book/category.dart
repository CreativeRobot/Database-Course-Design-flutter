class BookCategory {
  const BookCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.parentName,
    this.children = const [],
  });

  factory BookCategory.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('分类响应格式不正确');
    }
    final rawChildren = json['children'];
    return BookCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      parentId: (json['parentId'] as num?)?.toInt(),
      parentName: json['parentName'] as String?,
      children: rawChildren is List
          ? rawChildren.map(BookCategory.fromJson).toList(growable: false)
          : const [],
    );
  }

  final int id;
  final String name;
  final int? parentId;
  final String? parentName;
  final List<BookCategory> children;
}
