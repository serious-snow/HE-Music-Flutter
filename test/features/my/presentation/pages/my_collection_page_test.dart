import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_collection_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/presentation/controllers/my_collection_controller.dart';
import 'package:he_music_flutter/features/my/presentation/pages/my_collection_page.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_collection_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

void main() {
  testWidgets('collection page opens desktop queue panel on wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          myCollectionControllerProvider.overrideWith(
            _TestMyCollectionController.new,
          ),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
        ],
        child: const MaterialApp(home: MyCollectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.queue_music_rounded).last);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyCollectionPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isTrue);
    expect(
      find.byKey(const ValueKey<String>('player-queue-desktop-panel')),
      findsOneWidget,
    );
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh');
  }
}

class _TestMyCollectionController extends MyCollectionController {
  @override
  MyCollectionState build() {
    return MyCollectionState.initial.copyWith(
      playlists: const <MyFavoriteItem>[
        MyFavoriteItem(
          id: 'playlist-1',
          platform: 'qq',
          type: MyFavoriteType.playlists,
          title: '测试歌单',
          subtitle: '测试作者',
          coverUrl: '',
          songCount: '10',
        ),
      ],
    );
  }

  @override
  Future<void> initialize() async {}
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'current-song',
        title: '正在播放',
        artist: '测试歌手',
        platform: 'qq',
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}
}
