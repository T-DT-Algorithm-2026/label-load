import 'package:path/path.dart' as p;
import '../app/app_error.dart';
import '../app/error_reporter.dart';
import 'gadget_repository.dart';

/// 工具服务
///
/// 提供数据集批量处理工具，包括文件重命名、标签格式转换、边界框操作等。
class GadgetService {
  GadgetService({GadgetRepository? repository})
      : _repository = repository ?? FileGadgetRepository();

  final GadgetRepository _repository;

  // ============ 文件获取方法 ============

  /// 获取目录下所有图片文件（自然排序）
  Future<List<String>> getImageFiles(String directoryPath) async {
    return _repository.listImageFiles(directoryPath);
  }

  /// 获取目录下所有视频文件（自然排序）
  Future<List<String>> getVideoFiles(String directoryPath) async {
    return _repository.listVideoFiles(directoryPath);
  }

  /// 获取目录下所有标签文件（自然排序，排除classes.txt）
  Future<List<String>> getLabelFiles(String directoryPath) async {
    return _repository.listLabelFiles(directoryPath);
  }

  // ============ 批处理方法 ============

  /// 批量重命名图片为序号
  ///
  /// 返回 (成功数, 失败数)
  Future<(int, int)> batchRename(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    final repo = repository ?? _repository;
    final files = await repo.listImageFiles(directoryPath);
    if (files.isEmpty) return (0, 0);

    int success = 0;
    int failed = 0;
    final totalSteps = files.length * 2;

    // 第一遍：重命名为临时文件名
    final tempFiles = <String, String>{};
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = p.extension(file);
      final tempName = p.join(directoryPath, '${i}_temp$ext');
      try {
        await repo.renameFile(file, tempName);
        tempFiles[tempName] = p.join(directoryPath, '$i$ext');
      } catch (e, stack) {
        ErrorReporter.report(
          e,
          AppErrorCode.ioOperationFailed,
          stackTrace: stack,
          details: 'batch rename temp: $file ($e)',
        );
        failed++;
      }
      onProgress?.call(i + 1, totalSteps);
    }

    // 第二遍：重命名为最终文件名
    int idx = 0;
    for (final entry in tempFiles.entries) {
      try {
        await repo.renameFile(entry.key, entry.value);
        success++;
      } catch (e, stack) {
        ErrorReporter.report(
          e,
          AppErrorCode.ioOperationFailed,
          stackTrace: stack,
          details: 'batch rename final: ${entry.value} ($e)',
        );
        failed++;
      }
      onProgress?.call(files.length + idx + 1, totalSteps);
      idx++;
    }

    return (success, failed);
  }

  /// XYXY格式转XYWH格式
  ///
  /// 输入格式：class x1 y1 x2 y2 [额外数据]
  /// 输出格式：class cx cy w h [额外数据]
  /// 返回 (成功数, 失败数)
  Future<(int, int)> xyxy2xywh(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    return _processLabelFiles(directoryPath, onProgress: onProgress,
        processor: (tokens) {
      if (tokens.length < 5) return null;

      final classId = tokens[0];
      final x1 = double.parse(tokens[1]);
      final y1 = double.parse(tokens[2]);
      final x2 = double.parse(tokens[3]);
      final y2 = double.parse(tokens[4]);

      final cx = (x1 + x2) / 2;
      final cy = (y1 + y2) / 2;
      final w = (x2 - x1).abs();
      final h = (y2 - y1).abs();

      final remaining =
          tokens.length > 5 ? ' ${tokens.sublist(5).join(' ')}' : '';
      return '$classId $cx $cy $w $h$remaining';
    }, repository: repository);
  }

  /// 扩展边界框
  ///
  /// [ratioX] X方向缩放比例
  /// [ratioY] Y方向缩放比例
  /// [biasX] X方向偏移量
  /// [biasY] Y方向偏移量
  /// 返回 (成功数, 失败数)
  Future<(int, int)> bboxExpand(
    String directoryPath, {
    double ratioX = 1.0,
    double ratioY = 1.0,
    double biasX = 0.0,
    double biasY = 0.0,
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    return _processLabelFiles(directoryPath, onProgress: onProgress,
        processor: (tokens) {
      if (tokens.length < 5) return null;

      final classId = tokens[0];
      final cx = double.parse(tokens[1]);
      final cy = double.parse(tokens[2]);
      var w = double.parse(tokens[3]);
      var h = double.parse(tokens[4]);

      // 应用扩展
      w = w * ratioX + biasX;
      h = h * ratioY + biasY;

      // 裁剪到有效范围
      final fromX = (cx - w / 2).clamp(0.0, 1.0);
      final fromY = (cy - h / 2).clamp(0.0, 1.0);
      final toX = (cx + w / 2).clamp(0.0, 1.0);
      final toY = (cy + h / 2).clamp(0.0, 1.0);

      final newCx = (fromX + toX) / 2;
      final newCy = (fromY + toY) / 2;
      final newW = toX - fromX;
      final newH = toY - fromY;

      final remaining =
          tokens.length > 5 ? ' ${tokens.sublist(5).join(' ')}' : '';
      return '$classId $newCx $newCy $newW $newH$remaining';
    }, repository: repository);
  }

  /// 检查并修复标签问题
  ///
  /// 修复越界边界框，移除重复标签。
  /// 返回 (成功数, 失败数)
  Future<(int, int)> checkAndFix(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    final repo = repository ?? _repository;
    final files = await repo.listLabelFiles(directoryPath);
    if (files.isEmpty) return (0, 0);

    int success = 0;
    int failed = 0;

    for (int i = 0; i < files.length; i++) {
      try {
        final lines = await repo.readLines(files[i]);

        bool needRewrite = false;
        final newLines = <String>[];

        for (final line in lines) {
          final tokens = line.trim().split(RegExp(r'\s+'));
          if (tokens.length < 5) {
            failed++;
            continue;
          }

          final classId = tokens[0];
          final cx = double.parse(tokens[1]);
          final cy = double.parse(tokens[2]);
          final w = double.parse(tokens[3]);
          final h = double.parse(tokens[4]);

          final left = cx - w / 2;
          final top = cy - h / 2;
          final right = cx + w / 2;
          final bottom = cy + h / 2;

          String newLine;
          if (left < 0 || top < 0 || right > 1 || bottom > 1) {
            needRewrite = true;
            // 修复越界
            final fixedLeft = left.clamp(0.000001, 0.999999);
            final fixedTop = top.clamp(0.000001, 0.999999);
            final fixedRight = right.clamp(0.000001, 0.999999);
            final fixedBottom = bottom.clamp(0.000001, 0.999999);

            final newCx = (fixedLeft + fixedRight) / 2;
            final newCy = (fixedTop + fixedBottom) / 2;
            final newW = fixedRight - fixedLeft;
            final newH = fixedBottom - fixedTop;

            final remaining =
                tokens.length > 5 ? ' ${tokens.sublist(5).join(' ')}' : '';
            newLine = '$classId $newCx $newCy $newW $newH$remaining';
          } else {
            newLine = line.trim();
          }

          // 去重
          if (!newLines.contains(newLine)) {
            newLines.add(newLine);
          } else {
            needRewrite = true;
          }
        }

        if (needRewrite) {
          await repo.writeLines(files[i], newLines);
        }
        success++;
      } catch (e, stack) {
        ErrorReporter.report(
          e,
          AppErrorCode.ioOperationFailed,
          stackTrace: stack,
          details: 'check and fix: ${files[i]} ($e)',
        );
        failed++;
      }
      onProgress?.call(i + 1, files.length);
    }

    return (success, failed);
  }

  /// 删除关键点，只保留边界框
  ///
  /// 保留前5个值：class cx cy w h
  /// 返回 (成功数, 失败数)
  Future<(int, int)> deleteKeypoints(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    return _processLabelFiles(directoryPath, onProgress: onProgress,
        processor: (tokens) {
      if (tokens.length < 5) return null;
      return tokens.take(5).join(' ');
    }, repository: repository);
  }

  /// 从关键点计算边界框
  ///
  /// 输入格式：class x1 y1 x2 y2 ...
  /// 输出格式：class cx cy w h x1 y1 x2 y2 ...
  /// 返回 (成功数, 失败数)
  Future<(int, int)> addBboxFromKeypoints(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    return _processLabelFiles(directoryPath, onProgress: onProgress,
        processor: (tokens) {
      if (tokens.length < 5) return null;

      final classId = tokens[0];
      final xs = <double>[];
      final ys = <double>[];

      for (int j = 1; j < tokens.length; j += 2) {
        xs.add(double.parse(tokens[j]));
        if (j + 1 < tokens.length) {
          ys.add(double.parse(tokens[j + 1]));
        }
      }

      if (xs.isEmpty || ys.isEmpty || xs.length != ys.length) return null;

      final xMin = xs.reduce((a, b) => a < b ? a : b);
      final xMax = xs.reduce((a, b) => a > b ? a : b);
      final yMin = ys.reduce((a, b) => a < b ? a : b);
      final yMax = ys.reduce((a, b) => a > b ? a : b);

      final cx = (xMin + xMax) / 2;
      final cy = (yMin + yMax) / 2;
      final w = xMax - xMin;
      final h = yMax - yMin;

      final keypoints = tokens.sublist(1).join(' ');
      return '$classId $cx $cy $w $h $keypoints';
    }, repository: repository);
  }

  /// 转换标签类别ID
  ///
  /// [classMapping] 映射数组，索引为原ID，值为新ID（-1表示删除）
  /// 返回 (成功数, 失败数)
  Future<(int, int)> convertLabels(
    String directoryPath,
    List<int> classMapping, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    final repo = repository ?? _repository;
    final files = await repo.listLabelFiles(directoryPath);
    if (files.isEmpty) return (0, 0);

    int success = 0;
    int failed = 0;

    for (int i = 0; i < files.length; i++) {
      try {
        final lines = await repo.readLines(files[i]);

        final newLines = <String>[];
        for (final line in lines) {
          final tokens = line.trim().split(RegExp(r'\s+'));
          if (tokens.isEmpty) continue;

          final classId = int.tryParse(tokens[0]);
          if (classId == null || classId >= classMapping.length) {
            failed++;
            continue;
          }

          final newClassId = classMapping[classId];
          if (newClassId < 0) continue; // -1表示删除

          tokens[0] = newClassId.toString();
          newLines.add(tokens.join(' '));
        }

        await repo.writeLines(files[i], newLines);
        success++;
      } catch (e, stack) {
        ErrorReporter.report(
          e,
          AppErrorCode.ioOperationFailed,
          stackTrace: stack,
          details: 'convert labels: ${files[i]} ($e)',
        );
        failed++;
      }
      onProgress?.call(i + 1, files.length);
    }

    return (success, failed);
  }

  /// 删除指定类别的所有标签
  ///
  /// 返回 (修改的文件数, 删除的标签数)
  Future<(int, int)> deleteClassFromLabels(
    String directoryPath,
    int classIdToDelete, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    final repo = repository ?? _repository;
    final files = await repo.listLabelFiles(directoryPath);
    if (files.isEmpty) return (0, 0);

    int filesModified = 0;
    int labelsDeleted = 0;

    for (int i = 0; i < files.length; i++) {
      try {
        final lines = await repo.readLines(files[i]);

        final newLines = <String>[];
        int deletedInFile = 0;

        for (final line in lines) {
          final tokens = line.trim().split(RegExp(r'\s+'));
          if (tokens.isEmpty) continue;

          final classId = int.tryParse(tokens[0]);
          if (classId == classIdToDelete) {
            deletedInFile++;
            continue;
          }

          newLines.add(line);
        }

        if (deletedInFile > 0) {
          await repo.writeLines(files[i], newLines);
          filesModified++;
          labelsDeleted += deletedInFile;
        }
      } catch (e, stack) {
        ErrorReporter.report(
          e,
          AppErrorCode.ioOperationFailed,
          stackTrace: stack,
          details: 'delete class from labels: ${files[i]} ($e)',
        );
      }
      onProgress?.call(i + 1, files.length);
    }

    return (filesModified, labelsDeleted);
  }

  // ============ 类名文件操作 ============

  /// 读取classes.txt
  Future<List<String>> readClassNames(
    String labelDir, {
    GadgetRepository? repository,
  }) async {
    final repo = repository ?? _repository;
    return repo.readClassNames(labelDir);
  }

  /// 读取任意文本文件（按行，过滤空行）
  Future<List<String>> readLines(
    String path, {
    GadgetRepository? repository,
  }) async {
    final repo = repository ?? _repository;
    return repo.readLines(path);
  }

  /// 写入classes.txt
  Future<void> writeClassNames(
    String labelDir,
    List<String> classNames, {
    GadgetRepository? repository,
  }) async {
    final repo = repository ?? _repository;
    await repo.writeClassNames(labelDir, classNames);
  }

  // ============ 内部工具方法 ============

  /// 通用标签文件处理
  ///
  /// [processor] 处理单行的函数，返回null表示该行处理失败
  Future<(int, int)> _processLabelFiles(
    String directoryPath, {
    required String? Function(List<String> tokens) processor,
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    final repo = repository ?? _repository;
    final files = await repo.listLabelFiles(directoryPath);
    if (files.isEmpty) return (0, 0);

    int success = 0;
    int failed = 0;

    for (int i = 0; i < files.length; i++) {
      try {
        final lines = await repo.readLines(files[i]);

        final newLines = <String>[];
        for (final line in lines) {
          final tokens = line.trim().split(RegExp(r'\s+'));
          final result = processor(tokens);
          if (result != null) {
            newLines.add(result);
          } else {
            failed++;
          }
        }

        await repo.writeLines(files[i], newLines);
        success++;
      } catch (e, stack) {
        ErrorReporter.report(
          e,
          AppErrorCode.ioOperationFailed,
          stackTrace: stack,
          details: 'process label file: ${files[i]} ($e)',
        );
        failed++;
      }
      onProgress?.call(i + 1, files.length);
    }

    return (success, failed);
  }
}
