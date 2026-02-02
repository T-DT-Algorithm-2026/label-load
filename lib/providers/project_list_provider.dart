import 'package:flutter/foundation.dart';
import '../models/project_config.dart';
import '../services/app/app_error.dart';
import '../services/projects/project_list_repository.dart';
import 'app_error_state.dart';

/// 项目列表状态管理
///
/// 管理所有项目配置的加载、保存和CRUD操作。
/// 项目列表存储在应用文档目录的 LabelLoad/projects.json 文件中。
class ProjectListProvider extends ChangeNotifier with AppErrorState {
  List<ProjectConfig> _projects = [];
  bool _isLoading = false;
  final ProjectListRepository _repository;

  ProjectListProvider({ProjectListRepository? repository})
      : _repository = repository ?? ProjectListRepository();

  /// 当前项目列表（按加载顺序）。
  ///
  /// 仅供读取；请通过 add/update/remove 方法修改。
  List<ProjectConfig> get projects => _projects;

  /// 是否正在加载项目列表。
  bool get isLoading => _isLoading;

  /// 加载项目列表
  Future<void> loadProjects() async {
    _isLoading = true;
    clearError();
    notifyListeners();

    try {
      _projects = await _repository.loadProjects();
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.projectListLoadFailed,
        stackTrace: stack,
        details: e.toString(),
        notify: false,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 添加项目
  Future<void> addProject(ProjectConfig project) async {
    _projects.add(project);
    await _saveProjects();
    notifyListeners();
  }

  /// 更新项目
  Future<void> updateProject(ProjectConfig project) async {
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _projects[index] = project;
      await _saveProjects();
      notifyListeners();
    }
  }

  /// 删除项目
  Future<void> removeProject(String id) async {
    _projects.removeWhere((p) => p.id == id);
    await _saveProjects();
    notifyListeners();
  }

  /// 保存项目列表到文件
  Future<void> _saveProjects() async {
    try {
      await _repository.saveProjects(_projects);
      clearError();
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.projectListSaveFailed,
        stackTrace: stack,
        details: e.toString(),
        notify: false,
      );
      notifyListeners();
    }
  }
}
