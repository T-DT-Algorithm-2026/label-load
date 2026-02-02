import 'package:file_picker/file_picker.dart';

/// 文件选择服务接口
///
/// 封装平台文件选择器，便于测试替换。
abstract class FilePickerService {
  /// 选择目录，返回路径或 null。
  Future<String?> getDirectoryPath();

  /// 保存文件对话框，返回路径或 null。
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    List<String>? allowedExtensions,
  });

  /// 选择文件对话框，返回路径或 null。
  Future<String?> pickFile({
    String? dialogTitle,
    List<String>? allowedExtensions,
  });
}

/// 平台默认实现
class PlatformFilePickerService implements FilePickerService {
  const PlatformFilePickerService();

  @override
  Future<String?> getDirectoryPath() {
    return FilePicker.platform.getDirectoryPath();
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    List<String>? allowedExtensions,
  }) {
    final useCustom = allowedExtensions != null && allowedExtensions.isNotEmpty;
    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: useCustom ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );
  }

  @override
  Future<String?> pickFile({
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    final useCustom = allowedExtensions != null && allowedExtensions.isNotEmpty;
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: useCustom ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );
    if (result == null) return null;
    final file = result.files.single;
    return file.path;
  }
}
