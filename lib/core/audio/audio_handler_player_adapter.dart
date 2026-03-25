import '../../app/config/app_config_state.dart';
import 'audio_player_port.dart';
import 'audio_track.dart';
import 'he_audio_handler.dart';

class AudioHandlerPlayerAdapter implements AudioPlayerPort {
  AudioHandlerPlayerAdapter(this._handler);

  final HeAudioHandler _handler;

  Future<void> syncConfig(AppConfigState config) {
    return _handler.syncConfig(
      apiBaseUrl: config.apiBaseUrl,
      authToken: config.authToken,
      qualityPreference: config.onlineAudioQualityPreference,
      lastSelectedQualityName: config.lastSelectedOnlineAudioQualityName,
    );
  }

  @override
  Stream<bool> get playingStream => _handler.playingStream;

  @override
  Stream<bool> get loadingStream => _handler.loadingStream;

  @override
  Stream<bool> get completedStream => _handler.completedStream;

  @override
  Stream<Duration> get positionStream => _handler.positionStream;

  @override
  Stream<Duration?> get durationStream => _handler.durationStream;

  @override
  Stream<int?> get currentIndexStream => _handler.queueIndexStream;

  @override
  Future<void> setQueue(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
  }) {
    return _handler.setQueueData(
      tracks,
      initialIndex: initialIndex,
      forceReloadCurrent: forceReloadCurrent,
    );
  }

  @override
  Future<void> setSource(AudioTrack track) {
    return _handler.replaceCurrentTrack(track);
  }

  @override
  Future<void> playAt(int index) => _handler.playIndex(index);

  @override
  Future<void> seekToNext() => _handler.skipToNext();

  @override
  Future<void> seekToPrevious() => _handler.skipToPrevious();

  @override
  Future<void> play() => _handler.play();

  @override
  Future<void> pause() => _handler.pause();

  @override
  Future<void> stop() => _handler.stop();

  @override
  Future<void> seek(Duration position) => _handler.seek(position);

  @override
  Future<void> setVolume(double volume) => _handler.setVolumeValue(volume);

  @override
  Future<void> setSpeed(double speed) => _handler.setSpeedValue(speed);

  @override
  Future<void> setSingleLoop(bool enabled) =>
      _handler.setSingleLoopMode(enabled);

  @override
  Future<void> setShuffle(bool enabled) =>
      _handler.setShuffleModeEnabled(enabled);

  @override
  Future<void> dispose() async {}
}
