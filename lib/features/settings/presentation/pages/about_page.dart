import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_environment.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../update/domain/entities/update_release.dart';
import '../../../update/domain/entities/update_state.dart';
import '../../../update/presentation/providers/update_providers.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateState>(updateControllerProvider, (previous, next) {
      if (previous?.status == next.status &&
          previous?.errorMessage == next.errorMessage &&
          previous?.release?.htmlUrl == next.release?.htmlUrl) {
        return;
      }
      switch (next.status) {
        case UpdateStatus.available:
          final release = next.release;
          if (release == null) {
            return;
          }
          Future<void>.microtask(() async {
            if (!mounted) {
              return;
            }
            await _showAvailableReleaseSheet(release);
            if (!mounted) {
              return;
            }
            ref.read(updateControllerProvider.notifier).resetStatus();
          });
          break;
        case UpdateStatus.latest:
          Future<void>.microtask(() {
            if (!mounted) {
              return;
            }
            _showMessage(
              AppI18n.t(ref.read(appConfigProvider), 'settings.about.latest'),
            );
            ref.read(updateControllerProvider.notifier).resetStatus();
          });
          break;
        case UpdateStatus.failure:
          Future<void>.microtask(() {
            if (!mounted) {
              return;
            }
            final config = ref.read(appConfigProvider);
            final message = _failureMessage(config, next.errorMessage);
            _showMessage(message);
            ref.read(updateControllerProvider.notifier).resetStatus();
          });
          break;
        case UpdateStatus.idle:
        case UpdateStatus.checking:
          break;
      }
    });
    final config = ref.watch(appConfigProvider);
    final appInfoAsync = ref.watch(currentAppInfoProvider);
    final updateState = ref.watch(updateControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: AppI18n.t(config, 'common.back'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(AppI18n.t(config, 'settings.about.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _AboutHero(
            appName: appInfoAsync.maybeWhen(
              data: (info) =>
                  info.appName.trim().isEmpty ? 'HE Music' : info.appName,
              orElse: () => 'HE Music',
            ),
            versionLabel: appInfoAsync.maybeWhen(
              data: (info) => info.versionLabel,
              orElse: () => '--',
            ),
            versionTitle: AppI18n.t(config, 'settings.about.current_version'),
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: Text(
                    AppI18n.t(config, 'settings.about.github_release'),
                  ),
                  subtitle: Text(_gitHubReleaseDescription(config)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: AppEnvironment.hasGitHubReleaseConfig,
                  onTap: AppEnvironment.hasGitHubReleaseConfig
                      ? () => _openUrl(_releasePageUrl)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: updateState.status == UpdateStatus.checking
                ? null
                : () => ref
                      .read(updateControllerProvider.notifier)
                      .checkForUpdates(),
            icon: updateState.status == UpdateStatus.checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_rounded),
            label: Text(
              updateState.status == UpdateStatus.checking
                  ? AppI18n.t(config, 'settings.about.checking')
                  : AppI18n.t(config, 'settings.about.check_update'),
            ),
          ),
        ],
      ),
    );
  }

  String get _releasePageUrl {
    if (!AppEnvironment.hasGitHubReleaseConfig) {
      return '';
    }
    return 'https://github.com/${AppEnvironment.githubOwner}/${AppEnvironment.githubRepo}/releases';
  }

  String _gitHubReleaseDescription(AppConfigState config) {
    if (!AppEnvironment.hasGitHubReleaseConfig) {
      return AppI18n.t(config, 'settings.about.unconfigured');
    }
    return '${AppEnvironment.githubOwner}/${AppEnvironment.githubRepo}';
  }

  String _failureMessage(AppConfigState config, String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) {
      return AppI18n.t(config, 'settings.about.check_failed');
    }
    if (normalized.contains('未配置 GitHub Release 仓库')) {
      return AppI18n.t(config, 'settings.about.unconfigured');
    }
    return normalized;
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    final config = ref.read(appConfigProvider);
    if (uri == null) {
      _showMessage(AppI18n.t(config, 'settings.about.open_failed'));
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showMessage(AppI18n.t(config, 'settings.about.open_failed'));
    }
  }

  Future<void> _showAvailableReleaseSheet(UpdateRelease release) async {
    final config = ref.read(appConfigProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final releaseNotes = release.releaseNotes.trim().isEmpty
            ? AppI18n.t(config, 'settings.about.release_notes.empty')
            : release.releaseNotes.trim();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppI18n.t(config, 'settings.about.available'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.new_releases_outlined),
                  title: Text(release.version.normalized),
                  subtitle: Text(_formatPublishedAt(release.publishedAt)),
                ),
                const SizedBox(height: 8),
                Text(
                  AppI18n.t(config, 'settings.about.release_notes'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(child: Text(releaseNotes)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(AppI18n.t(config, 'common.cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _openUrl(release.htmlUrl);
                        },
                        child: Text(
                          AppI18n.t(config, 'settings.about.open_release'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatPublishedAt(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero({
    required this.appName,
    required this.versionLabel,
    required this.versionTitle,
  });

  final String appName;
  final String versionLabel;
  final String versionTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          children: <Widget>[
            Image.asset(
              'assets/icons/favicon-512x512.png',
              key: const ValueKey<String>('about-logo'),
              width: 88,
              height: 88,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 18),
            Text(
              appName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              versionTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              versionLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
