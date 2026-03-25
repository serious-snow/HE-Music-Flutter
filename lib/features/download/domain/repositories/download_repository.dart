typedef DownloadProgressCallback = void Function(double progress);

abstract class DownloadRepository {
  Future<String> resolveSavePath({required String title, required String url});

  Future<void> downloadFile({
    required String url,
    required String savePath,
    required DownloadProgressCallback onProgress,
  });
}
