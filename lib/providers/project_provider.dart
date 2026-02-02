import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/project_config.dart';
import '../models/label_definition.dart';
import '../models/label.dart';
import '../models/config.dart';
import '../models/ai_config.dart';
import '../services/inference/ai_post_processor.dart';
import '../services/labels/label_history_store.dart';
import '../services/app/app_error.dart';
import 'app_error_state.dart';
import '../services/inference/project_inference_controller.dart';
import '../services/projects/project_repository.dart';
import '../services/app/error_reporter.dart';

/// 项目状态管理
///
/// 管理当前打开项目的完整状态，包括图像列表、标签数据、配置和AI推理。
class ProjectProvider extends ChangeNotifier with AppErrorState {
  Project? _project;
  AppConfig _config = AppConfig();
  ProjectConfig? _projectConfig;
  bool _isLoading = false;
  final LabelHistoryStore _labelStore;
  final ProjectRepository _repository;

  // AI推理服务
  final AiPostProcessor _aiPostProcessor;
  final ProjectInferenceController? _inferenceControllerOverride;
  ProjectInferenceController? _inferenceController;

  /// 当前是否已加载 AI 模型。
  bool get isModelLoaded =>
      _inferenceControllerOverride?.hasModel ??
      _inferenceController?.hasModel ??
      false;
  bool _isProcessing = false;

  /// 当前是否处于 AI 推理处理阶段。
  bool get isProcessing => _isProcessing;

  ProjectProvider({
    ProjectRepository? repository,
    ProjectInferenceController? inferenceController,
    AiPostProcessor? postProcessor,
    LabelHistoryStore? labelStore,
  })  : _repository = repository ?? ProjectRepository(),
        _labelStore = labelStore ?? LabelHistoryStore(),
        _aiPostProcessor = postProcessor ?? const AiPostProcessor(),
        _inferenceControllerOverride = inferenceController;

  ProjectInferenceController get _controller =>
      _inferenceController ??= _inferenceControllerOverride ??
          ProjectInferenceController(postProcessor: _aiPostProcessor);

  // 已推理过的图片集合（快速查找）
  Set<String> _inferredImages = {};

  List<LabelDefinition> _labelDefinitions = [];

  /// 是否可撤销。
  bool get canUndo => _labelStore.canUndo;

  /// 是否可重做。
  bool get canRedo => _labelStore.canRedo;

  // Getters
  /// 当前项目对象（未加载时为 null）。
  Project? get project => _project;

  /// 当前图片的标签列表。
  List<Label> get labels => _labelStore.labels;

  /// 应用配置快照。
  AppConfig get config => _config;

  /// 当前项目配置。
  ProjectConfig? get projectConfig => _projectConfig;

  /// 当前标签定义列表。
  List<LabelDefinition> get labelDefinitions => _labelDefinitions;

  /// 是否处于加载过程。
  bool get isLoading => _isLoading;

  /// 标签是否有未保存修改。
  bool get isDirty => _labelStore.isDirty;

  /// 当前图像路径。
  String? get currentImagePath => _project?.currentImagePath;

  /// 当前索引（无项目时为 0）。
  int get currentIndex => _project?.currentIndex ?? 0;

  /// 图片总数（无项目时为 0）。
  int get totalImages => _project?.imageFiles.length ?? 0;

  /// 判断指定图片是否已被推理过。
  bool isImageInferred(String imagePath) {
    final imageName = imagePath.split('/').last;
    return _inferredImages.contains(imageName);
  }

  // 待保存的配置更新（AI自动填充标签定义后触发）
  ProjectConfig? _pendingConfigUpdate;

  /// 待持久化的配置更新（读取后会清空）。
  ProjectConfig? get pendingConfigUpdate {
    final update = _pendingConfigUpdate;
    _pendingConfigUpdate = null;
    return update;
  }

  /// 根据类别ID获取颜色
  Color getLabelColor(int classId) {
    return _labelDefinitions.colorForClassId(classId);
  }

  /// 根据类别ID获取标签定义
  LabelDefinition? getLabelDefinition(int classId) {
    return _labelDefinitions.findByClassId(classId);
  }

  /// 重新加载配置（保持当前图片索引，并尝试迁移当前标签数据）
  Future<void> reloadConfig(ProjectConfig config) async {
    final currentIndex = _project?.currentIndex ?? 0;
    final allowedClassIds =
        config.labelDefinitions.map((d) => d.classId).toSet();

    // 暂存当前内存中的标签数据（序列化为字符串），以便用新配置重新解析
    // 这样可以处理从 Box <-> BoxWithPoint 切换时的数据迁移
    final savedLabelLines = _labelStore.labels
        // Drop labels for deleted classes to avoid re-adding removed definitions.
        .where((l) => allowedClassIds.contains(l.id))
        .map((l) => l.toYoloLineFull())
        .toList();

    await loadProject(config);

    if (_project != null && currentIndex < _project!.imageFiles.length) {
      _project!.currentIndex = currentIndex;

      // 不直接从文件重载，而是用刚才暂存的数据+新定义进行重解析
      _labelStore.labels.clear();

      String getName(int id) {
        return _labelDefinitions.nameForClassId(id);
      }

      int failedLines = 0;
      Object? firstError;
      StackTrace? firstStack;

      for (final line in savedLabelLines) {
        try {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.isEmpty) continue;

          final classId = int.tryParse(parts[0]);
          if (classId == null) continue;

          final type = _labelDefinitions.typeForClassId(
            classId,
            fallback: LabelType.boxWithPoint,
          );

          final label = Label.fromYoloLine(line, getName, type: type);
          _labelStore.labels.add(label);
          // 忽略解析错位
        } catch (e, stack) {
          failedLines += 1;
          firstError ??= e;
          firstStack ??= stack;
        }
      }

      _labelStore.setCorruptedLines([]);

      if (failedLines > 0) {
        ErrorReporter.report(
          firstError ?? Exception('label parse failed'),
          AppErrorCode.unexpected,
          stackTrace: firstStack,
          details:
              'reload config: skipped $failedLines label lines during migration',
        );
      }

      // 自动补全可能缺失的定义
      _fillMissingDefinitions(_labelStore.labels);

      // 标记为 Dirty，因为我们修改了内存中的对象结构
      _labelStore.markDirty();

      notifyListeners();
    }
  }

  /// 加载项目
  Future<void> loadProject(ProjectConfig config) async {
    _isLoading = true;
    clearError();
    notifyListeners();

    try {
      final imageFiles = await _repository.listImageFiles(config.imagePath);

      final definitions = List<LabelDefinition>.from(config.labelDefinitions);
      final classNames = definitions.map((e) => e.name).toList();

      _project = Project(
        imagePath: config.imagePath,
        labelPath: config.labelPath,
        imageFiles: imageFiles,
      );

      _config = _config.copyWith(
        imagePath: config.imagePath,
        labelPath: config.labelPath,
        classNames: classNames,
      );

      _projectConfig = config;
      _labelDefinitions = definitions;

      // 初始化状态
      _inferredImages = Set.from(config.inferredImages);

      // 恢复上次查看的位置
      if (_project != null &&
          config.lastViewedIndex >= 0 &&
          config.lastViewedIndex < _project!.imageFiles.length) {
        _project!.currentIndex = config.lastViewedIndex;
      }

      if (imageFiles.isNotEmpty) {
        await _loadCurrentLabels();
      }
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.projectLoadFailed,
        stackTrace: stack,
        details: e.toString(),
        notify: false,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 切换到下一张图片
  ///
  /// 返回是否完成切换（保存失败会返回false）。
  Future<bool> nextImage({bool autoSave = true}) async {
    if (_project == null || !_project!.canGoNext) return false;

    final saved = await _saveIfDirty(autoSave: autoSave);
    if (!saved) return false;
    _project!.nextImage();
    _markConfigDirty(); // 记录位置
    _clearHistory();
    await _loadCurrentLabels();
    notifyListeners();
    return error == null;
  }

  /// 切换到上一张图片
  ///
  /// 返回是否完成切换（保存失败会返回false）。
  Future<bool> previousImage({bool autoSave = true}) async {
    if (_project == null || !_project!.canGoPrevious) return false;

    final saved = await _saveIfDirty(autoSave: autoSave);
    if (!saved) return false;
    _project!.previousImage();
    _markConfigDirty(); // 记录位置
    _clearHistory();
    await _loadCurrentLabels();
    notifyListeners();
    return error == null;
  }

  /// 跳转到指定图片
  ///
  /// 返回是否完成切换（保存失败会返回false）。
  Future<bool> goToImage(int index, {bool autoSave = true}) async {
    if (_project == null) return false;
    if (index < 0 || index >= _project!.imageFiles.length) return false;

    final saved = await _saveIfDirty(autoSave: autoSave);
    if (!saved) return false;
    _project!.currentIndex = index;
    _markConfigDirty(); // 记录位置
    _clearHistory();
    await _loadCurrentLabels();
    notifyListeners();
    return error == null;
  }

  /// 添加标签
  void addLabel(Label label) {
    _labelStore.addLabel(label);
    notifyListeners();
  }

  /// 更新标签
  void updateLabel(int index, Label label,
      {bool addToHistory = true, bool notify = true}) {
    _labelStore.updateLabel(index, label, addToHistory: addToHistory);
    if (notify) {
      notifyListeners();
    }
  }

  /// 手动触发一次通知（用于外部批量更新场景）。
  void notifyLabelChange() {
    notifyListeners();
  }

  /// 删除标签
  void removeLabel(int index) {
    _labelStore.removeLabel(index);
    notifyListeners();
  }

  /// 撤销
  void undo() {
    if (!_labelStore.undo()) return;
    notifyListeners();
  }

  /// 重做
  void redo() {
    if (!_labelStore.redo()) return;
    notifyListeners();
  }

  /// 添加到撤销历史
  void addToHistory() {
    _labelStore.addToHistory();
  }

  /// 保存标签
  ///
  /// 返回是否保存成功（或无需保存）。
  Future<bool> saveLabels() async {
    if (_project == null || !_labelStore.isDirty) return true;

    final labelPath = _project!.currentLabelPath;
    if (labelPath == null) return true;

    clearError();
    try {
      await _repository.writeLabels(
        labelPath,
        _labelStore.labels,
        labelDefinitions: _labelDefinitions,
        corruptedLines: _labelStore.corruptedLines,
      );
      _labelStore.markClean();
      notifyListeners();
      return true;
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.ioOperationFailed,
        stackTrace: stack,
        details: 'save labels: $labelPath ($e)',
        notify: false,
      );
      notifyListeners();
      return false;
    }
  }

  /// 更新全局配置
  void updateConfig(AppConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  /// 设置语言
  void setLocale(String locale) {
    if (_config.locale != locale) {
      _config = _config.copyWith(locale: locale);
      notifyListeners();
    }
  }

  /// 加载ONNX模型
  ///
  /// GPU加载失败时自动回退到CPU
  Future<bool> loadModel(String path, {bool useGpu = false}) async {
    final success = await _controller.loadModel(path, useGpu: useGpu);
    notifyListeners();
    return success;
  }

  /// 对当前图片执行AI自动标注
  ///
  /// [force] 是否强制推理。
  /// 如果为 false (默认)，则会检查该图片是否已经推理过，如果已推理过则跳过。
  /// 如果为 true (手动触发/批量)，则忽略历史状态强制推理。
  Future<void> autoLabelCurrent(
      {bool useGpu = false, bool force = false}) async {
    if (_project == null || _projectConfig == null) {
      setError(const AppError(AppErrorCode.projectNotLoaded));
      return;
    }

    final aiConfig = _projectConfig!.aiConfig;

    if (aiConfig.modelPath.isEmpty) {
      setError(const AppError(AppErrorCode.aiModelNotConfigured));
      return;
    }

    // 加载模型（如果需要）
    if (!_controller.hasModel ||
        _controller.loadedModelPath != aiConfig.modelPath) {
      final success = await loadModel(aiConfig.modelPath, useGpu: useGpu);
      if (!success) {
        setError(const AppError(AppErrorCode.aiModelLoadFailed));
        return;
      }
    }

    final imagePath = _project!.currentImagePath;
    if (imagePath == null) {
      setError(const AppError(AppErrorCode.imageNotSelected));
      return;
    }

    // 检查是否已推理过（仅在非强制模式下检查）
    final imageName = imagePath.split('/').last; // 使用文件名作为Key
    if (!force && _inferredImages.contains(imageName)) {
      // 已推理过，跳过
      return;
    }

    _isProcessing = true;
    clearError();
    notifyListeners();

    try {
      final newLabels = await _controller.inferLabels(
        imagePath: imagePath,
        config: aiConfig,
        labelDefinitions: _labelDefinitions,
      );

      if (newLabels.isNotEmpty) {
        addToHistory();

        if (aiConfig.labelSaveMode == LabelSaveMode.overwrite) {
          _labelStore.replaceLabels(
            newLabels,
            corruptedLines: _labelStore.corruptedLines,
            markDirty: true,
          );
        } else {
          _labelStore.labels.addAll(newLabels);
          _labelStore.markDirty();
        }

        // 标记为已推理
        _inferredImages.add(imageName);
        _markConfigDirty();

        _autoFillFromAiResults(newLabels);
      }
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.aiInferenceFailed,
        stackTrace: stack,
        details: e.toString(),
        notify: false,
      );
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 上次检测的标签数量
  int get lastDetectionCount => _labelStore.labels.length;

  /// 创建标签
  Label createLabel(int classId, double x, double y, double w, double h) {
    final xmin = (x - w / 2).clamp(0.0, 1.0);
    final ymin = (y - h / 2).clamp(0.0, 1.0);
    final xmax = (x + w / 2).clamp(0.0, 1.0);
    final ymax = (y + h / 2).clamp(0.0, 1.0);

    final name = labelNameForClass(classId);

    final label = Label(
      id: classId,
      name: name,
    );
    label.setFromCorners(xmin, ymin, xmax, ymax);
    return label;
  }

  /// 根据矩形创建标签（坐标为归一化）
  Label createLabelFromRect(int classId, Rect rect) {
    final label = Label(
      id: classId,
      name: labelNameForClass(classId),
    );
    label.setFromCorners(rect.left, rect.top, rect.right, rect.bottom);
    return label;
  }

  /// 获取标签显示名称（优先使用配置中的类名，其次定义列表）
  String labelNameForClass(int classId) {
    if (classId >= 0 && classId < _config.classNames.length) {
      return _config.classNames[classId];
    }
    return _labelDefinitions.nameForClassId(classId);
  }

  /// 加载当前图片的标签
  Future<void> _loadCurrentLabels() async {
    final labelPath = _project?.currentLabelPath;
    if (labelPath == null) {
      _labelStore.replaceLabels([], corruptedLines: [], markDirty: false);
      return;
    }

    String getName(int id) {
      return _labelDefinitions.nameForClassId(id);
    }

    clearError();
    try {
      final result = await _repository.readLabels(
        labelPath,
        getName,
        labelDefinitions: _labelDefinitions,
      );

      _labelStore.replaceLabels(
        result.$1,
        corruptedLines: result.$2,
        markDirty: false,
      );

      // 多边形标签需从顶点计算边界框
      for (final label in _labelStore.labels) {
        if (_labelDefinitions.typeForClassId(label.id) == LabelType.polygon) {
          label.updateBboxFromPoints();
        }
      }

      // 检查是否有未定义的标签，并自动补全定义
      _fillMissingDefinitions(_labelStore.labels);

      _labelStore.markClean();
    } catch (e, stack) {
      _labelStore.replaceLabels([], corruptedLines: [], markDirty: false);
      reportError(
        e,
        AppErrorCode.ioOperationFailed,
        stackTrace: stack,
        details: 'load labels: $labelPath ($e)',
        notify: false,
      );
    }
  }

  /// 从AI结果自动填充缺失的标签定义
  void _autoFillFromAiResults(List<Label> newLabels) {
    if (newLabels.isEmpty) return;
    _fillMissingDefinitions(newLabels);
  }

  /// 根据标签列表填充缺失的定义
  void _fillMissingDefinitions(List<Label> labels) {
    final updated =
        _aiPostProcessor.fillMissingDefinitions(labels, _labelDefinitions);
    if (identical(updated, _labelDefinitions)) return;

    _labelDefinitions = updated;

    _config = _config.copyWith(
      classNames: _labelDefinitions.map((e) => e.name).toList(),
    );

    if (_projectConfig != null) {
      _projectConfig = _projectConfig!.copyWith(
        labelDefinitions: _labelDefinitions,
      );
      _pendingConfigUpdate = _projectConfig;
    }
  }

  /// 标记配置为脏（需要保存），并更新内存中的状态到 Config 对象
  void _markConfigDirty() {
    if (_project == null || _projectConfig == null) return;

    _projectConfig = _projectConfig!.copyWith(
      lastViewedIndex: _project!.currentIndex,
      inferredImages: _inferredImages.toList(),
    );

    // 触发保存
    _pendingConfigUpdate = _projectConfig;
  }

  /// 如有修改则保存
  Future<bool> _saveIfDirty({required bool autoSave}) async {
    if (!_labelStore.isDirty) return true;
    if (!autoSave) {
      setError(const AppError(AppErrorCode.unsavedChanges));
      return false;
    }
    return saveLabels();
  }

  /// 清除撤销/重做历史
  void _clearHistory() {
    _labelStore.clearHistory();
  }
}
