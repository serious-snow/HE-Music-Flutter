import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/router/app_router.dart';
import '../../app/router/app_routes.dart';
import '../captcha/captcha_coordinator.dart';
import 'auth_token_interceptor.dart';
import 'captcha_challenge_interceptor.dart';
import 'error_message_interceptor.dart';
import 'unauthorized_redirect_interceptor.dart';

final apiDioProvider = Provider<Dio>((ref) {
  // 只监听网络相关字段，避免主题色等无关配置水合触发 Dio 重建，从而中断启动阶段请求。
  final (authToken, apiBaseUrl, localeCode) = ref.watch(
    appConfigProvider.select(
      (config) => (config.authToken, config.apiBaseUrl, config.localeCode),
    ),
  );
  final router = ref.watch(appRouterProvider);
  final configController = ref.read(appConfigProvider.notifier);
  final captchaCoordinator = CaptchaCoordinator(router);
  final baseUrl = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
    ),
  );

  // 避免在 interceptor 回调里再次使用 Riverpod ref（会触发 “dependency changed but before rebuild” 断言）。
  // 配置变更时通过 Provider 重建 Dio 实例来更新行为。
  dio.interceptors.add(
    AuthTokenInterceptor(() {
      return authToken;
    }, () => localeCode),
  );
  dio.interceptors.add(
    UnauthorizedRedirectInterceptor(
      readCurrentLocation: () {
        try {
          return router.state.uri.toString();
        } catch (_) {
          return AppRoutes.home;
        }
      },
      onUnauthorized: (redirectLocation) {
        configController.clearAuthToken();
        final currentLocation = _safeCurrentRoute(router);
        if (currentLocation.startsWith(AppRoutes.login)) {
          return;
        }
        final normalizedRedirect = redirectLocation.trim();
        final loginLocation = Uri(
          path: AppRoutes.login,
          queryParameters:
              normalizedRedirect.isEmpty ||
                  normalizedRedirect.startsWith(AppRoutes.login)
              ? null
              : <String, String>{'redirect': normalizedRedirect},
        ).toString();
        Future.microtask(() {
          final latestLocation = _safeCurrentRoute(router);
          if (latestLocation.startsWith(AppRoutes.login)) {
            return;
          }
          router.go(loginLocation);
        });
      },
    ),
  );
  dio.interceptors.add(
    CaptchaChallengeInterceptor(dio: dio, coordinator: captchaCoordinator),
  );
  dio.interceptors.add(ErrorMessageInterceptor());

  ref.onDispose(() {
    dio.close(force: true);
  });
  return dio;
});

String _safeCurrentRoute(GoRouter router) {
  try {
    return router.state.uri.toString();
  } catch (_) {
    return AppRoutes.home;
  }
}
