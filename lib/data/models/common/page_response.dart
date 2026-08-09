class PageResponse<T> {
  const PageResponse({
    required this.records,
    required this.total,
    required this.page,
    required this.size,
    required this.totalPages,
  });

  factory PageResponse.fromJson(
    dynamic json, {
    required T Function(dynamic item) itemParser,
  }) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('分页响应必须是 JSON 对象');
    }
    final rawRecords = json['records'];
    if (rawRecords is! List) {
      throw const FormatException('分页响应缺少 records 数组');
    }
    return PageResponse<T>(
      records: rawRecords.map(itemParser).toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? 10,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  final List<T> records;
  final int total;
  final int page;
  final int size;
  final int totalPages;
}
