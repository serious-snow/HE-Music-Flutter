import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';

void main() {
  test('app theme text styles do not use bold font weights', () {
    final theme = AppTheme.light(AppThemeAccent.forest);

    expect(
      theme.textTheme.headlineMedium?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
    expect(
      theme.textTheme.headlineSmall?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
    expect(
      theme.textTheme.titleLarge?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
    expect(
      theme.textTheme.titleMedium?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
    expect(
      theme.textTheme.titleSmall?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
    expect(
      theme.textTheme.labelLarge?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
  });

  test('app theme navigation labels do not use bold font weights', () {
    final theme = AppTheme.dark(AppThemeAccent.ocean);
    final labelStyle = theme.navigationBarTheme.labelTextStyle?.resolve(
      <WidgetState>{},
    );

    expect(
      labelStyle?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
  });
}
