import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_track.dart';
import '../controllers/player_controller.dart';
import '../providers/player_providers.dart';
import 'player_queue_sheet.dart';

class MiniPlayerBar extends ConsumerStatefulWidget {
  const MiniPlayerBar({required this.onOpenFullPlayer, super.key});

  final VoidCallback onOpenFullPlayer;

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar> {
  static const double _maxDragOffset = 96;
  static const double _switchThreshold = 68;

  double _slideDirection = 1;
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final hasQueue = ref.watch(
      playerControllerProvider.select((state) => state.queue.isNotEmpty),
    );
    final isPlaying = ref.watch(
      playerControllerProvider.select((state) => state.isPlaying),
    );
    final queue = ref.watch(
      playerControllerProvider.select((state) => state.queue),
    );
    final currentIndex = ref.watch(
      playerControllerProvider.select((state) => state.currentIndex),
    );
    final playMode = ref.watch(
      playerControllerProvider.select((state) => state.playMode),
    );
    final config = ref.watch(appConfigProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    if (!hasQueue || track == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 58,
          child: Row(
            children: <Widget>[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onOpenFullPlayer,
                child: _CoverImage(
                  url: track.artworkUrl,
                  bytes: track.artworkBytes,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackSwipeArea(
                  track: track,
                  previewTrack: _previewTrack(
                    queue: queue,
                    currentIndex: currentIndex,
                    playMode: playMode,
                  ),
                  dragOffset: _dragOffset,
                  slideDirection: _slideDirection,
                  onTap: widget.onOpenFullPlayer,
                  onDragUpdate: _handleDragUpdate,
                  onDragEnd: (velocity) =>
                      _handleHorizontalDrag(velocity, controller),
                ),
              ),
              IconButton(
                onPressed: controller.togglePlayPause,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                tooltip: AppI18n.t(config, 'player.full'),
              ),
              IconButton(
                onPressed: () => _openQueueSheet(context),
                icon: const Icon(Icons.queue_music_rounded),
                tooltip: AppI18n.t(config, 'player.queue'),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  void _handleHorizontalDrag(double? velocity, PlayerController controller) {
    final value = velocity ?? 0;
    final shouldSwitch =
        _dragOffset.abs() >= _switchThreshold || value.abs() >= 320;
    final direction = _dragOffset.abs() >= _switchThreshold
        ? _dragOffset
        : (value == 0 ? _dragOffset : -value);
    if (!shouldSwitch || direction == 0) {
      setState(() {
        _dragOffset = 0;
      });
      return;
    }
    if (direction < 0) {
      setState(() {
        _slideDirection = 1;
        _dragOffset = 0;
      });
      controller.playNext();
      return;
    }
    setState(() {
      _slideDirection = -1;
      _dragOffset = 0;
    });
    controller.playPrevious();
  }

  void _handleDragUpdate(double delta) {
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(
        -_maxDragOffset,
        _maxDragOffset,
      );
    });
  }

  PlayerTrack? _previewTrack({
    required List<PlayerTrack> queue,
    required int currentIndex,
    required PlayerPlayMode playMode,
  }) {
    if (playMode != PlayerPlayMode.sequence || queue.isEmpty) {
      return null;
    }
    if (_dragOffset < -8) {
      final nextIndex = currentIndex + 1;
      if (nextIndex >= 0 && nextIndex < queue.length) {
        return queue[nextIndex];
      }
    }
    if (_dragOffset > 8) {
      final previousIndex = currentIndex - 1;
      if (previousIndex >= 0 && previousIndex < queue.length) {
        return queue[previousIndex];
      }
    }
    return null;
  }

  void _openQueueSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const PlayerQueueSheet(),
    );
  }
}

class _TrackSwipeArea extends StatelessWidget {
  const _TrackSwipeArea({
    required this.track,
    required this.previewTrack,
    required this.dragOffset,
    required this.slideDirection,
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final PlayerTrack track;
  final PlayerTrack? previewTrack;
  final double dragOffset;
  final double slideDirection;
  final VoidCallback onTap;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double?> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewOpacity = (dragOffset.abs() / 72).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
      onHorizontalDragEnd: (details) => onDragEnd(details.primaryVelocity),
      onHorizontalDragCancel: () => onDragEnd(0),
      child: ClipRect(
        child: SizedBox(
          height: double.infinity,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              if (previewTrack != null)
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: dragOffset < 0 ? 18 : 0,
                      right: dragOffset > 0 ? 18 : 0,
                    ),
                    child: Align(
                      alignment: dragOffset < 0
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Opacity(
                        opacity: previewOpacity * 0.72,
                        child: Transform.translate(
                          offset: Offset(
                            dragOffset < 0 ? dragOffset + 28 : dragOffset - 28,
                            0,
                          ),
                          child: _PreviewTrackText(track: previewTrack!),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(dragOffset, 0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final begin = Offset(slideDirection * 0.16, 0);
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: begin,
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Container(
                    key: ValueKey<String>(
                      '${track.platform ?? ''}-${track.id}',
                    ),
                    alignment: Alignment.centerLeft,
                    child: _TrackText(track: track),
                  ),
                ),
              ),
              if (dragOffset.abs() > 2)
                Positioned(
                  left: dragOffset < 0 ? null : 0,
                  right: dragOffset < 0 ? 0 : null,
                  child: Icon(
                    dragOffset < 0
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.arrow_back_ios_new_rounded,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: (previewOpacity * 0.75).clamp(0.0, 0.75),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackText extends StatelessWidget {
  const _TrackText({required this.track});

  final PlayerTrack track;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        Text(
          (track.artist ?? '-').trim().isEmpty ? '-' : (track.artist ?? '-'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

class _PreviewTrackText extends StatelessWidget {
  const _PreviewTrackText({required this.track});

  final PlayerTrack track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 190,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            (track.artist ?? '-').trim().isEmpty ? '-' : (track.artist ?? '-'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.bytes});

  final String? url;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes != null && bytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes!,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, error, stackTrace) => Container(
            width: 46,
            height: 46,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.music_note_rounded),
          ),
        ),
      );
    }
    if (url == null || url!.isEmpty) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        child: const Icon(Icons.music_note_rounded),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url!,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        cacheWidth: 128,
        errorBuilder: (_, error, stackTrace) => Container(
          width: 46,
          height: 46,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.music_note_rounded),
        ),
      ),
    );
  }
}
