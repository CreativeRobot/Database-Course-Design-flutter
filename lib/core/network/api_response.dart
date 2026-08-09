class ApiResponse<T> {
  const ApiResponse({
    required this.code,
    required this.message,
    required this.data,
  });

  factory ApiResponse.fromJson(
    dynamic json, {
    T Function(dynamic value)? parser,
  }) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('统一响应体必须是 JSON 对象');
    }

    final rawData = json['data'];
    return ApiResponse<T>(
      code: (json['code'] as num?)?.toInt() ?? 500,
      message: json['message'] as String? ?? '未知响应',
      data: parser == null ? rawData as T : parser(rawData),
    );
  }

  final int code;
  final String message;
  final T data;

  bool get isSuccess => code == 200;
}
