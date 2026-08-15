import 'package:flutter/material.dart';

import '../network/api_exception.dart';

String appErrorMessage(Object error, {String fallback = '操作失败，请稍后再试'}) {
  if (error is ApiException) {
    if (error.isUnauthorized) return '登录已过期，请重新登录';
    if (error.isForbidden) return '没有权限执行此操作';
    if (error.isConflict) return error.message.isNotEmpty ? error.message : '数据已存在或发生冲突';
    if (error.statusCode != null && error.statusCode! >= 500) {
      return '服务暂时不可用，请稍后再试';
    }
    final message = error.message.trim();
    if (message == 'Unable to connect to the server') return '暂时无法连接服务，请确认后端已经启动';
    if (message == 'Connection to server timed out') return '连接服务超时，请稍后再试';
    if (message.isNotEmpty && !message.startsWith('ApiException(')) return message;
  }
  if (error is FormatException) return '服务器返回的数据格式不正确';
  return fallback;
}

void showAppError(BuildContext context, Object error, {String? fallback}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(appErrorMessage(error, fallback: fallback ?? '操作失败，请稍后再试')),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
