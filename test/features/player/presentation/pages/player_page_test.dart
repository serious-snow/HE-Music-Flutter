import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/pages/player_page.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('player more sheet shows add to playlist for online track', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Add to Playlist'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('player more sheet hides add to playlist for local track', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _LocalTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Add to Playlist'), findsNothing);
  });

  testWidgets('player download action opens quality sheet for online track', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Quality'), findsOneWidget);
    expect(find.text('SQ'), findsWidgets);
    expect(find.text('HQ'), findsWidgets);
  });
}

Widget _buildPlayerTestApp({
  required PlayerController Function() controllerFactory,
}) {
  return ProviderScope(
    overrides: <Override>[
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(controllerFactory),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
    ],
    child: const MaterialApp(home: PlayerPage()),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}

class _OnlineTrackPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'song-1',
        title: '在线歌曲',
        links: <LinkInfo>[
          LinkInfo(
            name: 'SQ',
            quality: 500,
            format: 'mp3',
            size: '3145728',
            url: 'https://example.com/sq.mp3',
          ),
          LinkInfo(
            name: 'HQ',
            quality: 800,
            format: 'flac',
            size: '10485760',
            url: 'https://example.com/hq.flac',
          ),
        ],
        artist: '测试歌手',
        album: '测试专辑',
        albumId: 'album-1',
        platform: 'qq',
      ),
    ]).copyWith(
      currentAvailableQualities: const <PlayerQualityOption>[
        PlayerQualityOption(
          name: 'HQ',
          quality: 800,
          format: 'flac',
          url: 'https://example.com/hq.flac',
        ),
        PlayerQualityOption(
          name: 'SQ',
          quality: 500,
          format: 'mp3',
          url: 'https://example.com/sq.mp3',
        ),
      ],
      currentSelectedQualityName: 'HQ',
    );
  }

  @override
  Future<void> initialize() async {}
}

class _LocalTrackPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'local-song-1',
        title: '本地歌曲',
        artist: '本地歌手',
        album: '本地专辑',
        platform: 'local',
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
  }
}
