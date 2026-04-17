import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_environment.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'loadHeAudioHandlerRuntimeConfig should restore persisted playback config',
    () async {
      const dataSource = AppConfigDataSource();
      await dataSource.save(
        (await dataSource.load()).copyWith(
          apiBaseUrl: 'https://example.com/',
          authToken: 'token-123',
          onlineAudioQualityPreference: AppOnlineAudioQuality.flac,
          lastSelectedOnlineAudioQualityName: 'FLAC',
        ),
      );

      final config = await loadHeAudioHandlerRuntimeConfig(
        dataSource: dataSource,
      );

      expect(config.apiBaseUrl, AppEnvironment.apiBaseUrl);
      expect(config.authToken, 'token-123');
      expect(config.qualityPreference, AppOnlineAudioQuality.flac);
      expect(config.lastSelectedQualityName, 'FLAC');
    },
  );

  test('shouldRefreshRemotePlaybackUrl returns true for remote tracks', () {
    const track = AudioTrack(
      id: '1',
      title: 'Remote',
      url: 'https://cdn.example.com/audio.mp3',
      platform: 'netease',
    );

    expect(shouldRefreshRemotePlaybackUrl(track), isTrue);
  });

  test('shouldRefreshRemotePlaybackUrl returns false for local file path', () {
    const track = AudioTrack(
      id: '2',
      title: 'Local',
      url: '',
      path: '/tmp/demo.mp3',
      platform: 'local',
    );

    expect(shouldRefreshRemotePlaybackUrl(track), isFalse);
  });

  test('shouldRefreshRemotePlaybackUrl returns false for file scheme url', () {
    const track = AudioTrack(
      id: '3',
      title: 'LocalUrl',
      url: 'file:///tmp/demo.mp3',
    );

    expect(shouldRefreshRemotePlaybackUrl(track), isFalse);
  });

  test('远程歌曲即使已有 url 也应该重新获取播放链接', () async {
    final requestedSongIds = <String>[];
    final loadedUrls = <String>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            requestedSongIds.add(songId);
            return <String, dynamic>{
              'url':
                  'https://fresh.example.com/$songId-${requestedSongIds.length}.mp3',
            };
          },
      setAudioSourceOverride: (source, player) async {
        final uriSource = source as UriAudioSource;
        loadedUrls.add(uriSource.uri.toString());
        return null;
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
    );
    const track = AudioTrack(
      id: 'song-1',
      title: '远程歌曲',
      url: 'https://expired.example.com/song-1.mp3',
      platform: 'qq',
      links: <LinkInfo>[
        LinkInfo(
          name: '320k',
          quality: 320,
          format: 'mp3',
          size: '0',
          url: 'https://stale.example.com/song-1-320.mp3',
        ),
      ],
    );

    await handler.setQueueData(<AudioTrack>[track], initialIndex: 0);
    await handler.setQueueData(
      <AudioTrack>[track],
      initialIndex: 0,
      forceReloadCurrent: true,
    );

    expect(requestedSongIds.length, greaterThanOrEqualTo(2));
    expect(loadedUrls.length, greaterThanOrEqualTo(2));
    expect(loadedUrls[0], 'https://fresh.example.com/song-1-1.mp3');
    expect(loadedUrls[1], isNot(loadedUrls[0]));
  });

  test('setAudioSource 首次失败后应该重新获取新链接并重试', () async {
    final requestedUrls = <String>[];
    var setSourceAttempts = 0;
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            final nextUrl =
                'https://fresh.example.com/$songId-${requestedUrls.length + 1}.mp3';
            requestedUrls.add(nextUrl);
            return <String, dynamic>{'url': nextUrl};
          },
      setAudioSourceOverride: (source, player) async {
        setSourceAttempts += 1;
        if (setSourceAttempts == 1) {
          throw StateError('首次装载失败');
        }
        final uriSource = source as UriAudioSource;
        expect(uriSource.uri.toString(), requestedUrls.last);
        return null;
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
    );

    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(
        id: 'song-2',
        title: '需要重试的远程歌曲',
        url: 'https://expired.example.com/song-2.mp3',
        platform: 'qq',
      ),
    ], initialIndex: 0);

    expect(requestedUrls, <String>[
      'https://fresh.example.com/song-2-1.mp3',
      'https://fresh.example.com/song-2-2.mp3',
    ]);
    expect(setSourceAttempts, 2);
  });

  test('快速切歌时旧请求不应在最后覆盖最新曲目', () async {
    final completer = Completer<void>();
    final loadedUrls = <String>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            if (songId == 'song-1') {
              await completer.future;
            }
            return <String, dynamic>{
              'url': 'https://fresh.example.com/$songId.mp3',
            };
          },
      setAudioSourceOverride: (source, player) async {
        final uriSource = source as UriAudioSource;
        loadedUrls.add(uriSource.uri.toString());
        return null;
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
    );
    const queue = <AudioTrack>[
      AudioTrack(
        id: 'song-1',
        title: '第一首',
        url: 'https://expired.example.com/song-1.mp3',
        platform: 'qq',
      ),
      AudioTrack(
        id: 'song-2',
        title: '第二首',
        url: 'https://expired.example.com/song-2.mp3',
        platform: 'qq',
      ),
    ];

    final staleFuture = handler.setQueueData(
      queue,
      initialIndex: 0,
      forceReloadCurrent: true,
    );
    final latestFuture = handler.setQueueData(
      queue,
      initialIndex: 1,
      forceReloadCurrent: true,
    );
    await latestFuture;
    completer.complete();
    await staleFuture;

    expect(loadedUrls, isNotEmpty);
    expect(loadedUrls.last, 'https://fresh.example.com/song-2.mp3');
    expect(handler.mediaItem.value?.id, 'song-2');
    expect(handler.playbackState.value.queueIndex, 1);
  });
}
