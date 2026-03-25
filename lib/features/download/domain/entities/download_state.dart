import 'download_task.dart';

class DownloadState {
  const DownloadState({required this.tasks, required this.isProcessing});

  final List<DownloadTask> tasks;
  final bool isProcessing;

  DownloadState copyWith({List<DownloadTask>? tasks, bool? isProcessing}) {
    return DownloadState(
      tasks: tasks ?? this.tasks,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  static const initial = DownloadState(
    tasks: <DownloadTask>[],
    isProcessing: false,
  );
}
