import '../../models/label.dart';
import '../../models/label_definition.dart';
import '../image/image_repository.dart';
import '../labels/label_file_repository.dart';

/// 项目数据访问层。
///
/// 统一图片列表与标签文件读写，便于替换底层仓库实现。
class ProjectRepository {
  ProjectRepository({
    ImageRepository? imageRepository,
    LabelFileRepository? labelRepository,
  })  : _imageRepository = imageRepository ?? FileImageRepository(),
        _labelRepository = labelRepository ?? FileLabelRepository();

  final ImageRepository _imageRepository;
  final LabelFileRepository _labelRepository;

  /// 列出项目图片文件路径。
  Future<List<String>> listImageFiles(String imagePath) {
    return _imageRepository.listImagePaths(imagePath);
  }

  /// 读取标签文件。
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int) getName, {
    List<LabelDefinition>? labelDefinitions,
  }) {
    return _labelRepository.readLabels(
      labelPath,
      getName,
      labelDefinitions: labelDefinitions,
    );
  }

  /// 写入标签文件。
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  }) {
    return _labelRepository.writeLabels(
      labelPath,
      labels,
      labelDefinitions: labelDefinitions,
      corruptedLines: corruptedLines,
    );
  }
}
