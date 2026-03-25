import 'audio_track.dart';

abstract class AudioPlayerPort {
  Stream<bool> get playingStream;
  Stream<bool> get loadingStream;
  Stream<bool> get completedStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<int?> get currentIndexStream;

  Future<void> setQueue(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
  });
  Future<void> setSource(AudioTrack track);
  Future<void> playAt(int index);
  Future<void> seekToNext();
  Future<void> seekToPrevious();
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);
  Future<void> setSingleLoop(bool enabled);
  Future<void> setShuffle(bool enabled);
  Future<void> dispose();
}
