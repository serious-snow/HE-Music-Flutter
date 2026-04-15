import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_queue_panel.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('queue source link closes desktop panel before navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildQueuePanelApp());
    await tester.pump();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerQueuePanelOverlay)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isTrue);

    await tester.tap(find.byIcon(Icons.link_rounded));
    await tester.pumpAndSettle();

    expect(container.read(playerQueuePanelOpenProvider), isFalse);
    expect(find.text('playlist detail page'), findsOneWidget);
  });
}

Widget _buildQueuePanelApp() {
  final router = GoRouter(
    initialLocation: '/',
    routes: <GoRoute>[
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: PlayerQueuePanelOverlay()),
      ),
      GoRoute(
        path: '/playlist/detail',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('playlist detail page'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: <Override>[
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_QueueSourcePlayerController.new),
      playerQueuePanelOpenProvider.overrideWith((ref) => true),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}

class _QueueSourcePlayerController extends PlayerController {
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
    ]).copyWith(
      queueSource: const PlayerQueueSource(
        routePath: '/playlist/detail',
        queryParameters: <String, String>{'id': '1', 'platform': 'qq'},
        title: '测试歌单',
      ),
    );
  }

  @override
  Future<void> initialize() async {}
}
