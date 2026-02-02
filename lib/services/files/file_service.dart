import 'package:path/path.dart' as p;
import '../../models/label.dart';
import '../../models/label_definition.dart';
import '../app/app_error.dart';
import '../app/error_reporter.dart';
import 'file_extensions.dart';
import 'file_listing.dart';
import 'text_file_repository.dart';

/// 文件服务
///
/// 提供图像和标签文件的读写操作。
class FileService {
  FileService({TextFileRepository? repository})
      : _repository = repository ?? FileTextRepository();

  final TextFileRepository _repository;

  /// 获取目录下所有图片文件
  ///
  /// 返回按文件名排序的完整路径列表。
  Future<List<String>> getImageFiles(String directoryPath) async {
    return FileListing.listByExtensions(
      directoryPath,
      supportedImageExtensions,
    );
  }

  /// 读取YOLO格式标签文件
  ///
  /// [labelPath] 标签文件路径
  /// [getName] 由 class id 映射类名的函数
  /// [labelDefinitions] 标签定义，用于判断是否为多边形类型
  /// 返回: (标签列表, 损坏的行列表)
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int) getName, {
    List<LabelDefinition>? labelDefinitions,
  }) async {
    if (!await _repository.exists(labelPath)) return (<Label>[], <String>[]);

    final content = await _repository.readString(labelPath);
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty);

    final labels = <Label>[];
    final corruptedLines = <String>[];

    int failedLines = 0;
    Object? firstError;
    StackTrace? firstStack;

    for (final line in lines) {
      try {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.isEmpty) continue;

        final classId = int.tryParse(parts[0]);
        if (classId == null) {
          corruptedLines.add(line);
          failedLines += 1;
          continue;
        }

        // 根据标签定义获取类型，未定义则默认为 BWP 以保留最多信息
        final type = labelDefinitions?.typeForClassId(
              classId,
              fallback: LabelType.boxWithPoint,
            ) ??
            LabelType.boxWithPoint;

        labels.add(Label.fromYoloLine(line, getName, type: type));
      } catch (e, stack) {
        corruptedLines.add(line);
        failedLines += 1;
        firstError ??= e;
        firstStack ??= stack;
      }
    }

    if (failedLines > 0) {
      ErrorReporter.report(
        firstError ?? Exception('label parse failed'),
        AppErrorCode.unexpected,
        stackTrace: firstStack,
        details: 'read labels: $labelPath (failed lines: $failedLines)',
      );
    }

    return (labels, corruptedLines);
  }

  /// 写入YOLO格式标签文件
  ///
  /// [labelPath] 标签文件路径
  /// [labels] 标签列表
  /// [labelDefinitions] 标签定义，用于判断是否以多边形格式写入
  /// [corruptedLines] 需要保留的损坏/无法解析的行
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  }) async {
    final buffer = StringBuffer();

    // 写入有效标签
    if (labels.isNotEmpty) {
      final labelContent = labels.map((l) {
        // 根据标签定义判断是否以多边形格式写入
        final isPolygon =
            labelDefinitions?.typeForClassId(l.id) == LabelType.polygon;
        return l.toYoloLine(isPolygon: isPolygon);
      }).join('\n');
      buffer.write(labelContent);
    }

    // 写入损坏/保留的行
    if (corruptedLines != null && corruptedLines.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(corruptedLines.join('\n'));
    }

    await _repository.writeString(labelPath, buffer.toString());
  }

  /// 读取类名文件
  ///
  /// 尝试读取 classes.txt 或 classes.names 文件。
  Future<List<String>> readClassNames(String labelDir) async {
    for (final name in ['classes.txt', 'classes.names']) {
      final path = p.join(labelDir, name);
      if (await _repository.exists(path)) {
        final content = await _repository.readString(path);
        return content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      }
    }
    return [];
  }

  /// 写入类名文件
  Future<void> writeClassNames(String labelDir, List<String> classNames) async {
    final filePath = p.join(labelDir, 'classes.txt');
    await _repository.writeString(filePath, classNames.join('\n'));
  }
}
