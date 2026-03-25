import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/ranking/presentation/pages/ranking_list_page.dart';

void main() {
  testWidgets(
    'ranking page should not treat loading platforms as empty platforms',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            onlinePlatformsProvider.overrideWith((ref) async {
              await Future<void>.delayed(const Duration(milliseconds: 200));
              return _fakePlatforms;
            }),
          ],
          child: const MaterialApp(home: RankingListPage()),
        ),
      );

      expect(find.text('没有可用平台'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('QQ'), findsWidgets);
    },
  );
}

final List<OnlinePlatform> _fakePlatforms = <OnlinePlatform>[
  OnlinePlatform(
    id: 'qq',
    name: 'QQ音乐',
    shortName: 'QQ',
    status: 1,
    featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
  ),
];
