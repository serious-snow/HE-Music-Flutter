import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';

void main() {
  test('light theme uses dark status bar icons', () {
    final theme = AppTheme.light(AppThemeAccent.cobalt);

    expect(
      theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      theme.appBarTheme.systemOverlayStyle?.statusBarBrightness,
      Brightness.light,
    );
    expect(
      theme.appBarTheme.systemOverlayStyle?.statusBarColor,
      Colors.transparent,
    );
  });

  test('dark theme uses light status bar icons', () {
    final theme = AppTheme.dark(AppThemeAccent.cobalt);

    expect(
      theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.light,
    );
    expect(
      theme.appBarTheme.systemOverlayStyle?.statusBarBrightness,
      Brightness.dark,
    );
    expect(
      theme.appBarTheme.systemOverlayStyle?.statusBarColor,
      Colors.transparent,
    );
  });
}
