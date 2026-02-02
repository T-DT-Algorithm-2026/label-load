import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/project_config.dart';
import '../files/text_file_repository.dart';

/// 项目列表文件路径提供者。
abstract class ProjectsPathProvider {
  /// 返回 projects.json 的完整路径。
  Future<String> getProjectsFilePath();
}

/// 使用应用文档目录存放项目列表。
class AppDocumentsPathProvider implements ProjectsPathProvider {
  @override
  Future<String> getProjectsFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'LabelLoad', 'projects.json');
  }
}

/// 项目列表的持久化读写仓库。
class ProjectListRepository {
  ProjectListRepository({
    ProjectsPathProvider? pathProvider,
    TextFileRepository? fileRepository,
  })  : _pathProvider = pathProvider ?? AppDocumentsPathProvider(),
        _fileRepository = fileRepository ?? FileTextRepository();

  final ProjectsPathProvider _pathProvider;
  final TextFileRepository _fileRepository;

  /// 读取项目列表，文件不存在则返回空列表。
  Future<List<ProjectConfig>> loadProjects() async {
    final filePath = await _pathProvider.getProjectsFilePath();
    if (!await _fileRepository.exists(filePath)) return [];

    final jsonString = await _fileRepository.readString(filePath);
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => ProjectConfig.fromJson(e)).toList();
  }

  /// 保存项目列表。
  Future<void> saveProjects(List<ProjectConfig> projects) async {
    final filePath = await _pathProvider.getProjectsFilePath();
    final jsonList = projects.map((e) => e.toJson()).toList();
    await _fileRepository.writeString(filePath, jsonEncode(jsonList));
  }
}
