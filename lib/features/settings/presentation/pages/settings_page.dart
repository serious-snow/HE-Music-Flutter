import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_online_audio_quality.dart';
import '../../../../app/config/app_theme_accent.dart';
import '../../../../app/config/app_theme_mode.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final preference = config.onlineAudioQualityPreference;
    final lastSelected = config.lastSelectedOnlineAudioQualityName;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: AppI18n.t(config, 'common.back'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(AppI18n.t(config, 'settings.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _SettingsSection(
            children: <Widget>[
              _SettingsTile(
                icon: Icons.high_quality_rounded,
                title: AppI18n.t(config, 'settings.audio_quality'),
                subtitle: _qualitySubtitle(preference, lastSelected),
                trailingText: preference.label,
                onTap: () => _openOnlineAudioQualitySheet(config),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            children: <Widget>[
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: AppI18n.t(config, 'settings.theme'),
                subtitle: _themeModeLabel(config.themeMode),
                onTap: () => _openThemeModeSheet(config.themeMode),
              ),
              _SettingsTile(
                icon: Icons.color_lens_outlined,
                title: AppI18n.t(config, 'settings.theme_accent'),
                subtitle: AppI18n.format(
                  config,
                  'settings.theme_accent.current',
                  <String, String>{'value': config.themeAccent.label},
                ),
                trailing: _AccentDot(color: _accentPreviewColor(config)),
                onTap: () => _openThemeAccentSheet(config.themeAccent),
              ),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: AppI18n.t(config, 'settings.language'),
                subtitle: config.localeCode == 'zh'
                    ? AppI18n.t(config, 'settings.lang.zh_cn')
                    : AppI18n.t(config, 'settings.lang.en'),
                onTap: () => _openLanguageSheet(config.localeCode),
              ),
              SwitchListTile.adaptive(
                value: config.isMonochrome,
                onChanged: (_) =>
                    ref.read(appConfigProvider.notifier).toggleMonochrome(),
                secondary: const Icon(Icons.contrast_rounded),
                title: Text(AppI18n.t(config, 'settings.monochrome')),
                subtitle: Text(AppI18n.t(config, 'settings.monochrome.desc')),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
              ),
              SwitchListTile.adaptive(
                value: config.autoCheckUpdates,
                onChanged: (value) => ref
                    .read(appConfigProvider.notifier)
                    .setAutoCheckUpdates(value),
                secondary: const Icon(Icons.system_update_alt_rounded),
                title: Text(AppI18n.t(config, 'settings.auto_check_updates')),
                subtitle: Text(
                  AppI18n.t(config, 'settings.auto_check_updates.desc'),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: AppI18n.t(config, 'settings.about'),
                subtitle: AppI18n.t(config, 'settings.about.desc'),
                onTap: () => context.push(AppRoutes.about),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            children: <Widget>[
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: AppI18n.t(config, 'settings.logout'),
                subtitle: AppI18n.t(config, 'settings.logout.desc'),
                destructive: true,
                onTap: _clearToken,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _clearToken() {
    ref.read(appConfigProvider.notifier).clearAuthToken();
    final config = ref.read(appConfigProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppI18n.t(config, 'settings.logout.done'))),
    );
  }

  void _openThemeModeSheet(AppThemeMode currentMode) {
    final controller = ref.read(appConfigProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final item in AppThemeMode.values)
                ListTile(
                  title: Text(_themeModeLabel(item)),
                  trailing: currentMode == item
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    controller.setThemeMode(item);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _openLanguageSheet(String currentLocaleCode) {
    final controller = ref.read(appConfigProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  AppI18n.tByLocaleCode(
                    currentLocaleCode,
                    'settings.lang.zh_cn',
                  ),
                ),
                trailing: currentLocaleCode == 'zh'
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  controller.setLocaleCode('zh');
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                title: Text(
                  AppI18n.tByLocaleCode(currentLocaleCode, 'settings.lang.en'),
                ),
                trailing: currentLocaleCode == 'en'
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  controller.setLocaleCode('en');
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openThemeAccentSheet(AppThemeAccent currentAccent) {
    final controller = ref.read(appConfigProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final item in AppThemeAccent.values)
                ListTile(
                  leading: _AccentDot(color: item.lightSeed),
                  title: Text(item.label),
                  trailing: currentAccent == item
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    controller.setThemeAccent(item);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _openOnlineAudioQualitySheet(AppConfigState config) {
    final controller = ref.read(appConfigProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final item in AppOnlineAudioQuality.values)
                ListTile(
                  leading: const Icon(Icons.graphic_eq_rounded),
                  title: Text(item.label),
                  subtitle: Text(
                    item.isAuto
                        ? AppOnlineAudioQuality.autoDescription(
                            lastSelectedQualityName:
                                config.lastSelectedOnlineAudioQualityName,
                          )
                        : item.tip,
                  ),
                  trailing: config.onlineAudioQualityPreference == item
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    controller.setOnlineAudioQualityPreference(item);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  String _qualitySubtitle(
    AppOnlineAudioQuality preference,
    String? lastSelected,
  ) {
    if (!preference.isAuto) {
      return preference.tip;
    }
    return AppOnlineAudioQuality.autoDescription(
      lastSelectedQualityName: lastSelected,
    );
  }

  String _themeModeLabel(AppThemeMode mode) {
    final config = ref.read(appConfigProvider);
    return switch (mode) {
      AppThemeMode.system => AppI18n.t(config, 'my.theme.system'),
      AppThemeMode.light => AppI18n.t(config, 'my.theme.light'),
      AppThemeMode.dark => AppI18n.t(config, 'my.theme.dark'),
    };
  }

  Color _accentPreviewColor(AppConfigState config) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? config.themeAccent.darkSeed
        : config.themeAccent.lightSeed;
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingText;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      trailing:
          trailing ??
          (trailingText == null
              ? const Icon(Icons.chevron_right_rounded)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      trailingText!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                )),
      onTap: onTap,
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}
