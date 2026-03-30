import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_message_service.dart';
import '../config/app_config_controller.dart';
import '../config/app_config_state.dart';
import '../i18n/app_i18n.dart';
import '../../features/update/domain/entities/update_state.dart';
import '../../features/update/presentation/providers/update_providers.dart';

class AppAutoUpdateGate extends ConsumerStatefulWidget {
  const AppAutoUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppAutoUpdateGate> createState() => _AppAutoUpdateGateState();
}

class _AppAutoUpdateGateState extends ConsumerState<AppAutoUpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_checkOnStartup);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  Future<void> _checkOnStartup() async {
    if (_checked || !mounted) {
      return;
    }
    _checked = true;
    final config = await ref.read(appConfigDataSourceProvider).load();
    if (!mounted || !config.autoCheckUpdates) {
      return;
    }
    await ref.read(updateControllerProvider.notifier).checkForUpdates();
    if (!mounted) {
      return;
    }
    final updateState = ref.read(updateControllerProvider);
    if (updateState.status != UpdateStatus.available ||
        updateState.release == null) {
      ref.read(updateControllerProvider.notifier).resetStatus();
      return;
    }
    _showAvailableSnackBar(config, updateState);
  }

  void _showAvailableSnackBar(AppConfigState config, UpdateState updateState) {
    final release = updateState.release;
    if (release == null) {
      return;
    }
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) {
      ref.read(updateControllerProvider.notifier).resetStatus();
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${AppI18n.t(config, 'settings.about.available')} ${release.version.normalized}',
        ),
        action: SnackBarAction(
          label: AppI18n.t(config, 'settings.about.open_release'),
          onPressed: () {
            _openReleaseUrl(release.htmlUrl, config);
          },
        ),
      ),
    );
    ref.read(updateControllerProvider.notifier).resetStatus();
  }

  Future<void> _openReleaseUrl(String rawUrl, AppConfigState config) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      AppMessageService.showError(
        AppI18n.t(config, 'settings.about.open_failed'),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppMessageService.showError(
        AppI18n.t(config, 'settings.about.open_failed'),
      );
    }
  }
}
