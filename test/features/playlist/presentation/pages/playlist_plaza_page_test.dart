import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/playlist/data/datasources/playlist_plaza_api_client.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_category_group.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_plaza_page_result.dart';
import 'package:he_music_flutter/features/playlist/presentation/pages/playlist_plaza_page.dart';
import 'package:he_music_flutter/features/playlist/presentation/providers/playlist_plaza_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';

void main() {
  const allCategoriesLabels = <String>['全部分类', 'All Categories'];

  testWidgets(
    'playlist plaza shows loading skeleton before first platform load',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            onlinePlatformsProvider.overrideWith(
              _DelayedOnlinePlatformsController.new,
            ),
            playlistPlazaApiClientProvider.overrideWithValue(
              _FakePlaylistPlazaApiClient(),
            ),
          ],
          child: const MaterialApp(home: PlaylistPlazaPage()),
        ),
      );

      expect(find.byType(PlazaPlatformTabsSkeleton), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 140));
      await tester.pump();

      expect(find.text('QQ'), findsWidgets);
      expect(find.text('流行'), findsOneWidget);
      expect(find.text('今日推荐'), findsOneWidget);
    },
  );

  testWidgets('playlist plaza opens desktop queue panel on wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_QueuePlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _DelayedOnlinePlatformsController.new,
          ),
          playlistPlazaApiClientProvider.overrideWithValue(
            _FakePlaylistPlazaApiClient(),
          ),
        ],
        child: const MaterialApp(home: PlaylistPlazaPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.queue_music_rounded).last);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlaylistPlazaPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isTrue);
    expect(
      find.byKey(const ValueKey<String>('player-queue-desktop-panel')),
      findsOneWidget,
    );
  });

  testWidgets('playlist plaza shows dialog for all categories on wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _DelayedOnlinePlatformsController.new,
          ),
          playlistPlazaApiClientProvider.overrideWithValue(
            _FakePlaylistPlazaApiClient(),
          ),
        ],
        child: const MaterialApp(home: PlaylistPlazaPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      allCategoriesLabels
          .map((label) => find.text(label))
          .where((finder) => finder.evaluate().isNotEmpty)
          .length,
      1,
    );
    expect(find.text('流行'), findsWidgets);
    expect(find.text('摇滚'), findsWidgets);
    expect(find.text('民谣'), findsWidgets);
  });

  testWidgets('playlist plaza dialog for all categories has close button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _DelayedOnlinePlatformsController.new,
          ),
          playlistPlazaApiClientProvider.overrideWithValue(
            _FakePlaylistPlazaApiClient(),
          ),
        ],
        child: const MaterialApp(home: PlaylistPlazaPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('playlist-plaza-categories-close')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('playlist-plaza-categories-close')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    for (final label in allCategoriesLabels) {
      expect(find.text(label), findsNothing);
    }
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial;
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

  @override
  Future<void> initialize() async {}
}

class _QueuePlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'song-1',
        title: '测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        platform: 'qq',
        links: <LinkInfo>[
          LinkInfo(
            name: 'SQ',
            quality: 500,
            format: 'mp3',
            size: '3145728',
            url: 'https://example.com/song-1.mp3',
          ),
        ],
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}
}

class _DelayedOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag:
            PlatformFeatureSupportFlag.getTagList |
            PlatformFeatureSupportFlag.getTagPlaylist,
      ),
    ];
  }
}

class _FakePlaylistPlazaApiClient extends PlaylistPlazaApiClient {
  _FakePlaylistPlazaApiClient() : super(Dio());

  @override
  Future<List<PlaylistCategoryGroup>> fetchCategories({
    required String platform,
  }) async {
    return <PlaylistCategoryGroup>[
      PlaylistCategoryGroup(
        name: '推荐',
        categories: <CategoryInfo>[
          CategoryInfo(name: '流行', id: 'pop', platform: platform),
          CategoryInfo(name: '摇滚', id: 'rock', platform: platform),
          CategoryInfo(name: '民谣', id: 'folk', platform: platform),
        ],
      ),
      PlaylistCategoryGroup(
        name: '语种',
        categories: <CategoryInfo>[
          CategoryInfo(name: '华语', id: 'cn', platform: platform),
          CategoryInfo(name: '欧美', id: 'en', platform: platform),
        ],
      ),
    ];
  }

  @override
  Future<PlaylistPlazaPageResult> fetchCategoryPlaylists({
    required String platform,
    required String categoryId,
    int pageIndex = 1,
    int pageSize = 30,
    String? lastId,
  }) async {
    return PlaylistPlazaPageResult(
      list: <PlaylistInfo>[
        PlaylistInfo(
          name: '今日推荐',
          id: 'playlist-1',
          cover: '',
          creator: '测试账号',
          songCount: '20',
          playCount: '1234',
          platform: platform,
          description: '',
          songs: const <SongInfo>[],
          categories: <CategoryInfo>[
            CategoryInfo(name: '流行', id: categoryId, platform: platform),
          ],
        ),
      ],
      hasMore: false,
      lastId: '',
    );
  }
}
