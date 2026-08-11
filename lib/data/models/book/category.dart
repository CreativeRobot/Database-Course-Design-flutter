class BookCategory {
  const BookCategory({required this.id, required this.name, this.parentName});

  factory BookCategory.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('分类响应格式不正确');
    }
    return BookCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      parentName: json['parentName'] as String?,
    );
  }

  final int id;
  final String name;
  final String? parentName;
}
