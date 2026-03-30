import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/startup/app_auto_update_gate.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_state.dart';
import 'package:he_music_flutter/features/update/presentation/controllers/update_controller.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';

void main() {
  testWidgets('app auto update gate checks once when enabled', (tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: true),
        ),
        updateControllerProvider.overrideWith(_CountingUpdateController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AppAutoUpdateGate(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller =
        container.read(updateControllerProvider.notifier)
            as _CountingUpdateController;
    expect(controller.checkCount, 1);
  });

  testWidgets('app auto update gate skips check when disabled', (tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: false),
        ),
        updateControllerProvider.overrideWith(_CountingUpdateController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AppAutoUpdateGate(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller =
        container.read(updateControllerProvider.notifier)
            as _CountingUpdateController;
    expect(controller.checkCount, 0);
  });
}

class _FakeAppConfigDataSource extends AppConfigDataSource {
  const _FakeAppConfigDataSource({required this.autoCheckUpdates});

  final bool autoCheckUpdates;

  @override
  Future<AppConfigState> load() async {
    return AppConfigState.initial.copyWith(autoCheckUpdates: autoCheckUpdates);
  }
}

class _CountingUpdateController extends UpdateController {
  int checkCount = 0;

  @override
  UpdateState build() {
    return UpdateState.initial;
  }

  @override
  Future<void> checkForUpdates() async {
    checkCount += 1;
  }
}
