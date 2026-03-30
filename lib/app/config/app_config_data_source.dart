import 'package:shared_preferences/shared_preferences.dart';

import 'app_config_state.dart';
import 'app_online_audio_quality.dart';
import 'app_theme_accent.dart';
import 'app_theme_mode.dart';

const _themeModeKey = 'app_config.theme_mode';
const _themeAccentKey = 'app_config.theme_accent';
const _monochromeKey = 'app_config.monochrome';
const _localeKey = 'app_config.locale';
const _onlineAudioQualityPreferenceKey =
    'app_config.online_audio_quality_preference';
const _lastSelectedOnlineAudioQualityNameKey =
    'app_config.last_selected_online_audio_quality';
const _autoCheckUpdatesKey = 'app_config.auto_check_updates';
const _authTokenKey = 'app_config.auth_token';

class AppConfigDataSource {
  const AppConfigDataSource();

  Future<AppConfigState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = _readAuthToken(
      prefs.getString(_authTokenKey),
      hasStoredValue: prefs.containsKey(_authTokenKey),
    );
    return AppConfigState.initial.copyWith(
      themeMode: _readThemeMode(prefs.getString(_themeModeKey)),
      themeAccent: AppThemeAccent.fromValue(prefs.getString(_themeAccentKey)),
      isMonochrome: prefs.getBool(_monochromeKey) ?? false,
      localeCode: _readLocaleCode(prefs.getString(_localeKey)),
      onlineAudioQualityPreference: AppOnlineAudioQuality.fromValue(
        prefs.getString(_onlineAudioQualityPreferenceKey),
      ),
      autoCheckUpdates: prefs.getBool(_autoCheckUpdatesKey) ?? false,
      lastSelectedOnlineAudioQualityName:
          _readLastSelectedOnlineAudioQualityName(
            prefs.getString(_lastSelectedOnlineAudioQualityNameKey),
          ),
      authToken: authToken,
      clearToken: prefs.containsKey(_authTokenKey) && authToken == null,
    );
  }

  Future<void> save(AppConfigState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, state.themeMode.name);
    await prefs.setString(_themeAccentKey, state.themeAccent.value);
    await prefs.setBool(_monochromeKey, state.isMonochrome);
    await prefs.setString(_localeKey, state.localeCode);
    await prefs.setString(
      _onlineAudioQualityPreferenceKey,
      state.onlineAudioQualityPreference.value,
    );
    await prefs.setBool(_autoCheckUpdatesKey, state.autoCheckUpdates);
    final lastSelected = state.lastSelectedOnlineAudioQualityName?.trim();
    if (lastSelected == null || lastSelected.isEmpty) {
      await prefs.remove(_lastSelectedOnlineAudioQualityNameKey);
    } else {
      await prefs.setString(
        _lastSelectedOnlineAudioQualityNameKey,
        lastSelected,
      );
    }
    final authToken = state.authToken?.trim() ?? '';
    await prefs.setString(_authTokenKey, authToken);
  }

  String? _readLastSelectedOnlineAudioQualityName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _readAuthToken(String? value, {required bool hasStoredValue}) {
    if (!hasStoredValue) {
      return null;
    }
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  AppThemeMode _readThemeMode(String? value) {
    for (final item in AppThemeMode.values) {
      if (item.name == value) {
        return item;
      }
    }
    return AppConfigState.initial.themeMode;
  }

  String _readLocaleCode(String? value) {
    if (value == 'zh' || value == 'en') {
      return value!;
    }
    return AppConfigState.initial.localeCode;
  }
}
