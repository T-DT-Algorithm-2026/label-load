import 'dart:io';
import 'dart:typed_data';
import '../files/file_extensions.dart';
import '../files/file_listing.dart';

/// 图片仓库接口，抽象文件系统读取。
abstract class ImageRepository {
  /// 列出目录下的图片路径（完整路径）。
  Future<List<String>> listImagePaths(String directoryPath);

  /// 判断路径是否存在。
  Future<bool> exists(String path);

  /// 读取文件字节内容。
  Future<Uint8List> readBytes(String path);

  /// 删除文件（若存在）。
  Future<void> deleteIfExists(String path);
}

/// 基于文件系统的图片仓库。
class FileImageRepository implements ImageRepository {
  @override
  Future<List<String>> listImagePaths(String directoryPath) {
    return FileListing.listByExtensions(
      directoryPath,
      supportedImageExtensions,
    );
  }

  @override
  Future<bool> exists(String path) {
    return File(path).exists();
  }

  @override
  Future<Uint8List> readBytes(String path) {
    return File(path).readAsBytes();
  }

  @override
  Future<void> deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
