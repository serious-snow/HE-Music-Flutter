import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/router/app_routes.dart';
import '../../features/player/presentation/widgets/mini_player_bar.dart';
import '../../features/player/presentation/widgets/player_queue_panel.dart';
import 'detail_loading_skeleton.dart';

class DetailPageShell extends StatelessWidget {
  const DetailPageShell({required this.child, this.bottomBar, super.key});

  final Widget child;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopLayout =
            constraints.maxWidth >= playerQueuePanelBreakpoint;
        return Scaffold(
          body: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  Expanded(child: child),
                  ...<Widget?>[bottomBar].nonNulls,
                  MiniPlayerBar(
                    onOpenFullPlayer: () => context.push(AppRoutes.player),
                  ),
                ],
              ),
              if (useDesktopLayout)
                const Positioned.fill(child: PlayerQueuePanelOverlay()),
            ],
          ),
        );
      },
    );
  }
}

class DetailLoadingBody extends StatelessWidget {
  const DetailLoadingBody({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return GenericDetailLoadingBody(title: title);
  }
}

class DetailErrorBody extends ConsumerWidget {
  const DetailErrorBody({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(AppI18n.t(config, 'common.retry')),
          ),
        ],
      ),
    );
  }
}
