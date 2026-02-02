import 'dart:io';
import 'package:path/path.dart' as p;
import '../files/atomic_file_writer.dart';
import '../files/file_extensions.dart';
import '../files/file_listing.dart';

/// 批处理工具的数据仓库接口。
abstract class GadgetRepository {
  /// 列出目录下图片文件（自然排序）。
  Future<List<String>> listImageFiles(String directoryPath);

  /// 列出目录下视频文件（自然排序）。
  Future<List<String>> listVideoFiles(String directoryPath);

  /// 列出目录下标签文件（排除 classes.txt）。
  Future<List<String>> listLabelFiles(String directoryPath);

  /// 重命名文件。
  Future<void> renameFile(String from, String to);

  /// 按行读取文本文件。
  Future<List<String>> readLines(String path);

  /// 按行写入文本文件。
  Future<void> writeLines(String path, List<String> lines);

  /// 读取 classes.txt。
  Future<List<String>> readClassNames(String labelDir);

  /// 写入 classes.txt。
  Future<void> writeClassNames(String labelDir, List<String> classNames);
}

/// 基于文件系统的 GadgetRepository 实现。
class FileGadgetRepository implements GadgetRepository {
  @override
  Future<List<String>> listImageFiles(String directoryPath) {
    return FileListing.listByExtensions(
      directoryPath,
      supportedImageExtensions,
      comparator: _naturalCompare,
    );
  }

  @override
  Future<List<String>> listVideoFiles(String directoryPath) {
    return FileListing.listByExtensions(
      directoryPath,
      supportedVideoExtensions,
      comparator: _naturalCompare,
    );
  }

  @override
  Future<List<String>> listLabelFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final files = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (ext == '.txt' && p.basename(entity.path) != 'classes.txt') {
          files.add(entity.path);
        }
      }
    }

    files.sort(_naturalCompare);
    return files;
  }

  @override
  Future<void> renameFile(String from, String to) {
    return File(from).rename(to);
  }

  @override
  Future<List<String>> readLines(String path) async {
    final file = File(path);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    return content.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  @override
  Future<void> writeLines(String path, List<String> lines) {
    return atomicWriteString(path, lines.join('\n'));
  }

  @override
  Future<List<String>> readClassNames(String labelDir) async {
    final file = File(p.join(labelDir, 'classes.txt'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    return content.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  @override
  Future<void> writeClassNames(String labelDir, List<String> classNames) {
    final file = File(p.join(labelDir, 'classes.txt'));
    return atomicWriteString(file.path, classNames.join('\n'));
  }

  static int _naturalCompare(String a, String b) {
    final aName = p.basenameWithoutExtension(a);
    final bName = p.basenameWithoutExtension(b);

    final aNum = int.tryParse(aName);
    final bNum = int.tryParse(bName);

    if (aNum != null && bNum != null) {
      return aNum.compareTo(bNum);
    }

    return a.compareTo(b);
  }
}
