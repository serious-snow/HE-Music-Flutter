import 'app_environment.dart';
import 'app_online_audio_quality.dart';
import 'app_theme_accent.dart';
import 'app_theme_mode.dart';

class AppConfigState {
  const AppConfigState({
    required this.apiBaseUrl,
    required this.themeMode,
    required this.themeAccent,
    required this.isMonochrome,
    required this.localeCode,
    required this.onlineAudioQualityPreference,
    this.lastSelectedOnlineAudioQualityName,
    this.authToken,
  });

  final String apiBaseUrl;
  final AppThemeMode themeMode;
  final AppThemeAccent themeAccent;
  final bool isMonochrome;
  final String localeCode;
  final AppOnlineAudioQuality onlineAudioQualityPreference;
  final String? lastSelectedOnlineAudioQualityName;
  final String? authToken;

  AppConfigState copyWith({
    String? apiBaseUrl,
    AppThemeMode? themeMode,
    AppThemeAccent? themeAccent,
    bool? isMonochrome,
    String? localeCode,
    AppOnlineAudioQuality? onlineAudioQualityPreference,
    String? lastSelectedOnlineAudioQualityName,
    bool clearLastSelectedOnlineAudioQuality = false,
    String? authToken,
    bool clearToken = false,
  }) {
    return AppConfigState(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      themeMode: themeMode ?? this.themeMode,
      themeAccent: themeAccent ?? this.themeAccent,
      isMonochrome: isMonochrome ?? this.isMonochrome,
      localeCode: localeCode ?? this.localeCode,
      onlineAudioQualityPreference:
          onlineAudioQualityPreference ?? this.onlineAudioQualityPreference,
      lastSelectedOnlineAudioQualityName: clearLastSelectedOnlineAudioQuality
          ? null
          : lastSelectedOnlineAudioQualityName ??
                this.lastSelectedOnlineAudioQualityName,
      authToken: clearToken ? null : authToken ?? this.authToken,
    );
  }

  static final initial = AppConfigState(
    themeMode: AppThemeMode.system,
    themeAccent: AppThemeAccent.forest,
    isMonochrome: false,
    localeCode: 'zh',
    onlineAudioQualityPreference: AppOnlineAudioQuality.auto,
    apiBaseUrl: AppEnvironment.apiBaseUrl,
  );
}
