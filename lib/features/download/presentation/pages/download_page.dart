import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../core/error/app_exception.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/download_state.dart';
import '../../domain/entities/download_task.dart';
import '../providers/download_providers.dart';

class DownloadPage extends ConsumerWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadControllerProvider);
    final currentTrack = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: AppI18n.t(ref.read(appConfigProvider), 'common.back'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(AppI18n.t(ref.read(appConfigProvider), 'download.title')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              _DownloadToolbar(
                state: downloadState,
                currentTrackTitle: currentTrack?.title,
                onDownloadCurrent: () => _downloadCurrentTrack(context, ref),
                onClearCompleted: ref
                    .read(downloadControllerProvider.notifier)
                    .clearCompleted,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _DownloadTaskList(
                  tasks: downloadState.tasks,
                  onRetry: ref.read(downloadControllerProvider.notifier).retry,
                  onRemove: ref
                      .read(downloadControllerProvider.notifier)
                      .removeTask,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadCurrentTrack(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final track = ref.read(playerControllerProvider).currentTrack;
    final config = ref.read(appConfigProvider);
    if (track == null) {
      _showMessage(context, AppI18n.t(config, 'download.no_current'));
      return;
    }
    try {
      await ref
          .read(downloadControllerProvider.notifier)
          .enqueue(title: track.title, url: track.url);
      if (!context.mounted) {
        return;
      }
      _showMessage(
        context,
        AppI18n.format(
          config,
          'download.added',
          <String, String>{'title': track.title},
        ),
      );
    } on AppException catch (error) {
      if (!context.mounted) {
        return;
      }
      _showErrorMessage(error.failure.message);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showErrorMessage(String message) {
    AppMessageService.showError(message);
  }
}

class _DownloadToolbar extends StatelessWidget {
  const _DownloadToolbar({
    required this.state,
    required this.currentTrackTitle,
    required this.onDownloadCurrent,
    required this.onClearCompleted,
  });

  final DownloadState state;
  final String? currentTrackTitle;
  final VoidCallback onDownloadCurrent;
  final VoidCallback onClearCompleted;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              state.isProcessing
                  ? AppI18n.tByLocaleCode(localeCode, 'download.processing')
                  : AppI18n.tByLocaleCode(localeCode, 'download.idle'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              AppI18n.formatByLocaleCode(
                localeCode,
                'download.current_track',
                <String, String>{
                  'title':
                      currentTrackTitle ??
                      AppI18n.tByLocaleCode(localeCode, 'download.none'),
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onDownloadCurrent,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    AppI18n.tByLocaleCode(localeCode, 'download.action.current'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onClearCompleted,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(
                    AppI18n.tByLocaleCode(
                      localeCode,
                      'download.action.clear_completed',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTaskList extends StatelessWidget {
  const _DownloadTaskList({
    required this.tasks,
    required this.onRetry,
    required this.onRemove,
  });

  final List<DownloadTask> tasks;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      final localeCode = Localizations.localeOf(context).languageCode;
      return Center(
        child: Text(AppI18n.tByLocaleCode(localeCode, 'download.empty')),
      );
    }
    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _DownloadTaskTile(
          task: task,
          onRetry: () => onRetry(task.id),
          onRemove: () => onRemove(task.id),
        );
      },
    );
  }
}

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({
    required this.task,
    required this.onRetry,
    required this.onRemove,
  });

  final DownloadTask task;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final progress = (task.progress * 100).clamp(0, 100).toStringAsFixed(0);
    return ListTile(
      title: Text(task.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${_statusLabel(task.status, localeCode)} · $progress%'),
          if (task.status == DownloadTaskStatus.downloading)
            LinearProgressIndicator(value: task.progress),
          if (task.filePath != null)
            Text(
              AppI18n.formatByLocaleCode(
                localeCode,
                'download.saved',
                <String, String>{'path': task.filePath!},
              ),
            ),
          if (task.errorMessage != null)
            Text(
              task.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      trailing: _TaskActions(task: task, onRetry: onRetry, onRemove: onRemove),
    );
  }

  String _statusLabel(DownloadTaskStatus status, String localeCode) {
    switch (status) {
      case DownloadTaskStatus.queued:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.queued');
      case DownloadTaskStatus.downloading:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.downloading');
      case DownloadTaskStatus.completed:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.completed');
      case DownloadTaskStatus.failed:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.failed');
    }
  }
}

class _TaskActions extends StatelessWidget {
  const _TaskActions({
    required this.task,
    required this.onRetry,
    required this.onRemove,
  });

  final DownloadTask task;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (task.status == DownloadTaskStatus.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      );
    }
    return IconButton(
      onPressed: onRemove,
      icon: const Icon(Icons.delete_outline_rounded),
    );
  }
}
