import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config_data_source.dart';
import 'app_config_state.dart';
import 'app_online_audio_quality.dart';
import 'app_theme_accent.dart';
import 'app_theme_mode.dart';

class AppConfigController extends Notifier<AppConfigState> {
  bool _hydrated = false;

  @override
  AppConfigState build() {
    _hydrate();
    return AppConfigState.initial;
  }

  void cycleThemeMode() {
    final next = switch (state.themeMode) {
      AppThemeMode.system => AppThemeMode.light,
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.system,
    };
    _update(state.copyWith(themeMode: next));
  }

  void setThemeMode(AppThemeMode mode) {
    _update(state.copyWith(themeMode: mode));
  }

  void setThemeAccent(AppThemeAccent accent) {
    _update(state.copyWith(themeAccent: accent));
  }

  void toggleMonochrome() {
    _update(state.copyWith(isMonochrome: !state.isMonochrome));
  }

  void setLocaleCode(String localeCode) {
    if (localeCode != 'zh' && localeCode != 'en') {
      return;
    }
    _update(state.copyWith(localeCode: localeCode));
  }

  void setOnlineAudioQualityPreference(AppOnlineAudioQuality quality) {
    _update(state.copyWith(onlineAudioQualityPreference: quality));
  }

  void setLastSelectedOnlineAudioQualityName(String qualityName) {
    final normalized = qualityName.trim();
    if (normalized.isEmpty) {
      return;
    }
    _update(state.copyWith(lastSelectedOnlineAudioQualityName: normalized));
  }

  void setAuthToken(String token) {
    _update(state.copyWith(authToken: token.trim()));
  }

  void clearAuthToken() {
    _update(state.copyWith(clearToken: true));
  }

  void _update(AppConfigState next, {bool persist = true}) {
    state = next;
    if (!persist) {
      return;
    }
    _persist(next);
  }

  void _hydrate() {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    Future.microtask(() async {
      final loaded = await ref.read(appConfigDataSourceProvider).load();
      state = state.copyWith(
        themeMode: loaded.themeMode,
        themeAccent: loaded.themeAccent,
        isMonochrome: loaded.isMonochrome,
        localeCode: loaded.localeCode,
        onlineAudioQualityPreference: loaded.onlineAudioQualityPreference,
        lastSelectedOnlineAudioQualityName:
            loaded.lastSelectedOnlineAudioQualityName,
        authToken: loaded.authToken,
        clearToken: loaded.authToken == null,
      );
    });
  }

  void _persist(AppConfigState value) {
    Future.microtask(() async {
      await ref.read(appConfigDataSourceProvider).save(value);
    });
  }
}

final appConfigDataSourceProvider = Provider<AppConfigDataSource>((ref) {
  return const AppConfigDataSource();
});

final appConfigProvider = NotifierProvider<AppConfigController, AppConfigState>(
  AppConfigController.new,
);
