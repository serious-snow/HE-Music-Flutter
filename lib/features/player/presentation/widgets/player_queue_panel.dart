import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import 'player_queue_panel_content.dart';

const double playerQueuePanelWidth = 360;
const double playerQueuePanelBreakpoint = 720;

class PlayerQueuePanelOverlay extends ConsumerWidget {
  const PlayerQueuePanelOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(playerQueuePanelOpenProvider);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!isOpen || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          ref.read(playerQueuePanelOpenProvider.notifier).state = false;
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: IgnorePointer(
        ignoring: !isOpen,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey<String>('player-queue-panel-backdrop'),
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    ref.read(playerQueuePanelOpenProvider.notifier).state =
                        false,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: isOpen ? 1 : 0,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: PlayerQueuePanel(),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerQueuePanel extends ConsumerWidget {
  const PlayerQueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(playerQueuePanelOpenProvider);
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: !isOpen,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutQuint,
        offset: isOpen ? Offset.zero : const Offset(1.0, 0),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: isOpen ? 0.985 : 1,
            end: isOpen ? 1 : 0.985,
          ),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutQuint,
          child: SizedBox(
            key: const ValueKey<String>('player-queue-desktop-panel'),
            width: playerQueuePanelWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.28,
                    ),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(-10, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                      child: Row(
                        children: <Widget>[
                          const Spacer(),
                          IconButton(
                            onPressed: () =>
                                ref
                                        .read(
                                          playerQueuePanelOpenProvider.notifier,
                                        )
                                        .state =
                                    false,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonLabel,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Expanded(child: PlayerQueuePanelContent()),
                  ],
                ),
              ),
            ),
          ),
          builder: (context, value, child) {
            return Transform.scale(
              alignment: Alignment.centerRight,
              scale: value,
              child: child,
            );
          },
        ),
      ),
    );
  }
}
