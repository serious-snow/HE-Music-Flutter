import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _downloadDirName = 'downloads';

class DownloadPathDataSource {
  Future<Directory> ensureDownloadDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${baseDir.path}/$_downloadDirName');
    if (await targetDir.exists()) {
      return targetDir;
    }
    return targetDir.create(recursive: true);
  }
}
