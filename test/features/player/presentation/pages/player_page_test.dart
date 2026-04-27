import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/pages/player_page.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_queue_sheet.dart';
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

  testWidgets('player more sheet shows detail entry for online track', (
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

    expect(find.text('View Detail'), findsOneWidget);
  });

  testWidgets(
    'player more sheet hides album artist comments when platform flags are unsupported',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
          featureSupportFlag: BigInt.zero,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('View Detail'), findsOneWidget);
      expect(find.text('View Album'), findsNothing);
      expect(find.text('View Artist'), findsNothing);
      expect(find.text('View Comments'), findsNothing);
    },
  );

  testWidgets('player switch quality sheet shows quality description', (
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();

    expect(find.text('HQ'), findsWidgets);
    expect(find.textContaining('High Quality'), findsOneWidget);
  });

  testWidgets('player page uses split layout on desktop width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-desktop-primary-pane')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-desktop-lyric-pane')),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('player page opens desktop queue panel on wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isTrue);
    expect(
      find.byKey(const ValueKey<String>('player-queue-desktop-panel')),
      findsOneWidget,
    );
    expect(find.byType(PlayerQueueSheet), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('player page closes desktop queue panel when backdrop tapped', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('player-queue-panel-backdrop')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isFalse);
  });

  testWidgets('player page closes desktop queue panel on escape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isFalse);
  });

  testWidgets('player page uses compact desktop layout on short window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 632));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-desktop-layout')),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('player page avoids overflow on narrow short window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(585, 632));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('player-compact-lyric-preview')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final lyricY = tester
        .getCenter(
          find.byKey(const ValueKey<String>('player-compact-lyric-preview')),
        )
        .dy;
    final progressY = tester.getCenter(find.byType(Slider).first).dy;
    final moreY = tester.getCenter(find.byIcon(Icons.more_horiz_rounded)).dy;
    final playY = tester.getCenter(find.byIcon(Icons.play_arrow_rounded)).dy;

    expect(lyricY, lessThan(moreY));
    expect(progressY, greaterThan(500));
    expect(moreY, greaterThan(460));
    expect(playY, greaterThan(560));
  });

  testWidgets('player page opens queue bottom sheet on narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    expect(container.read(playerQueuePanelOpenProvider), isFalse);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('player-queue-desktop-panel')),
      findsNothing,
    );
  });

  testWidgets('player page hides queue entry in radio mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _RadioTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
  });

  testWidgets('player page hides play mode toggle in radio mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _RadioTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
  });

  testWidgets('player page uses light status bar style while visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    final overlayRegion = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byWidgetPredicate(
            (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
          ),
        )
        .last;
    final overlayStyle = overlayRegion.value;

    expect(overlayStyle.statusBarIconBrightness, Brightness.light);
    expect(overlayStyle.statusBarBrightness, Brightness.dark);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });
}

Widget _buildPlayerTestApp({
  required PlayerController Function() controllerFactory,
  BigInt? featureSupportFlag,
}) {
  return ProviderScope(
    overrides: <Override>[
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(controllerFactory),
      onlinePlatformsProvider.overrideWith(
        () => _TestOnlinePlatformsController(
          featureSupportFlag:
              featureSupportFlag ??
              (PlatformFeatureSupportFlag.getAlbumInfo |
                  PlatformFeatureSupportFlag.getSingerInfo |
                  PlatformFeatureSupportFlag.getCommentList),
        ),
      ),
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
        artists: <SongInfoArtistInfo>[
          SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
        ],
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

class _RadioTrackPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'radio-song-1',
        title: '电台歌曲',
        artist: '电台歌手',
        album: '电台专辑',
        platform: 'qq',
      ),
    ]).copyWith(
      playMode: PlayerPlayMode.sequence,
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );
  }

  @override
  Future<void> initialize() async {}
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  _TestOnlinePlatformsController({required this.featureSupportFlag});

  final BigInt featureSupportFlag;

  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: featureSupportFlag,
        qualities: const <String, String>{
          'SQ': 'Standard Quality',
          'HQ': 'High Quality',
        },
      ),
    ];
  }
}
