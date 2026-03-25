import 'package:dio/dio.dart';

class UnauthorizedRedirectInterceptor extends Interceptor {
  UnauthorizedRedirectInterceptor({
    required this.readCurrentLocation,
    required this.onUnauthorized,
  });

  final String Function() readCurrentLocation;
  final void Function(String redirectLocation) onUnauthorized;

  static const _loginApiPath = '/v1/login';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    if (statusCode == 401 && !_isLoginRequest(err.requestOptions.path)) {
      onUnauthorized(readCurrentLocation());
    }
    handler.next(err);
  }

  bool _isLoginRequest(String path) {
    final normalized = path.trim().toLowerCase();
    return normalized == _loginApiPath || normalized.endsWith(_loginApiPath);
  }
}
