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
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_group.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_detail.dart';
import 'package:he_music_flutter/features/ranking/domain/repositories/ranking_repository.dart';
import 'package:he_music_flutter/features/ranking/presentation/pages/ranking_list_page.dart';
import 'package:he_music_flutter/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('ranking list opens desktop queue panel on wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildRankingListApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RankingListPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isTrue);
    expect(
      find.byKey(const ValueKey<String>('player-queue-desktop-panel')),
      findsOneWidget,
    );
  });
}

Widget _buildRankingListApp() {
  return ProviderScope(
    overrides: <Override>[
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_MiniPlayerTestController.new),
      onlinePlatformsProvider.overrideWith(_RankingPlatformsController.new),
      rankingRepositoryProvider.overrideWithValue(_RankingRepositoryStub()),
    ],
    child: const MaterialApp(home: RankingListPage()),
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

class _RankingPlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getTopList,
      ),
    ];
  }
}

class _RankingRepositoryStub implements RankingRepository {
  @override
  Future<List<RankingGroup>> fetchRankingGroups({required String platform}) {
    return Future.value(const <RankingGroup>[]);
  }

  @override
  Future<RankingDetail> fetchRankingDetail({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 100,
    String? lastId,
  }) {
    throw UnimplementedError();
  }
}
