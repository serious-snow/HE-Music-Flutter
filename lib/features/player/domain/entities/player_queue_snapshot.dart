import 'player_play_mode.dart';
import 'player_queue_source.dart';
import 'player_track.dart';

class PlayerQueueSnapshot {
  const PlayerQueueSnapshot({
    required this.queue,
    required this.currentIndex,
    required this.playMode,
    this.source,
    this.previousSnapshot,
  });

  final List<PlayerTrack> queue;
  final int currentIndex;
  final PlayerPlayMode playMode;
  final PlayerQueueSource? source;
  final PlayerQueueSnapshot? previousSnapshot;

  bool get isEmpty => queue.isEmpty;
}
