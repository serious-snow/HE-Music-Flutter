import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_message_service.dart';
import '../config/app_config_controller.dart';
import '../config/app_config_state.dart';
import '../i18n/app_i18n.dart';
import '../../features/update/domain/entities/update_state.dart';
import '../../features/update/presentation/providers/update_providers.dart';
import '../../features/update/presentation/widgets/update_available_release_sheet.dart';

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
    await _showAvailableReleaseSheet(config, updateState);
  }

  Future<void> _showAvailableReleaseSheet(
    AppConfigState config,
    UpdateState updateState,
  ) async {
    final release = updateState.release;
    if (release == null) {
      return;
    }
    if (!mounted) {
      ref.read(updateControllerProvider.notifier).resetStatus();
      return;
    }
    await showUpdateAvailableReleaseSheet(
      context: context,
      config: config,
      release: release,
      onOpenUrl: (rawUrl) => _openReleaseUrl(rawUrl, config),
    );
    if (!mounted) {
      return;
    }
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
