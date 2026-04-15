import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_comments_page.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

void main() {
  testWidgets('online comments page opens desktop queue panel on wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          onlineApiClientProvider.overrideWithValue(_FakeOnlineApiClient()),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
        ],
        child: const MaterialApp(
          home: OnlineCommentsPage(
            resourceId: 'song-1',
            resourceType: 'song',
            platform: 'qq',
            title: '测试歌曲',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.queue_music_rounded).last);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnlineCommentsPage)),
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

class _FakeOnlineApiClient extends OnlineApiClient {
  _FakeOnlineApiClient() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> fetchComments({
    required String resourceId,
    required String resourceType,
    required String platform,
    int pageIndex = 1,
    int pageSize = 20,
    String? lastId,
    bool isHot = false,
  }) async {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'comment_id': 'comment-1',
        'content': '测试评论',
        'time': DateTime.now().millisecondsSinceEpoch,
        'praise_count': 1,
        'reply_count': 0,
        'user': <String, dynamic>{'nickname': '测试用户', 'avatar': ''},
        'sub_comments': const <Map<String, dynamic>>[],
      },
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
