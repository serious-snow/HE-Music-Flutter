import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_mode.dart';
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
        mode: AppMode.localOnly,
        themeMode: AppThemeMode.dark,
        isMonochrome: true,
        localeCode: 'en',
      ),
    );

    final state = await dataSource.load();

    expect(state.mode, AppMode.localOnly);
    expect(state.themeMode, AppThemeMode.dark);
    expect(state.isMonochrome, isTrue);
    expect(state.localeCode, 'en');
  });
}
