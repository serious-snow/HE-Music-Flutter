import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('load should return saved config values', () async {
    const dataSource = AppConfigDataSource();
    await dataSource.save(
      AppConfigState.initial.copyWith(
        themeMode: AppThemeMode.dark,
        themeAccent: AppThemeAccent.ocean,
        isMonochrome: true,
        localeCode: 'en',
        onlineAudioQualityPreference: AppOnlineAudioQuality.flac,
        lastSelectedOnlineAudioQualityName: 'sq',
        autoCheckUpdates: true,
        authToken: 'token',
      ),
    );

    final state = await dataSource.load();

    expect(state.themeMode, AppThemeMode.dark);
    expect(state.themeAccent, AppThemeAccent.ocean);
    expect(state.isMonochrome, isTrue);
    expect(state.localeCode, 'en');
    expect(state.onlineAudioQualityPreference, AppOnlineAudioQuality.flac);
    expect(state.lastSelectedOnlineAudioQualityName, 'sq');
    expect(state.autoCheckUpdates, isTrue);
    expect(state.authToken, 'token');
  });

  test('load should enable autoCheckUpdates by default', () async {
    const dataSource = AppConfigDataSource();

    final state = await dataSource.load();

    expect(state.autoCheckUpdates, isTrue);
  });
}
