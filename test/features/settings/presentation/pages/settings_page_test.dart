import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets('settings page shows about entry', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );

    expect(find.text('关于'), findsOneWidget);
  });

  testWidgets('settings page places about entry below monochrome', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );

    final monochromeTopLeft = tester.getTopLeft(find.text('黑白模式'));
    final aboutTopLeft = tester.getTopLeft(find.text('关于'));

    expect(aboutTopLeft.dy, greaterThan(monochromeTopLeft.dy));
  });
}
