import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import 'app_message_service.dart';
import 'config/app_config_controller.dart';
import 'config/app_config_state.dart';
import 'config/app_theme_mode.dart';
import '../features/lyrics/presentation/providers/lyrics_providers.dart';
import '../features/online/presentation/providers/online_providers.dart';
import 'i18n/app_i18n.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'startup/app_startup_provider.dart';
import 'theme/app_theme.dart';

class HeMusicApp extends ConsumerWidget {
  const HeMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    final isTestBinding = bindingName.contains('TestWidgetsFlutterBinding');
    if (!isTestBinding) ref.watch(lyricsPrefetchBindingProvider);
    final appRouter = ref.watch(appRouterProvider);
    final appConfig = ref.watch(appConfigProvider);
    return MaterialApp.router(
      title: AppI18n.t(appConfig, 'app.title'),
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      themeMode: _toThemeMode(appConfig.themeMode),
      theme: AppTheme.light(appConfig.themeAccent),
      darkTheme: AppTheme.dark(appConfig.themeAccent),
      locale: Locale(appConfig.localeCode),
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        final gated = isTestBinding
            ? content
            : _AppStartupGate(appConfig: appConfig, child: content);
        if (!appConfig.isMonochrome) return gated;
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: gated,
        );
      },
    );
  }

  ThemeMode _toThemeMode(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }
}

class _AppStartupGate extends ConsumerWidget {
  const _AppStartupGate({required this.child, required this.appConfig});

  final Widget child;
  final AppConfigState appConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    final currentLocation = _currentLocation(context);
    final bypassStartupGate =
        currentLocation.startsWith(AppRoutes.login) ||
        currentLocation.startsWith(AppRoutes.captcha);
    return startup.when(
      data: (_) => child,
      loading: () {
        if (bypassStartupGate) {
          return child;
        }
        return _StartupScaffold(
          title: 'HE MUSIC',
          subtitle: '正在同步在线平台与会话状态',
          body: const _StartupLoadingBody(),
        );
      },
      error: (error, _) {
        if (bypassStartupGate || _isUnauthorizedError(error)) {
          return child;
        }
        return _StartupScaffold(
          title: '启动失败',
          subtitle: _describeStartupError(error),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FilledButton(
                onPressed: () async {
                  await ref.read(onlinePlatformsProvider.notifier).refresh();
                  ref.invalidate(appStartupProvider);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _currentLocation(BuildContext context) {
    try {
      return GoRouter.of(context).state.uri.toString();
    } catch (_) {
      return '';
    }
  }

  bool _isUnauthorizedError(Object error) {
    return error is DioException && error.response?.statusCode == 401;
  }

  String _describeStartupError(Object error) {
    if (error is StateError) {
      final message = error.message.toString().trim();
      return message.isEmpty ? '初始化失败，请重试。' : message;
    }
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => '网络连接超时，请检查网络后重试。',
        DioExceptionType.connectionError => '网络连接失败，请检查网络或域名解析后重试。',
        DioExceptionType.badCertificate => '证书校验失败，请检查网络环境后重试。',
        DioExceptionType.badResponse =>
          '服务响应异常（${error.response?.statusCode ?? '-'}），请稍后重试。',
        DioExceptionType.cancel => '请求已取消，请重试。',
        DioExceptionType.unknown => '网络异常，请检查网络后重试。',
      };
    }
    return '初始化失败，请重试。';
  }
}

class _StartupScaffold extends StatelessWidget {
  const _StartupScaffold({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String title;
  final String subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              theme.colorScheme.surface,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.24),
              theme.colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.32,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.56,
                          ),
                        ),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 34,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 3.2,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      body,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupLoadingBody extends StatelessWidget {
  const _StartupLoadingBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        const SizedBox(height: 16),
        Text(
          '首次进入会稍慢一些，完成后会常驻缓存。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
