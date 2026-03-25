import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/player_play_mode.dart';

class PlayerControlBar extends StatelessWidget {
  const PlayerControlBar({
    required this.config,
    required this.isPlaying,
    required this.playMode,
    required this.onOpenQueue,
    required this.onCyclePlayMode,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    super.key,
  });

  final AppConfigState config;
  final bool isPlaying;
  final PlayerPlayMode playMode;
  final VoidCallback onOpenQueue;
  final VoidCallback onCyclePlayMode;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _SideControlButton(
          onPressed: onCyclePlayMode,
          tooltip: _modeTooltip(playMode),
          icon: _modeIcon(playMode),
        ),
        const SizedBox(width: 8),
        _RoundControlButton(
          onPressed: onPrevious,
          icon: Icons.skip_previous_rounded,
          size: 58,
          iconSize: 34,
        ),
        const SizedBox(width: 14),
        _PrimaryControlButton(
          onPressed: onPlayPause,
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        ),
        const SizedBox(width: 14),
        _RoundControlButton(
          onPressed: onNext,
          icon: Icons.skip_next_rounded,
          size: 58,
          iconSize: 34,
        ),
        const SizedBox(width: 8),
        _SideControlButton(
          onPressed: onOpenQueue,
          tooltip: AppI18n.t(config, 'player.queue.open'),
          icon: Icons.queue_music_rounded,
        ),
      ],
    );
  }

  IconData _modeIcon(PlayerPlayMode mode) {
    return switch (mode) {
      PlayerPlayMode.sequence => Icons.repeat_rounded,
      PlayerPlayMode.shuffle => Icons.shuffle_rounded,
      PlayerPlayMode.single => Icons.repeat_one_rounded,
    };
  }

  String _modeTooltip(PlayerPlayMode mode) {
    return switch (mode) {
      PlayerPlayMode.sequence => AppI18n.t(config, 'player.mode.sequence'),
      PlayerPlayMode.shuffle => AppI18n.t(config, 'player.mode.shuffle'),
      PlayerPlayMode.single => AppI18n.t(config, 'player.mode.single'),
    };
  }
}

class _PrimaryControlButton extends StatelessWidget {
  const _PrimaryControlButton({required this.onPressed, required this.icon});

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 42),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.onPressed,
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        minimumSize: Size.square(size),
        padding: const EdgeInsets.all(10),
      ),
    );
  }
}

class _SideControlButton extends StatelessWidget {
  const _SideControlButton({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 22,
      color: Colors.white.withValues(alpha: 0.84),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        minimumSize: const Size.square(48),
        padding: const EdgeInsets.all(10),
      ),
    );
  }
}
