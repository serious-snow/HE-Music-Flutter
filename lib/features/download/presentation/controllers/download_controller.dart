import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/download_state.dart';
import '../../domain/entities/download_task.dart';
import '../providers/download_providers.dart';

class DownloadController extends Notifier<DownloadState> {
  bool _processing = false;

  @override
  DownloadState build() {
    return DownloadState.initial;
  }

  Future<void> enqueue({required String title, required String url}) async {
    _validateUrl(url);
    final task = DownloadTask.queued(id: _taskId(), title: title, url: url);
    state = state.copyWith(tasks: <DownloadTask>[...state.tasks, task]);
    await _processQueue();
  }

  Future<void> retry(String taskId) async {
    _updateTask(
      taskId,
      (task) => task.copyWith(
        status: DownloadTaskStatus.queued,
        progress: 0,
        clearError: true,
      ),
    );
    await _processQueue();
  }

  void removeTask(String taskId) {
    final updated = state.tasks
        .where((task) => task.id != taskId)
        .toList(growable: false);
    state = state.copyWith(tasks: updated);
  }

  void clearCompleted() {
    final updated = state.tasks
        .where((task) => task.status != DownloadTaskStatus.completed)
        .toList(growable: false);
    state = state.copyWith(tasks: updated);
  }

  Future<void> _processQueue() async {
    if (_processing) {
      return;
    }
    _processing = true;
    state = state.copyWith(isProcessing: true);
    while (true) {
      final task = _nextQueuedTask();
      if (task == null) {
        break;
      }
      await _runTask(task);
    }
    _processing = false;
    state = state.copyWith(isProcessing: false);
  }

  DownloadTask? _nextQueuedTask() {
    for (final task in state.tasks) {
      if (task.status == DownloadTaskStatus.queued) {
        return task;
      }
    }
    return null;
  }

  Future<void> _runTask(DownloadTask task) async {
    _updateTask(
      task.id,
      (old) => old.copyWith(
        status: DownloadTaskStatus.downloading,
        progress: 0,
        clearError: true,
      ),
    );
    final repository = ref.read(downloadRepositoryProvider);
    try {
      final savePath = await repository.resolveSavePath(
        title: task.title,
        url: task.url,
      );
      await repository.downloadFile(
        url: task.url,
        savePath: savePath,
        onProgress: (progress) {
          _updateTask(
            task.id,
            (old) => old.copyWith(
              status: DownloadTaskStatus.downloading,
              progress: progress,
            ),
          );
        },
      );
      _updateTask(
        task.id,
        (old) => old.copyWith(
          status: DownloadTaskStatus.completed,
          progress: 1,
          filePath: savePath,
          clearError: true,
        ),
      );
    } catch (error) {
      _updateTask(
        task.id,
        (old) => old.copyWith(
          status: DownloadTaskStatus.failed,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void _updateTask(
    String taskId,
    DownloadTask Function(DownloadTask task) updater,
  ) {
    final updated = state.tasks
        .map((task) {
          if (task.id != taskId) {
            return task;
          }
          return updater(task);
        })
        .toList(growable: false);
    state = state.copyWith(tasks: updated);
  }

  void _validateUrl(String input) {
    final uri = Uri.tryParse(input);
    final scheme = uri?.scheme.toLowerCase();
    final valid = scheme == 'http' || scheme == 'https';
    if (valid) {
      return;
    }
    throw const AppException(
      ValidationFailure('Download only supports network URL (http/https).'),
    );
  }

  String _taskId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
