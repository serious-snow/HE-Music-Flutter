import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets('settings page shows about entry', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );

    expect(find.text('关于'), findsOneWidget);
  });

  testWidgets('settings tile title does not use bold font weight', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );

    final aboutTitle = tester.widget<Text>(find.text('关于'));

    expect(
      aboutTitle.style?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
  });

  testWidgets('settings page places about entry below monochrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );

    final monochromeTopLeft = tester.getTopLeft(find.text('黑白模式'));
    final aboutTopLeft = tester.getTopLeft(find.text('关于'));

    expect(aboutTopLeft.dy, greaterThan(monochromeTopLeft.dy));
  });

  testWidgets('settings page toggles auto update check switch', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('自动检查更新'), findsOneWidget);
    expect(container.read(appConfigProvider).autoCheckUpdates, isFalse);

    await tester.tap(find.text('自动检查更新'));
    await tester.pump();

    expect(container.read(appConfigProvider).autoCheckUpdates, isTrue);
  });
}
