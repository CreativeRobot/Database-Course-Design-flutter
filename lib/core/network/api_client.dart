import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import '../auth/session_events.dart';
import 'api_exception.dart';
import 'api_response.dart';

class ApiClient {
  ApiClient({required AppConfig config, required TokenStorage tokenStorage}) {
    _tokenStorage = tokenStorage;
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(tokenStorage));
  }

  late final Dio _dio;
  late final TokenStorage _tokenStorage;

  Future<ApiResponse<T>> request<T>(
    String path, {
    required String method,
    Map<String, dynamic>? queryParameters,
    Object? data,
    T Function(dynamic value)? parser,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        options: Options(method: method),
        queryParameters: queryParameters,
        data: data,
      );
      final result = ApiResponse<T>.fromJson(response.data, parser: parser);
      if (!result.isSuccess) {
        _notifyIfUnauthorized(result.code);
        throw ApiException(
          statusCode: response.statusCode,
          code: result.code,
          message: result.message,
        );
      }
      return result;
    } on DioException catch (error) {
      final body = error.response?.data;
      final bodyCode = body is Map<String, dynamic>
          ? (body['code'] as num?)?.toInt()
          : null;
      final bodyMessage = body is Map<String, dynamic>
          ? body['message'] as String?
          : null;
      throw ApiException(
        statusCode: error.response?.statusCode,
        code: bodyCode,
        message: bodyMessage ?? _messageFor(error),
      );
    } on ApiException {
      rethrow;
    } on FormatException catch (error) {
      throw ApiException(statusCode: null, code: null, message: error.message);
    }
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic value)? parser,
  }) {
    return request<T>(
      path,
      method: 'GET',
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? data,
    T Function(dynamic value)? parser,
  }) {
    return request<T>(path, method: 'POST', data: data, parser: parser);
  }

  Future<ApiResponse<T>> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    T Function(dynamic value)? parser,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        options: Options(contentType: 'multipart/form-data'),
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        }),
      );
      final result = ApiResponse<T>.fromJson(response.data, parser: parser);
      if (!result.isSuccess) {
        _notifyIfUnauthorized(result.code);
        throw ApiException(
          statusCode: response.statusCode,
          code: result.code,
          message: result.message,
        );
      }
      return result;
    } on DioException catch (error) {
      final body = error.response?.data;
      throw ApiException(
        statusCode: error.response?.statusCode,
        code: body is Map<String, dynamic>
            ? (body['code'] as num?)?.toInt()
            : null,
        message: body is Map<String, dynamic>
            ? body['message'] as String? ?? _messageFor(error)
            : _messageFor(error),
      );
    }
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    Object? data,
    T Function(dynamic value)? parser,
  }) {
    return request<T>(path, method: 'PUT', data: data, parser: parser);
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    Object? data,
    T Function(dynamic value)? parser,
  }) {
    return request<T>(path, method: 'DELETE', data: data, parser: parser);
  }

  String _messageFor(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection to server timed out';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server';
    }
    return 'Network request failed';
  }

  void _notifyIfUnauthorized(int? code) {
    if (code == 401) {
      unawaited(_tokenStorage.clearToken());
      SessionEvents.notifyTokenExpired();
    }
  }
}

class _AuthInterceptor extends Interceptor {
  const _AuthInterceptor(this._tokenStorage);

  final TokenStorage _tokenStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await _tokenStorage.clearToken();
      SessionEvents.notifyTokenExpired();
    }
    handler.next(err);
  }
}
