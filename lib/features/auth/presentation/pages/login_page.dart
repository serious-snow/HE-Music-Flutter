import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/startup/app_startup_provider.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../online/presentation/providers/online_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({required this.redirectLocation, super.key});

  final String? redirectLocation;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  Timer? _authPollTimer;
  bool _submitting = false;
  bool _loadingAuthProviders = true;
  bool _oauthBusy = false;
  bool _oauthPollingInFlight = false;
  List<String> _authProviders = const <String>[];
  String? _authProviderError;
  String? _oauthProvider;
  String? _oauthState;
  String? _oauthStatusText;
  int _oauthExpireAt = 0;
  int _oauthCheckInterval = 0;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    Future.microtask(_loadAuthProviders);
  }

  @override
  void dispose() {
    _authPollTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    final oauthStatusText = _oauthStatusText?.trim() ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.t(config, 'auth.login.title')),
        leading: IconButton(
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppI18n.t(config, 'common.back'),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              theme.colorScheme.surface,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.52),
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
            ],
          ),
        ),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            enabled: !_oauthBusy,
                            decoration: InputDecoration(
                              labelText: AppI18n.t(config, 'auth.login.username'),
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            enabled: !_oauthBusy,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: AppI18n.t(config, 'auth.login.password'),
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  (_submitting || _oauthBusy) ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                _submitting
                                    ? AppI18n.t(config, 'auth.login.submitting')
                                    : AppI18n.t(config, 'auth.login.submit'),
                              ),
                            ),
                          ),
                          if (_loadingAuthProviders ||
                              _authProviders.isNotEmpty ||
                              (_authProviderError?.trim().isNotEmpty ?? false))
                            ...<Widget>[
                              const SizedBox(height: 18),
                              Divider(
                                height: 1,
                                color: theme.dividerColor.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 16),
                              if (_loadingAuthProviders)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              else if (_authProviders.isNotEmpty)
                                Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: _authProviders.map((provider) {
                                      return OutlinedButton(
                                        onPressed: _oauthBusy
                                            ? null
                                            : () => _startOAuth(provider),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            _AuthProviderIcon(
                                              provider: provider,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(provider),
                                          ],
                                        ),
                                      );
                                    }).toList(growable: false),
                                  ),
                                )
                              else if ((_authProviderError?.trim().isNotEmpty ??
                                  false))
                                Text(
                                  _authProviderError!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                ),
                            ],
                        ],
                      ),
                    ),
                    if (oauthStatusText.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    _oauthProvider == null
                                        ? AppI18n.t(config, 'auth.oauth.title')
                                        : '${AppI18n.t(config, 'auth.oauth.title')} · ${_oauthProvider!}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (_oauthBusy)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(oauthStatusText),
                            if (_oauthBusy) ...<Widget>[
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _cancelOAuthFlow,
                                child: Text(AppI18n.t(config, 'auth.oauth.cancel')),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadAuthProviders() async {
    try {
      final providers = await ref.read(onlineApiClientProvider).listAuthProviders();
      if (!mounted) {
        return;
      }
      setState(() {
        _authProviders = providers;
        _loadingAuthProviders = false;
        _authProviderError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingAuthProviders = false;
        _authProviderError =
            NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.load_failed');
      });
    }
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.trim().isEmpty) {
      AppMessageService.showError(
        AppI18n.t(ref.read(appConfigProvider), 'auth.login.empty'),
      );
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .login(username: username, password: password);
      await _finishLoginFlow();
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.login.failed'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _startOAuth(String provider) async {
    _cancelOAuthFlow(clearStatusOnly: true);
    setState(() {
      _oauthBusy = true;
      _oauthProvider = provider;
      _oauthStatusText = AppI18n.t(
        ref.read(appConfigProvider),
        'auth.oauth.get_url',
      );
      _oauthState = null;
      _oauthExpireAt = 0;
      _oauthCheckInterval = 0;
    });
    try {
      final result = await ref
          .read(onlineApiClientProvider)
          .getAuthCodeUrl(provider: provider);
      final authUrl = Uri.tryParse(result.url);
      if (result.url.isEmpty || result.state.isEmpty || authUrl == null) {
        throw StateError(
          AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.invalid_url'),
        );
      }
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError(
          AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.open_failed'),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _oauthState = result.state;
        _oauthExpireAt = result.expireAt;
        _oauthCheckInterval = result.checkInterval;
        _oauthStatusText = AppI18n.t(
          ref.read(appConfigProvider),
          'auth.oauth.opened',
        );
      });
      _scheduleAuthPolling(result.checkInterval);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _cancelOAuthFlow(
        statusText:
            NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.start_failed'),
      );
    }
  }

  void _scheduleAuthPolling(int checkInterval) {
    _authPollTimer?.cancel();
    final seconds = checkInterval > 0 ? checkInterval : 2;
    _authPollTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_pollAuthStatus());
    });
  }

  Future<void> _pollAuthStatus() async {
    final state = _oauthState?.trim() ?? '';
    if (!_oauthBusy || state.isEmpty || _oauthPollingInFlight) {
      return;
    }
    if (_isOAuthExpired()) {
      _cancelOAuthFlow(
        statusText: AppI18n.t(
          ref.read(appConfigProvider),
          'auth.oauth.expired',
        ),
      );
      return;
    }
    _oauthPollingInFlight = true;
    try {
      final result = await ref
          .read(onlineApiClientProvider)
          .getAuthStatus(state: state);
      if (!mounted) {
        return;
      }
      if (result.expireAt > 0) {
        _oauthExpireAt = result.expireAt;
      }
      if (result.checkInterval > 0) {
        _oauthCheckInterval = result.checkInterval;
      }
      final normalizedStatus = result.status.trim().toLowerCase();
      if (_isOAuthSuccessStatus(normalizedStatus)) {
        setState(() {
          _oauthStatusText = AppI18n.t(
            ref.read(appConfigProvider),
            'auth.oauth.success',
          );
        });
        final token = await ref
            .read(onlineApiClientProvider)
            .exchangeAuthResult(state: state);
        if (token.isEmpty) {
          throw StateError(
            AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.result_invalid'),
          );
        }
        await ref.read(onlineControllerProvider.notifier).loginWithToken(token);
        if (!mounted) {
          return;
        }
        _cancelOAuthFlow(clearStatusOnly: true);
        await _finishLoginFlow();
        return;
      }
      if (_isOAuthFailedStatus(normalizedStatus)) {
        final message = result.error.trim().isNotEmpty
            ? result.error.trim()
            : AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.failed');
        _cancelOAuthFlow(statusText: message);
        return;
      }
      if (_isOAuthExpiredStatus(normalizedStatus)) {
        _cancelOAuthFlow(
          statusText: AppI18n.t(
            ref.read(appConfigProvider),
            'auth.oauth.expired',
          ),
        );
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _oauthStatusText = AppI18n.t(
          ref.read(appConfigProvider),
          'auth.oauth.waiting',
        );
      });
      _scheduleAuthPolling(result.checkInterval > 0 ? result.checkInterval : _oauthCheckInterval);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _cancelOAuthFlow(
        statusText:
            NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.status_failed'),
      );
    } finally {
      _oauthPollingInFlight = false;
    }
  }

  bool _isOAuthSuccessStatus(String status) {
    return status == 'success';
  }

  bool _isOAuthFailedStatus(String status) {
    return status == 'failed';
  }

  bool _isOAuthExpiredStatus(String status) {
    return status == 'expired';
  }

  bool _isOAuthExpired() {
    final expireAt = _oauthExpireAt;
    if (expireAt <= 0) {
      return false;
    }
    final dateTime = expireAt >= 1000000000000
        ? DateTime.fromMillisecondsSinceEpoch(expireAt)
        : DateTime.fromMillisecondsSinceEpoch(expireAt * 1000);
    return DateTime.now().isAfter(dateTime);
  }

  void _cancelOAuthFlow({
    String? statusText,
    bool clearStatusOnly = false,
  }) {
    _authPollTimer?.cancel();
    _authPollTimer = null;
    _oauthPollingInFlight = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _oauthBusy = false;
      _oauthState = null;
      _oauthExpireAt = 0;
      _oauthCheckInterval = 0;
      if (clearStatusOnly) {
        _oauthStatusText = null;
        _oauthProvider = null;
      } else {
        _oauthStatusText = statusText;
      }
    });
  }

  Future<void> _finishLoginFlow() async {
    await _reloadPlatformsIfNeeded();
    if (!mounted) {
      return;
    }
    final redirect = widget.redirectLocation?.trim() ?? '';
    if (redirect.isNotEmpty && !redirect.startsWith(AppRoutes.login)) {
      context.go(redirect);
      return;
    }
    context.go(AppRoutes.home);
  }

  Future<void> _reloadPlatformsIfNeeded() async {
    final platformsAsync = ref.read(onlinePlatformsProvider);
    final shouldReload =
        platformsAsync.hasError ||
        (platformsAsync.valueOrNull?.isEmpty ?? true);
    if (!shouldReload) {
      ref.invalidate(appStartupProvider);
      return;
    }
    ref.invalidate(appStartupProvider);
    await ref.read(onlinePlatformsProvider.notifier).refresh();
    final loaded = ref.read(onlinePlatformsProvider).valueOrNull;
    if (loaded == null || loaded.isEmpty) {
      ref.invalidate(appStartupProvider);
      await ref.read(onlinePlatformsProvider.notifier).refresh();
    }
  }

  void _handleBack() {
    _authPollTimer?.cancel();
    final redirect = widget.redirectLocation?.trim() ?? '';
    if (redirect.isNotEmpty && !redirect.startsWith(AppRoutes.login)) {
      context.go(redirect);
      return;
    }
    context.go(AppRoutes.home);
  }
}

class _AuthProviderIcon extends StatelessWidget {
  const _AuthProviderIcon({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final assetPath = _providerAssetPath(provider);
    if (assetPath == null) {
      return Icon(
        Icons.public_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return SvgPicture.asset(
      assetPath,
      width: 18,
      height: 18,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => Icon(
        Icons.public_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  String? _providerAssetPath(String rawProvider) {
    final normalized = rawProvider.trim().toLowerCase();
    return switch (normalized) {
      'linuxdo' => 'assets/icons/auth/linuxdo.svg',
      _ => null,
    };
  }
}
