import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/data/datasources/search_history_data_source.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_page.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_queue_sheet.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('online search opens desktop queue panel on wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildOnlineSearchApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnlineSearchPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isTrue);
    expect(
      find.byKey(const ValueKey<String>('player-queue-desktop-panel')),
      findsOneWidget,
    );
    expect(find.byType(PlayerQueueSheet), findsNothing);
  });

  testWidgets('online search keeps mobile queue bottom sheet behavior', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildOnlineSearchApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnlineSearchPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isFalse);
    expect(
      find.byKey(const ValueKey<String>('player-queue-desktop-panel')),
      findsNothing,
    );
    expect(find.byType(PlayerQueueSheet), findsOneWidget);
  });
}

Widget _buildOnlineSearchApp() {
  return ProviderScope(
    overrides: <Override>[
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_MiniPlayerTestController.new),
      onlinePlatformsProvider.overrideWith(_SearchPlatformsController.new),
      onlineApiClientProvider.overrideWithValue(_SearchPageOnlineApiClient()),
      searchHistoryDataSourceProvider.overrideWithValue(
        const _SearchHistoryDataSourceStub(),
      ),
      searchDefaultPlaceholderProvider.overrideWith(
        _StaticSearchDefaultPlaceholderController.new,
      ),
    ],
    child: const MaterialApp(home: OnlineSearchPage(platform: 'qq')),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}

class _MiniPlayerTestController extends PlayerController {
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

class _SearchPlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag:
            PlatformFeatureSupportFlag.getSearchHotkey |
            PlatformFeatureSupportFlag.comprehensiveSearch |
            PlatformFeatureSupportFlag.searchSong |
            PlatformFeatureSupportFlag.searchPlaylist,
      ),
    ];
  }
}

class _SearchPageOnlineApiClient extends OnlineApiClient {
  _SearchPageOnlineApiClient() : super(Dio());

  @override
  Future<List<String>> fetchHotKeywords({String? platform}) async {
    return const <String>['热门'];
  }

  @override
  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({
    String? platform,
  }) async {
    return const <SearchDefaultEntry>[
      SearchDefaultEntry(key: '周杰伦', description: '稻香'),
    ];
  }
}

class _SearchHistoryDataSourceStub extends SearchHistoryDataSource {
  const _SearchHistoryDataSourceStub();

  @override
  Future<List<String>> listKeywords() async {
    return const <String>['周杰伦'];
  }
}

class _StaticSearchDefaultPlaceholderController
    extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() {
    return const SearchDefaultPlaceholderState(
      entries: <SearchDefaultEntry>[
        SearchDefaultEntry(key: '周杰伦', description: '稻香'),
      ],
      currentIndex: 0,
    );
  }
}
