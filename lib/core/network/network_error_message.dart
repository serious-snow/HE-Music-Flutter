import 'package:dio/dio.dart';

import '../error/app_exception.dart';

class NetworkErrorMessage {
  NetworkErrorMessage._();

  static const captchaReason = 'CAPTCHA_REQUIRED';

  static String? resolve(
    Object error, {
    bool ignoreUnauthorized = false,
    bool ignoreCaptchaRequired = false,
  }) {
    if (error is AppException) {
      return error.failure.message.trim();
    }
    if (error is! DioException) {
      final fallback = '$error'.trim();
      return fallback.isEmpty ? null : fallback;
    }
    final statusCode = error.response?.statusCode;
    if (ignoreUnauthorized && statusCode == 401) {
      return null;
    }
    if (ignoreCaptchaRequired &&
        statusCode == 403 &&
        _readReason(error.response?.data) == captchaReason) {
      return null;
    }
    final dataMessage = _readMessage(error.response?.data);
    if (dataMessage != null) {
      return dataMessage;
    }
    if (statusCode != null) {
      return switch (statusCode) {
        400 => '请求参数错误',
        403 => '当前操作被拒绝',
        404 => '请求的内容不存在',
        500 => '服务器开小差了，请稍后重试',
        _ => _messageForType(error),
      };
    }
    return _messageForType(error);
  }

  static String _messageForType(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => '网络连接超时，请稍后重试',
      DioExceptionType.connectionError => '网络连接失败，请检查网络后重试',
      DioExceptionType.badCertificate => '网络证书校验失败',
      DioExceptionType.cancel => '请求已取消',
      DioExceptionType.badResponse => '服务响应异常，请稍后重试',
      DioExceptionType.unknown => _fallbackMessage(error.message),
    };
  }

  static String _fallbackMessage(String? message) {
    final normalized = message?.trim() ?? '';
    if (normalized.isEmpty) {
      return '请求失败，请稍后重试';
    }
    return normalized;
  }

  static String? _readMessage(dynamic raw) {
    final map = _asMap(raw);
    for (final key in const <String>['message', 'msg', 'error', 'detail']) {
      final direct = '${map[key] ?? ''}'.trim();
      if (direct.isNotEmpty) {
        return direct;
      }
    }
    final data = _asMap(map['data']);
    for (final key in const <String>['message', 'msg', 'error', 'detail']) {
      final nested = '${data[key] ?? ''}'.trim();
      if (nested.isNotEmpty) {
        return nested;
      }
    }
    return null;
  }

  static String _readReason(dynamic raw) {
    final map = _asMap(raw);
    return '${map['reason'] ?? ''}'.trim();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((dynamic key, dynamic item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }
}
