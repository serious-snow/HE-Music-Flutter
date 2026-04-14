import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/audio_player_port.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_playback_api_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'playAt should ignore stale failure from previous track switch',
    () async {
      final apiClient = _FakeOnlineApiClient(
        handlers: <String, Future<Map<String, dynamic>> Function()>{
          'song-1': () async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            throw Exception('stale network error');
          },
          'song-2': () async => const <String, dynamic>{
            'url': 'https://example.com/song-2.mp3',
          },
        },
      );
      final audioPlayer = _FakeAudioPlayerPort();
      final container = ProviderContainer(
        overrides: <Override>[
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          audioPlayerPortProvider.overrideWithValue(audioPlayer),
          playerPlaybackApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      await controller.replaceQueue(
        _buildQueue(),
        startIndex: 1,
        autoplay: false,
      );

      final staleFuture = controller.playAt(0).catchError((Object _) {});
      final latestFuture = controller.playAt(1);

      await latestFuture;
      await staleFuture;

      final state = container.read(playerControllerProvider);
      expect(state.currentIndex, 1);
      expect(state.currentTrack?.id, 'song-2');
      expect(state.currentTrack?.url, 'https://example.com/song-2.mp3');
      expect(state.errorMessage, isNull);
      expect(audioPlayer.lastQueueInitialIndex, 1);
      expect(
        audioPlayer.lastQueueTracks[1].url,
        'https://example.com/song-2.mp3',
      );
    },
  );

  test(
    'playAt should ignore stale success from previous track switch',
    () async {
      final apiClient = _FakeOnlineApiClient(
        handlers: <String, Future<Map<String, dynamic>> Function()>{
          'song-1': () async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return const <String, dynamic>{
              'url': 'https://example.com/song-1.mp3',
            };
          },
        },
      );
      final audioPlayer = _FakeAudioPlayerPort();
      final container = ProviderContainer(
        overrides: <Override>[
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          audioPlayerPortProvider.overrideWithValue(audioPlayer),
          playerPlaybackApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      await controller.replaceQueue(
        _buildQueue(),
        startIndex: 1,
        autoplay: false,
      );

      final staleFuture = controller.playAt(0);
      final latestFuture = controller.playAt(1);

      await Future.wait(<Future<void>>[staleFuture, latestFuture]);

      final state = container.read(playerControllerProvider);
      expect(state.currentIndex, 1);
      expect(state.currentTrack?.id, 'song-2');
      expect(state.currentTrack?.url, 'https://example.com/song-2.mp3');
      expect(state.errorMessage, isNull);
      expect(audioPlayer.lastQueueInitialIndex, 1);
      expect(audioPlayer.lastQueueTracks[1].id, 'song-2');
      expect(
        audioPlayer.lastQueueTracks[1].url,
        'https://example.com/song-2.mp3',
      );
    },
  );
}

List<PlayerTrack> _buildQueue() {
  return const <PlayerTrack>[
    PlayerTrack(id: 'song-1', title: '第一首', platform: 'qq'),
    PlayerTrack(
      id: 'song-2',
      title: '第二首',
      platform: 'qq',
      url: 'https://example.com/song-2.mp3',
    ),
  ];
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh-CN');
  }
}

class _FakeAudioPlayerPort implements AudioPlayerPort {
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _loadingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _completedController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<int?> _currentIndexController =
      StreamController<int?>.broadcast();

  List<AudioTrack> lastQueueTracks = const <AudioTrack>[];
  int? lastQueueInitialIndex;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<bool> get loadingStream => _loadingController.stream;

  @override
  Stream<bool> get completedStream => _completedController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  Future<void> setQueue(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
  }) async {
    lastQueueTracks = List<AudioTrack>.from(tracks);
    lastQueueInitialIndex = initialIndex;
  }

  @override
  Future<void> setSource(AudioTrack track) async {
    lastQueueTracks = <AudioTrack>[track];
    lastQueueInitialIndex = 0;
  }

  @override
  Future<void> playAt(int index) async {
    lastQueueInitialIndex = index;
  }

  @override
  Future<void> seekToNext() async {}

  @override
  Future<void> seekToPrevious() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setSingleLoop(bool enabled) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _loadingController.close();
    await _completedController.close();
    await _positionController.close();
    await _durationController.close();
    await _currentIndexController.close();
  }
}

class _FakeOnlineApiClient extends OnlineApiClient {
  _FakeOnlineApiClient({required this.handlers}) : super(Dio());

  final Map<String, Future<Map<String, dynamic>> Function()> handlers;

  @override
  Future<Map<String, dynamic>> fetchSongUrl({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) {
    final handler = handlers[songId];
    if (handler == null) {
      throw StateError('缺少 $songId 的测试响应');
    }
    return handler();
  }
}
