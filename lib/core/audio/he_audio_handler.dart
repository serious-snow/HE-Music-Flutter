import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';

import '../../app/config/app_environment.dart';
import '../../app/config/app_config_state.dart';
import '../../app/config/app_online_audio_quality.dart';
import '../../shared/models/he_music_models.dart';
import 'audio_player_factory.dart';
import 'audio_track.dart';

class HeAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  HeAudioHandler() : _player = createHeAudioPlayer() {
    _player.playerStateStream.listen((_) {
      _refreshDurationFromPlayer();
      _broadcastPlaybackState();
    });
    _player.durationStream.listen((duration) {
      _refreshDuration(duration);
    });
    _player.playbackEventStream.listen((_) {
      _refreshDurationFromPlayer();
      _broadcastPlaybackState();
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState != ProcessingState.completed) {
        return;
      }
      unawaited(_handlePlaybackCompleted());
    });
  }

  final AudioPlayer _player;
  final Random _random = Random();

  List<AudioTrack> _tracks = const <AudioTrack>[];
  int _currentIndex = 0;
  Duration? _duration;
  bool _shuffleEnabled = false;
  bool _singleLoopEnabled = false;
  bool _handlingCompletion = false;

  String _apiBaseUrl = AppEnvironment.apiBaseUrl;
  String? _authToken = AppConfigState.initial.authToken;
  AppOnlineAudioQuality _qualityPreference = AppOnlineAudioQuality.auto;
  String? _lastSelectedQualityName;

  Future<void> syncConfig({
    required String apiBaseUrl,
    required String? authToken,
    required AppOnlineAudioQuality qualityPreference,
    required String? lastSelectedQualityName,
  }) async {
    _apiBaseUrl = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _authToken = authToken?.trim();
    _qualityPreference = qualityPreference;
    _lastSelectedQualityName = lastSelectedQualityName?.trim();
  }

  Future<void> setQueueData(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
  }) async {
    final previousIndex = _currentIndex;
    final previousCurrent = _safeTrack(_currentIndex);
    _tracks = List<AudioTrack>.unmodifiable(tracks);
    _currentIndex = tracks.isEmpty
        ? 0
        : initialIndex.clamp(0, tracks.length - 1).toInt();
    queue.add(_tracks.map(_toMediaItem).toList(growable: false));
    _broadcastMediaItem();
    _broadcastPlaybackState();
    if (_tracks.isEmpty) {
      await _player.stop();
      _duration = null;
      return;
    }
    final nextCurrent = _safeTrack(_currentIndex);
    final sameCurrentTrack =
        previousCurrent != null &&
        nextCurrent != null &&
        _isSameTrack(previousCurrent, nextCurrent);
    if (sameCurrentTrack &&
        previousIndex == _currentIndex &&
        !forceReloadCurrent &&
        _player.audioSource != null &&
        _player.processingState != ProcessingState.idle) {
      _broadcastMediaItem();
      _broadcastPlaybackState();
      return;
    }
    await _prepareCurrentTrackIfNeeded(forceReload: forceReloadCurrent);
  }

  Future<void> replaceCurrentTrack(AudioTrack track) async {
    if (_tracks.isEmpty) {
      await setQueueData(<AudioTrack>[track], initialIndex: 0);
      return;
    }
    final next = <AudioTrack>[..._tracks];
    next[_currentIndex] = track;
    _tracks = List<AudioTrack>.unmodifiable(next);
    queue.add(_tracks.map(_toMediaItem).toList(growable: false));
    final resumePosition = _player.position;
    final wasPlaying = _player.playing;
    await _loadTrackAt(_currentIndex, autoplay: false);
    if (resumePosition > Duration.zero) {
      await _player.seek(resumePosition);
    }
    if (wasPlaying) {
      await _player.play();
    }
  }

  Future<void> playIndex(int index) async {
    if (_tracks.isEmpty) {
      return;
    }
    _currentIndex = index.clamp(0, _tracks.length - 1).toInt();
    await _loadTrackAt(_currentIndex, autoplay: true);
  }

  Future<void> setSingleLoopMode(bool enabled) async {
    _singleLoopEnabled = enabled;
    await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
    _broadcastPlaybackState();
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    _shuffleEnabled = enabled;
    _broadcastPlaybackState();
  }

  Future<void> setVolumeValue(double volume) async {
    await _player.setVolume(volume);
  }

  Future<void> setSpeedValue(double speed) async {
    await _player.setSpeed(speed);
    _broadcastPlaybackState();
  }

  Stream<int?> get queueIndexStream =>
      playbackState.map((state) => state.queueIndex).distinct();

  Stream<bool> get loadingStream => playbackState
      .map(
        (state) =>
            state.processingState == AudioProcessingState.loading ||
            state.processingState == AudioProcessingState.buffering,
      )
      .distinct();

  Stream<bool> get completedStream => playbackState
      .map((state) => state.processingState == AudioProcessingState.completed)
      .distinct();

  Stream<bool> get playingStream =>
      playbackState.map((state) => state.playing).distinct();

  Stream<Duration?> get durationStream =>
      mediaItem.map((item) => item?.duration).distinct();

  Stream<Duration> get positionStream => AudioService.position;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _broadcastPlaybackState();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_tracks.isEmpty) {
      return;
    }
    final nextIndex = _shuffleEnabled
        ? _randomNextIndex(_tracks.length, excluding: _currentIndex)
        : (_currentIndex + 1) % _tracks.length;
    await playIndex(nextIndex);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_tracks.isEmpty) {
      return;
    }
    final previousIndex = _shuffleEnabled
        ? _randomNextIndex(_tracks.length, excluding: _currentIndex)
        : (_currentIndex - 1 + _tracks.length) % _tracks.length;
    await playIndex(previousIndex);
  }

  @override
  Future<void> skipToQueueItem(int index) => playIndex(index);

  Future<void> disposeHandler() async {
    await _player.dispose();
  }

  Future<void> _prepareCurrentTrackIfNeeded({bool forceReload = false}) async {
    final current = _safeTrack(_currentIndex);
    if (current == null) {
      return;
    }
    if (!forceReload &&
        _player.audioSource != null &&
        mediaItem.value?.id == current.id &&
        _player.processingState != ProcessingState.idle) {
      return;
    }
    await _loadTrackAt(_currentIndex, autoplay: false);
  }

  Future<void> _loadTrackAt(int index, {required bool autoplay}) async {
    final track = _safeTrack(index);
    if (track == null) {
      return;
    }
    final resolved = await _resolveTrack(track);
    final next = <AudioTrack>[..._tracks];
    next[index] = resolved;
    _tracks = List<AudioTrack>.unmodifiable(next);
    queue.add(_tracks.map(_toMediaItem).toList(growable: false));
    _currentIndex = index;
    _duration = null;
    final initialDuration = await _player.setAudioSource(
      _buildSource(resolved),
    );
    _refreshDuration(initialDuration ?? _player.duration);
    _broadcastMediaItem();
    _broadcastPlaybackState();
    if (autoplay) {
      await _player.play();
    }
  }

  void _refreshDurationFromPlayer() {
    _refreshDuration(_player.duration);
  }

  void _refreshDuration(Duration? duration) {
    if (_duration == duration) {
      return;
    }
    _duration = duration;
    _broadcastMediaItem();
    _broadcastPlaybackState();
  }

  Future<AudioTrack> _resolveTrack(AudioTrack track) async {
    if (track.url.trim().isNotEmpty) {
      return track;
    }
    final matchedQuality = _resolvePreferredLink(track.links);
    final directUrl = matchedQuality?.url.trim() ?? '';
    if (directUrl.isNotEmpty) {
      return AudioTrack(
        id: track.id,
        title: track.title,
        url: directUrl,
        path: track.path,
        duration: track.duration,
        links: track.links,
        artist: track.artist,
        album: track.album,
        artworkUrl: track.artworkUrl,
        platform: track.platform,
      );
    }
    final localPath = track.path?.trim() ?? '';
    if (localPath.isNotEmpty) {
      return AudioTrack(
        id: track.id,
        title: track.title,
        url: _localPathToUrl(localPath),
        path: localPath,
        duration: track.duration,
        links: track.links,
        artist: track.artist,
        album: track.album,
        artworkUrl: track.artworkUrl,
        platform: track.platform,
      );
    }
    final platform = track.platform?.trim() ?? '';
    if (platform.isEmpty) {
      return track;
    }
    final payload = await _fetchSongUrl(
      songId: track.id,
      platform: platform,
      quality: _requestQuality(matchedQuality),
      format: _requestFormat(matchedQuality),
    );
    final url = '${payload['url'] ?? ''}'.trim();
    if (url.isEmpty) {
      return track;
    }
    return AudioTrack(
      id: track.id,
      title: track.title,
      url: url,
      path: track.path,
      duration: track.duration,
      links: track.links,
      artist: track.artist,
      album: track.album,
      artworkUrl: track.artworkUrl,
      platform: track.platform,
    );
  }

  LinkInfo? _resolvePreferredLink(List<LinkInfo> links) {
    if (links.isEmpty) {
      return null;
    }
    final lastSelected = _lastSelectedQualityName ?? '';
    if (_qualityPreference.isAuto && lastSelected.isNotEmpty) {
      for (final link in links) {
        if (link.name.trim() == lastSelected) {
          return link;
        }
      }
    }
    if (!_qualityPreference.isAuto) {
      for (final link in links) {
        if (link.name.trim().toLowerCase() == _qualityPreference.value) {
          return link;
        }
      }
    }
    for (final preference in AppOnlineAudioQuality.autoFallbackOrder) {
      for (final link in links) {
        if (_qualityBucket(link) == preference) {
          return link;
        }
      }
    }
    return links.first;
  }

  AppOnlineAudioQuality? _qualityBucket(LinkInfo link) {
    final name = link.name.trim().toLowerCase();
    final format = link.format.trim().toLowerCase();
    if (name.contains('master')) {
      return AppOnlineAudioQuality.master;
    }
    if (name.contains('galaxy')) {
      return AppOnlineAudioQuality.galaxy;
    }
    if (name.contains('dolby')) {
      return AppOnlineAudioQuality.dolby;
    }
    if (name.contains('hires') || name.contains('hi-res')) {
      return AppOnlineAudioQuality.hires;
    }
    if (name.contains('flac') || format == 'flac') {
      return AppOnlineAudioQuality.flac;
    }
    if (name.contains('320') || (format == 'mp3' && link.quality >= 320)) {
      return AppOnlineAudioQuality.mp3320;
    }
    if (name.contains('192') || (format == 'mp3' && link.quality >= 192)) {
      return AppOnlineAudioQuality.mp3192;
    }
    if (name.contains('128') || (format == 'mp3' && link.quality >= 128)) {
      return AppOnlineAudioQuality.mp3128;
    }
    return null;
  }

  int? _requestQuality(LinkInfo? selectedQuality) {
    if (selectedQuality == null) {
      return null;
    }
    if (selectedQuality.quality > 0) {
      return selectedQuality.quality;
    }
    final numeric = RegExp(r'(\d+)').firstMatch(selectedQuality.name.trim());
    if (numeric == null) {
      return null;
    }
    return int.tryParse(numeric.group(1)!);
  }

  String? _requestFormat(LinkInfo? selectedQuality) {
    final linkFormat = selectedQuality?.format.trim();
    if (linkFormat != null && linkFormat.isNotEmpty) {
      return linkFormat;
    }
    final name = selectedQuality?.name.trim().toLowerCase() ?? '';
    if (name.contains('flac')) {
      return 'flac';
    }
    if (name.contains('ape')) {
      return 'ape';
    }
    if (name.contains('m4a')) {
      return 'm4a';
    }
    if (name.contains('ogg')) {
      return 'ogg';
    }
    if (name.contains('wav')) {
      return 'wav';
    }
    if (name.contains('aac')) {
      return 'aac';
    }
    if (name.contains('mp3')) {
      return 'mp3';
    }
    return null;
  }

  Future<Map<String, dynamic>> _fetchSongUrl({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
        headers: <String, String>{
          'User-Agent': heAudioUserAgent,
          if ((_authToken ?? '').isNotEmpty) ...<String, String>{
            'authorization': 'Bearer ${_authToken!}',
            'Authorization': 'Bearer ${_authToken!}',
          },
        },
      ),
    );
    try {
      final response = await dio.get(
        '/v1/song/url',
        queryParameters: <String, dynamic>{
          'id': songId,
          'platform': platform,
          'quality': quality ?? 320,
          'format': (format == null || format.trim().isEmpty) ? 'mp3' : format,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return const <String, dynamic>{};
    } finally {
      dio.close(force: true);
    }
  }

  Future<void> _handlePlaybackCompleted() async {
    if (_handlingCompletion || _tracks.isEmpty || _singleLoopEnabled) {
      return;
    }
    _handlingCompletion = true;
    try {
      await skipToNext();
    } finally {
      _handlingCompletion = false;
    }
  }

  MediaItem _toMediaItem(AudioTrack track) {
    final artwork = track.artworkUrl?.trim() ?? '';
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      artUri: artwork.isEmpty ? null : Uri.parse(artwork),
      duration: _safeTrack(_currentIndex)?.id == track.id ? _duration : null,
    );
  }

  AudioSource _buildSource(AudioTrack track) {
    final sourceUrl = track.url.trim();
    final localPath = track.path?.trim() ?? '';
    return AudioSource.uri(
      localPath.isNotEmpty ? _localPathToUri(localPath) : Uri.parse(sourceUrl),
      tag: _toMediaItem(track),
    );
  }

  String _localPathToUrl(String localPath) {
    return _localPathToUri(localPath).toString();
  }

  Uri _localPathToUri(String localPath) {
    final normalized = localPath.trim();
    final parsed = Uri.tryParse(normalized);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    return Uri.file(normalized);
  }

  void _broadcastMediaItem() {
    final current = _safeTrack(_currentIndex);
    mediaItem.add(current == null ? null : _toMediaItem(current));
  }

  void _broadcastPlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: _mapProcessingState(_player.processingState),
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _tracks.isEmpty ? 0 : _currentIndex,
        repeatMode: _singleLoopEnabled
            ? AudioServiceRepeatMode.one
            : AudioServiceRepeatMode.none,
        shuffleMode: _shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  AudioTrack? _safeTrack(int index) {
    if (index < 0 || index >= _tracks.length) {
      return null;
    }
    return _tracks[index];
  }

  int _randomNextIndex(int queueLength, {required int excluding}) {
    if (queueLength <= 1) {
      return 0;
    }
    var nextIndex = excluding;
    while (nextIndex == excluding) {
      nextIndex = _random.nextInt(queueLength);
    }
    return nextIndex;
  }

  bool _isSameTrack(AudioTrack left, AudioTrack right) {
    final leftId = left.id.trim();
    final rightId = right.id.trim();
    if (leftId.isEmpty || rightId.isEmpty || leftId != rightId) {
      return false;
    }
    final leftPlatform = left.platform?.trim() ?? '';
    final rightPlatform = right.platform?.trim() ?? '';
    if (leftPlatform == 'local' || rightPlatform == 'local') {
      return true;
    }
    return leftPlatform.isNotEmpty &&
        rightPlatform.isNotEmpty &&
        leftPlatform == rightPlatform;
  }
}

late final HeAudioHandler globalHeAudioHandler;

Future<void> initHeAudioHandler() async {
  globalHeAudioHandler = await AudioService.init(
    builder: HeAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.he_music_flutter.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: true,
    ),
  );
}
