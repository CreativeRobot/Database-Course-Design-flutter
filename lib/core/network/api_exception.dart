class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int? statusCode;
  final int? code;
  final String message;

  bool get isUnauthorized => statusCode == 401 || code == 401;
  bool get isForbidden => statusCode == 403 || code == 403;
  bool get isConflict => statusCode == 409 || code == 409;

  @override
  String toString() => 'ApiException($statusCode/$code): $message';
}
