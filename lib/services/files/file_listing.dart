import 'package:path/path.dart' as p;
import 'file_path_lister.dart';

/// 文件列表工具
///
/// 提供按扩展名筛选并排序的文件列表方法。
class FileListing {
  /// 获取目录下指定扩展名的文件列表
  ///
  /// [comparator] 为空时按路径字符串排序。
  static Future<List<String>> listByExtensions(
    String directoryPath,
    List<String> extensions, {
    FilePathLister? filePathLister,
    int Function(String a, String b)? comparator,
  }) async {
    final lister = filePathLister ?? const DirectoryFilePathLister();
    final files = <String>[];
    await for (final filePath in lister.listFiles(directoryPath)) {
      final ext = p.extension(filePath).toLowerCase();
      if (!extensions.contains(ext)) continue;
      files.add(filePath);
    }

    files.sort(comparator ?? (a, b) => a.compareTo(b));
    return files;
  }
}
