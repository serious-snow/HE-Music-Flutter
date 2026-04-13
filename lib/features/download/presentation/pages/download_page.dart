import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/adaptive_action_menu.dart';
import '../../domain/entities/download_state.dart';
import '../../domain/entities/download_task.dart';
import '../providers/download_providers.dart';

class DownloadPage extends ConsumerWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadControllerProvider);
    final localeCode = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: AppI18n.tByLocaleCode(localeCode, 'common.back'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(AppI18n.tByLocaleCode(localeCode, 'download.title')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: _DownloadTaskList(
            state: downloadState,
            onPause: ref.read(downloadControllerProvider.notifier).pause,
            onResume: ref.read(downloadControllerProvider.notifier).resume,
            onRedownload: ref
                .read(downloadControllerProvider.notifier)
                .redownload,
            onOpenLocation: ref
                .read(downloadControllerProvider.notifier)
                .openContainingFolder,
            onRetry: ref.read(downloadControllerProvider.notifier).retry,
            onRemove: ref.read(downloadControllerProvider.notifier).removeTask,
            onClearCompleted: ref
                .read(downloadControllerProvider.notifier)
                .clearCompleted,
          ),
        ),
      ),
    );
  }
}

class _DownloadTaskList extends StatelessWidget {
  const _DownloadTaskList({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onRedownload,
    required this.onOpenLocation,
    required this.onRetry,
    required this.onRemove,
    required this.onClearCompleted,
  });

  final DownloadState state;
  final ValueChanged<String> onPause;
  final ValueChanged<String> onResume;
  final ValueChanged<String> onRedownload;
  final ValueChanged<String> onOpenLocation;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearCompleted;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    if (state.tasks.isEmpty) {
      return Center(
        child: Text(AppI18n.tByLocaleCode(localeCode, 'download.empty')),
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            itemCount: state.tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = state.tasks[index];
              return _DownloadTaskRow(
                task: task,
                onPause: () => onPause(task.id),
                onResume: () => onResume(task.id),
                onRedownload: () => onRedownload(task.id),
                onOpenLocation: () => onOpenLocation(task.id),
                onRetry: () => onRetry(task.id),
                onRemove: () => onRemove(task.id),
              );
            },
          ),
        ),
        if (state.completedTasks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClearCompleted,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(
                AppI18n.tByLocaleCode(
                  localeCode,
                  'download.action.clear_completed',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DownloadTaskRow extends StatelessWidget {
  const _DownloadTaskRow({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRedownload,
    required this.onOpenLocation,
    required this.onRetry,
    required this.onRemove,
  });

  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRedownload;
  final VoidCallback onOpenLocation;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  _displayFileName(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 42,
                child: Text(
                  task.quality.fileExtension.trim().toUpperCase(),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                child: Text(
                  _speedLabel(),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: _speedColor(colorScheme),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 54,
                child: Text(
                  _statusLabel(context),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: _statusColor(colorScheme),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Align(
                  alignment: Alignment.topRight,
                  child: _MoreButton(
                    task: task,
                    onPause: onPause,
                    onResume: onResume,
                    onRedownload: onRedownload,
                    onOpenLocation: onOpenLocation,
                    onRetry: onRetry,
                    onRemove: onRemove,
                  ),
                ),
              ),
            ],
          ),
          if (_showProgress(task)) ...<Widget>[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: task.status == DownloadTaskStatus.preparing
                    ? null
                    : task.progress,
                minHeight: 3,
                backgroundColor: colorScheme.outlineVariant.withValues(
                  alpha: 0.22,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _progressColor(colorScheme),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _displayFileName(DownloadTask task) {
    final filePath = (task.filePath ?? '').trim();
    if (filePath.isNotEmpty) {
      final normalized = filePath.replaceAll('\\', '/');
      final index = normalized.lastIndexOf('/');
      if (index >= 0 && index < normalized.length - 1) {
        return normalized.substring(index + 1);
      }
      return normalized;
    }
    final title = task.title.trim();
    final artist = (task.artist ?? '').trim();
    final extension = task.quality.fileExtension.trim().toLowerCase();
    if (artist.isEmpty) {
      return '$title.$extension';
    }
    return '$title - $artist.$extension';
  }

  bool _showProgress(DownloadTask task) {
    return task.status == DownloadTaskStatus.preparing ||
        task.status == DownloadTaskStatus.downloading ||
        task.status == DownloadTaskStatus.tagging;
  }

  String _speedLabel() {
    if (task.status == DownloadTaskStatus.downloading) {
      return '${task.quality.bitrate.toStringAsFixed(0)}kbps';
    }
    return '-';
  }

  String _statusLabel(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    switch (task.status) {
      case DownloadTaskStatus.queued:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.queued');
      case DownloadTaskStatus.preparing:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.preparing');
      case DownloadTaskStatus.downloading:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.downloading');
      case DownloadTaskStatus.tagging:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.tagging');
      case DownloadTaskStatus.completed:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.completed');
      case DownloadTaskStatus.paused:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.paused');
      case DownloadTaskStatus.failed:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.failed');
    }
  }

  Color _speedColor(ColorScheme colorScheme) {
    if (task.status == DownloadTaskStatus.downloading) {
      return const Color(0xFF3DAA7B);
    }
    return colorScheme.onSurfaceVariant;
  }

  Color _statusColor(ColorScheme colorScheme) {
    switch (task.status) {
      case DownloadTaskStatus.downloading:
        return const Color(0xFFCF8A17);
      case DownloadTaskStatus.tagging:
        return const Color(0xFF278BCB);
      case DownloadTaskStatus.failed:
        return colorScheme.error;
      case DownloadTaskStatus.completed:
        return const Color(0xFF2F9A5A);
      case DownloadTaskStatus.queued:
      case DownloadTaskStatus.paused:
        return colorScheme.onSurfaceVariant;
      case DownloadTaskStatus.preparing:
        return colorScheme.primary;
    }
  }

  Color _progressColor(ColorScheme colorScheme) {
    switch (task.status) {
      case DownloadTaskStatus.tagging:
        return const Color(0xFF4AB8F5);
      case DownloadTaskStatus.downloading:
      case DownloadTaskStatus.preparing:
        return const Color(0xFFE0A446);
      case DownloadTaskStatus.queued:
      case DownloadTaskStatus.completed:
      case DownloadTaskStatus.paused:
      case DownloadTaskStatus.failed:
        return colorScheme.primary;
    }
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRedownload,
    required this.onOpenLocation,
    required this.onRetry,
    required this.onRemove,
  });

  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRedownload;
  final VoidCallback onOpenLocation;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  String get _menuButtonKey => 'download_more_button_${task.id}';
  String get _pauseItemKey => 'download_more_pause_${task.id}';
  String get _resumeItemKey => 'download_more_resume_${task.id}';
  String get _redownloadItemKey => 'download_more_redownload_${task.id}';
  String get _openLocationItemKey => 'download_more_open_location_${task.id}';
  String get _retryItemKey => 'download_more_retry_${task.id}';
  String get _removeItemKey => 'download_more_remove_${task.id}';

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return AdaptiveActionMenu<String>(
      menuKey: Key(_menuButtonKey),
      tooltip: AppI18n.tByLocaleCode(localeCode, 'common.more'),
      icon: const Icon(Icons.more_horiz_rounded, size: 18),
      items: _buildActions(localeCode),
      onSelected: (action) {
        switch (action) {
          case 'pause':
            onPause();
          case 'resume':
            onResume();
          case 'redownload':
            onRedownload();
          case 'open_location':
            onOpenLocation();
          case 'retry':
            onRetry();
          case 'remove':
            onRemove();
        }
      },
    );
  }

  List<AdaptiveActionMenuItem<String>> _buildActions(String localeCode) {
    final items = <AdaptiveActionMenuItem<String>>[];
    if (task.status == DownloadTaskStatus.preparing ||
        task.status == DownloadTaskStatus.downloading ||
        task.status == DownloadTaskStatus.tagging) {
      items.add(
        AdaptiveActionMenuItem<String>(
          key: Key(_pauseItemKey),
          value: 'pause',
          label: AppI18n.tByLocaleCode(localeCode, 'download.action.pause'),
          icon: Icons.pause_rounded,
        ),
      );
    }
    if (task.status == DownloadTaskStatus.paused) {
      items.add(
        AdaptiveActionMenuItem<String>(
          key: Key(_resumeItemKey),
          value: 'resume',
          label: AppI18n.tByLocaleCode(localeCode, 'download.action.resume'),
          icon: Icons.play_arrow_rounded,
        ),
      );
    }
    if (task.status == DownloadTaskStatus.failed) {
      items.add(
        AdaptiveActionMenuItem<String>(
          key: Key(_retryItemKey),
          value: 'retry',
          label: AppI18n.tByLocaleCode(localeCode, 'download.action.retry'),
          icon: Icons.refresh_rounded,
        ),
      );
    }
    if (task.status == DownloadTaskStatus.completed) {
      items.add(
        AdaptiveActionMenuItem<String>(
          key: Key(_redownloadItemKey),
          value: 'redownload',
          label: AppI18n.tByLocaleCode(
            localeCode,
            'download.action.redownload',
          ),
          icon: Icons.download_for_offline_rounded,
        ),
      );
      if ((task.filePath ?? '').trim().isNotEmpty) {
        items.add(
          AdaptiveActionMenuItem<String>(
            key: Key(_openLocationItemKey),
            value: 'open_location',
            label: AppI18n.tByLocaleCode(
              localeCode,
              'download.action.open_location',
            ),
            icon: Icons.folder_open_rounded,
          ),
        );
      }
    }
    items.add(
      AdaptiveActionMenuItem<String>(
        key: Key(_removeItemKey),
        value: 'remove',
        label: AppI18n.tByLocaleCode(localeCode, 'download.action.remove'),
        icon: Icons.delete_outline_rounded,
        destructive: true,
        startsNewSection: items.isNotEmpty,
      ),
    );
    return items;
  }
}
