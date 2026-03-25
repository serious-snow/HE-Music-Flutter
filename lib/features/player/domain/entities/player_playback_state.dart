import 'player_play_mode.dart';
import 'player_quality_option.dart';
import 'player_queue_snapshot.dart';
import 'player_queue_source.dart';
import 'player_track.dart';

const defaultPlayerVolume = 1.0;
const defaultPlayerSpeed = 1.0;

class PlayerPlaybackState {
  const PlayerPlaybackState({
    required this.queue,
    required this.currentIndex,
    required this.historyCount,
    required this.isPlaying,
    required this.isLoading,
    required this.position,
    required this.duration,
    required this.volume,
    required this.speed,
    required this.playMode,
    required this.currentAvailableQualities,
    this.queueSource,
    this.previousQueueSnapshot,
    this.currentSelectedQualityName,
    this.errorMessage,
  });

  final List<PlayerTrack> queue;
  final int currentIndex;
  final int historyCount;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final double volume;
  final double speed;
  final PlayerPlayMode playMode;
  final List<PlayerQualityOption> currentAvailableQualities;
  final PlayerQueueSource? queueSource;
  final PlayerQueueSnapshot? previousQueueSnapshot;
  final String? currentSelectedQualityName;
  final String? errorMessage;

  PlayerTrack? get currentTrack {
    if (queue.isEmpty || currentIndex < 0 || currentIndex >= queue.length) {
      return null;
    }
    return queue[currentIndex];
  }

  PlayerPlaybackState copyWith({
    List<PlayerTrack>? queue,
    int? currentIndex,
    int? historyCount,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    double? volume,
    double? speed,
    PlayerPlayMode? playMode,
    List<PlayerQualityOption>? currentAvailableQualities,
    PlayerQueueSource? queueSource,
    bool clearQueueSource = false,
    PlayerQueueSnapshot? previousQueueSnapshot,
    bool clearPreviousQueueSnapshot = false,
    String? currentSelectedQualityName,
    bool clearCurrentSelectedQuality = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayerPlaybackState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      historyCount: historyCount ?? this.historyCount,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      playMode: playMode ?? this.playMode,
      currentAvailableQualities:
          currentAvailableQualities ?? this.currentAvailableQualities,
      queueSource: clearQueueSource ? null : queueSource ?? this.queueSource,
      previousQueueSnapshot: clearPreviousQueueSnapshot
          ? null
          : previousQueueSnapshot ?? this.previousQueueSnapshot,
      currentSelectedQualityName: clearCurrentSelectedQuality
          ? null
          : currentSelectedQualityName ?? this.currentSelectedQualityName,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static PlayerPlaybackState initial(List<PlayerTrack> tracks) {
    return PlayerPlaybackState(
      queue: tracks,
      currentIndex: 0,
      historyCount: 0,
      isPlaying: false,
      isLoading: false,
      position: Duration.zero,
      duration: Duration.zero,
      volume: defaultPlayerVolume,
      speed: defaultPlayerSpeed,
      playMode: PlayerPlayMode.sequence,
      currentAvailableQualities: const <PlayerQualityOption>[],
      queueSource: null,
      previousQueueSnapshot: null,
    );
  }
}
