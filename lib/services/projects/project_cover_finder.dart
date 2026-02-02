import 'package:path/path.dart' as path;
import '../app/app_error.dart';
import '../app/error_reporter.dart';
import '../files/file_extensions.dart';
import '../files/file_path_lister.dart';

/// 项目封面图查找器。
///
/// 在目录内按遍历顺序找到首个支持的图片文件。
class ProjectCoverFinder {
  const ProjectCoverFinder({FilePathLister? filePathLister})
      : _filePathLister = filePathLister ?? const DirectoryFilePathLister();

  final FilePathLister _filePathLister;

  /// 查找并返回首个图片路径，未找到则返回 null。
  Future<String?> findFirstImagePath(String dirPath) async {
    try {
      await for (final filePath in _filePathLister.listFiles(dirPath)) {
        final ext = path.extension(filePath).toLowerCase();
        if (supportedImageExtensions.contains(ext)) {
          return filePath;
        }
      }
    } catch (e, stack) {
      ErrorReporter.report(
        e,
        AppErrorCode.ioOperationFailed,
        stackTrace: stack,
        details: 'load project cover: $dirPath ($e)',
      );
    }
    return null;
  }
}
