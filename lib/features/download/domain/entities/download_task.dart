enum DownloadTaskStatus { queued, downloading, completed, failed }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.status,
    required this.progress,
    this.filePath,
    this.errorMessage,
  });

  final String id;
  final String title;
  final String url;
  final DownloadTaskStatus status;
  final double progress;
  final String? filePath;
  final String? errorMessage;

  DownloadTask copyWith({
    DownloadTaskStatus? status,
    double? progress,
    String? filePath,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      url: url,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static DownloadTask queued({
    required String id,
    required String title,
    required String url,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      url: url,
      status: DownloadTaskStatus.queued,
      progress: 0,
    );
  }
}
