import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../features/player/presentation/widgets/mini_player_bar.dart';
import 'detail_loading_skeleton.dart';

class DetailPageShell extends StatelessWidget {
  const DetailPageShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(child: child),
          MiniPlayerBar(onOpenFullPlayer: () => context.push(AppRoutes.player)),
        ],
      ),
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

class DetailErrorBody extends StatelessWidget {
  const DetailErrorBody({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
