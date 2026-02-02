import 'dart:io';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import '../files/file_service.dart';

/// 标签文件读写仓库接口。
abstract class LabelFileRepository {
  /// 确保目录存在（必要时创建）。
  Future<void> ensureDirectory(String directoryPath);

  /// 判断标签文件是否存在。
  Future<bool> exists(String path);

  /// 删除标签文件（若存在）。
  Future<void> deleteIfExists(String path);

  /// 读取标签文件，返回 (标签列表, 损坏行列表)。
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int) getName, {
    List<LabelDefinition>? labelDefinitions,
  });

  /// 写入标签文件（可携带损坏行以保留）。
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  });
}

/// 基于文件系统的标签仓库实现
class FileLabelRepository implements LabelFileRepository {
  FileLabelRepository({FileService? fileService})
      : _fileService = fileService ?? FileService();

  final FileService _fileService;

  @override
  Future<void> ensureDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  @override
  Future<bool> exists(String path) {
    return File(path).exists();
  }

  @override
  Future<void> deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int) getName, {
    List<LabelDefinition>? labelDefinitions,
  }) {
    return _fileService.readLabels(
      labelPath,
      getName,
      labelDefinitions: labelDefinitions,
    );
  }

  @override
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  }) {
    return _fileService.writeLabels(
      labelPath,
      labels,
      labelDefinitions: labelDefinitions,
      corruptedLines: corruptedLines,
    );
  }
}
