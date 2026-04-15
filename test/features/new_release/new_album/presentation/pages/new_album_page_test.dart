import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/new_release/new_album/data/datasources/new_album_api_client.dart';
import 'package:he_music_flutter/features/new_release/new_album/presentation/pages/new_album_page.dart';
import 'package:he_music_flutter/features/new_release/new_album/presentation/providers/new_album_page_providers.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_page_result.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_tab.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('new album page renders album grid items', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          newAlbumApiClientProvider.overrideWithValue(_FakeNewAlbumApiClient()),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(home: NewAlbumPage(initialPlatform: 'qq')),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('QQ'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('年度新碟'), findsOneWidget);
  });

  testWidgets('new album page shows mini player', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          newAlbumApiClientProvider.overrideWithValue(_FakeNewAlbumApiClient()),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(home: NewAlbumPage(initialPlatform: 'qq')),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MiniPlayerBar), findsOneWidget);
  });

  testWidgets('new album page opens desktop queue panel on wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          newAlbumApiClientProvider.overrideWithValue(
            _QueueTestNewAlbumApiClient(),
          ),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(home: NewAlbumPage(initialPlatform: 'qq')),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.queue_music_rounded).last);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NewAlbumPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isTrue);
    expect(
      find.byKey(const ValueKey<String>('player-queue-desktop-panel')),
      findsOneWidget,
    );
  });
}

class _FakeNewAlbumApiClient extends NewAlbumApiClient {
  _FakeNewAlbumApiClient() : super(Dio());

  @override
  Future<List<NewReleaseTab>> fetchTabs({required String platform}) async {
    return <NewReleaseTab>[
      NewReleaseTab(id: 'recommend', name: '推荐', platform: platform),
    ];
  }

  @override
  Future<NewReleasePageResult<AlbumInfo>> fetchAlbums({
    required String platform,
    required String tabId,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    return NewReleasePageResult<AlbumInfo>(
      list: <AlbumInfo>[_buildAlbum(platform)],
      hasMore: false,
    );
  }
}

class _QueueTestNewAlbumApiClient extends NewAlbumApiClient {
  _QueueTestNewAlbumApiClient() : super(Dio());

  @override
  Future<List<NewReleaseTab>> fetchTabs({required String platform}) async {
    return <NewReleaseTab>[
      NewReleaseTab(id: 'recommend', name: '推荐', platform: platform),
    ];
  }

  @override
  Future<NewReleasePageResult<AlbumInfo>> fetchAlbums({
    required String platform,
    required String tabId,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    return const NewReleasePageResult<AlbumInfo>(
      list: <AlbumInfo>[],
      hasMore: false,
    );
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ Music',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag:
            PlatformFeatureSupportFlag.getNewAlbumTabList |
            PlatformFeatureSupportFlag.getNewAlbumList,
      ),
    ];
  }
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

AlbumInfo _buildAlbum(String platform) {
  return AlbumInfo(
    name: '年度新碟',
    id: 'album-1',
    cover: '',
    artists: const <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-1', name: '歌手'),
    ],
    songCount: '10',
    publishTime: '2026-04-15',
    songs: const <SongInfo>[],
    description: '',
    platform: platform,
    language: '',
    genre: '',
    type: 0,
    isFinished: true,
    playCount: '100',
  );
}
