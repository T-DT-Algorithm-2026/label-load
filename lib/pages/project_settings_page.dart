import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/project_config.dart';
import '../models/label_definition.dart';
import '../models/ai_config.dart';
import '../providers/project_list_provider.dart';
import '../providers/project_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/dialogs/label_editor_dialog.dart';
import '../widgets/dialogs/ai_settings_widget.dart';
import '../services/gadgets/gadget_service.dart';
import '../services/inference/batch_inference_service.dart';
import '../services/image/image_repository.dart';
import '../services/labels/label_definition_io.dart';
import '../services/files/file_picker_service.dart';
import '../services/app/app_error.dart';
import '../services/app/app_services.dart';
import '../utils/toast_utils.dart';

/// 项目设置页面
///
/// 用于创建新项目或编辑现有项目的配置，包括名称、路径、标签定义和AI设置。
class ProjectSettingsPage extends StatefulWidget {
  /// 要编辑的项目配置，为null时创建新项目
  final ProjectConfig? project;

  /// 注入批量推理服务，便于测试或替换默认实现。
  final BatchInferenceService? batchInferenceService;

  /// 注入标签定义导入导出服务，便于测试或替换默认实现。
  final LabelDefinitionIo? labelDefinitionIo;

  /// 注入图片仓库，便于测试或替换默认实现。
  final ImageRepository? imageRepository;

  /// 注入文件选择服务，便于测试或替换默认实现。
  final FilePickerService? filePickerService;

  const ProjectSettingsPage({
    super.key,
    this.project,
    this.batchInferenceService,
    this.labelDefinitionIo,
    this.imageRepository,
    this.filePickerService,
  });

  @override
  State<ProjectSettingsPage> createState() => _ProjectSettingsPageState();
}

class _ProjectSettingsPageState extends State<ProjectSettingsPage> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  String? _imagePath;
  String? _labelPath;
  List<LabelDefinition> _labels = [];

  late AiConfig _aiConfig;
  List<String> _inferredImages = []; // 本地状态跟踪已推理图片

  // 批量推理状态
  bool _isBatchRunning = false;
  int _batchCurrent = 0;
  int _batchTotal = 0;
  late final BatchInferenceService _batchInferenceService;
  late final LabelDefinitionIo _labelDefinitionIo;
  late final ImageRepository _imageRepository;
  late final FilePickerService _filePickerService;
  late final GadgetService _gadgetService;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descController =
        TextEditingController(text: widget.project?.description ?? '');
    _imagePath = widget.project?.imagePath;
    _labelPath = widget.project?.labelPath;
    _labels = widget.project != null
        ? List.from(widget.project!.labelDefinitions)
        : [];
    _aiConfig = widget.project?.aiConfig.copyWith() ?? AiConfig();
    _inferredImages = widget.project?.inferredImages.toList() ?? [];
    _batchInferenceService =
        widget.batchInferenceService ?? services.batchInferenceService;
    _labelDefinitionIo = widget.labelDefinitionIo ?? services.labelDefinitionIo;
    _imageRepository = widget.imageRepository ?? services.imageRepository;
    _filePickerService = widget.filePickerService ?? services.filePickerService;
    _gadgetService = services.gadgetService;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 将标签类型转为本地化文案。
  String _getLabelTypeName(LabelType type, AppLocalizations l10n) {
    switch (type) {
      case LabelType.box:
        return l10n.labelTypeBox;
      case LabelType.boxWithPoint:
        return l10n.labelTypeBoxWithPoint;
      case LabelType.polygon:
        return l10n.labelTypePolygon;
    }
  }

  /// 选择目录路径
  Future<void> _pickPath(bool isImage) async {
    final result = await _filePickerService.getDirectoryPath();
    if (result != null) {
      setState(() {
        if (isImage) {
          _imagePath = result;
        } else {
          _labelPath = result;
        }
      });
    }
  }

  /// 添加标签定义
  void _addLabel() async {
    final nextId = _labels.nextClassId;
    final usedColors = _labels.map((e) => e.color).toList();
    final result = await showDialog<LabelDefinition>(
      context: context,
      builder: (context) => LabelEditorDialog(
        nextClassId: nextId,
        usedColors: usedColors,
      ),
    );
    if (result != null) {
      setState(() => _labels.add(result));
    }
  }

  /// 编辑标签定义
  void _editLabel(int index) async {
    final result = await showDialog<LabelDefinition>(
      context: context,
      builder: (context) => LabelEditorDialog(definition: _labels[index]),
    );
    if (result != null) {
      setState(() => _labels[index] = result);
    }
  }

  /// 删除标签定义
  void _deleteLabel(int index) async {
    final label = _labels[index];
    final l10n = AppLocalizations.of(context)!;
    final hasLabelPath = _labelPath != null && _labelPath!.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteLabelTitle),
        content: Text(hasLabelPath
            ? l10n.deleteLabelContentWithFiles(label.name, label.classId)
            : l10n.deleteLabelContent(label.name, label.classId)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 从标签文件中删除该类别
      if (hasLabelPath) {
        final (filesModified, labelsDeleted) =
            await _gadgetService.deleteClassFromLabels(
          _labelPath!,
          label.classId,
        );
        if (mounted && labelsDeleted > 0) {
          ToastUtils.show(
            context,
            l10n.labelsDeletedFromFiles(labelsDeleted, filesModified),
          );
        }
      }

      setState(() => _labels.removeAt(index));
    }
  }

  /// 导出标签定义
  Future<void> _exportLabels() async {
    final l10n = AppLocalizations.of(context)!;

    if (_labels.isEmpty) {
      ToastUtils.show(context, l10n.noLabelsToExport);
      return;
    }

    final result = await _filePickerService.saveFile(
      dialogTitle: l10n.exportLabels,
      fileName: 'label_definitions.json',
      allowedExtensions: ['json'],
    );

    if (result != null) {
      try {
        await _labelDefinitionIo.exportToFile(result, _labels);
        if (mounted) {
          ToastUtils.show(context, l10n.exportSuccess);
        }
      } catch (e, stack) {
        if (mounted) {
          ToastUtils.showException(
            context,
            e,
            AppErrorCode.ioOperationFailed,
            l10n,
            stackTrace: stack,
            details: 'export labels: $e',
            message: '${l10n.exportFailed}: $e',
          );
        }
      }
    }
  }

  /// 导入标签定义
  Future<void> _importLabels() async {
    final l10n = AppLocalizations.of(context)!;

    final result = await _filePickerService.pickFile(
      dialogTitle: l10n.importLabels,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      try {
        final importedLabels = await _labelDefinitionIo.importFromFile(result);

        setState(() {
          _labels = importedLabels;
        });

        if (mounted) {
          ToastUtils.show(context, l10n.importSuccess);
        }
      } catch (e, stack) {
        if (mounted) {
          ToastUtils.showException(
            context,
            e,
            AppErrorCode.ioOperationFailed,
            l10n,
            stackTrace: stack,
            details: 'import labels: $e',
            message: '${l10n.importFailed}: $e',
          );
        }
      }
    }
  }

  /// 执行批量推理
  Future<void> _runBatchInference() async {
    final l10n = AppLocalizations.of(context)!;
    final settingsProvider = context.read<SettingsProvider>();

    // 检查必要条件
    if (_imagePath == null || _imagePath!.isEmpty) {
      ToastUtils.show(context, l10n.imageDir);
      return;
    }

    if (_labelPath == null || _labelPath!.isEmpty) {
      ToastUtils.show(context, l10n.labelDir);
      return;
    }

    if (_aiConfig.modelPath.isEmpty) {
      ToastUtils.show(context, l10n.selectModel);
      return;
    }

    // 获取图片列表
    final imageFiles = await _imageRepository.listImagePaths(_imagePath!);
    if (imageFiles.isEmpty) {
      return;
    }

    setState(() {
      _isBatchRunning = true;
      _batchCurrent = 0;
      _batchTotal = 0;
    });

    try {
      final summary = await _batchInferenceService.run(
        imageDir: _imagePath!,
        labelDir: _labelPath!,
        config: _aiConfig,
        definitions: _labels,
        useGpu: settingsProvider.useGpu,
        shouldContinue: () => _isBatchRunning,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _batchCurrent = current;
            _batchTotal = total;
          });
        },
        onDefinitionsUpdated: (updated) {
          if (!mounted) return;
          setState(() {
            _labels = updated;
          });
        },
        onInferredImage: (fileName) {
          if (!_inferredImages.contains(fileName)) {
            _inferredImages.add(fileName);
          }
        },
      );

      if (!summary.modelLoaded) {
        if (mounted) {
          ToastUtils.show(context, l10n.modelLoadFailed);
        }
        return;
      }

      if (summary.lastError != null && mounted) {
        ToastUtils.showError(context, summary.lastError!, l10n);
        return;
      }

      if (summary.totalImages == 0) return;

      if (mounted) {
        ToastUtils.show(context, l10n.batchInferenceComplete);
      }
    } catch (e, stack) {
      if (mounted) {
        ToastUtils.showException(
          context,
          e,
          AppErrorCode.aiInferenceFailed,
          l10n,
          stackTrace: stack,
          details: 'batch inference: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBatchRunning = false);
      }
    }
  }

  /// 构建批量推理区域
  Widget _buildBatchInferenceSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.batchInference,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.batchInferenceDesc,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 12),
        if (_isBatchRunning) ...[
          LinearProgressIndicator(
            value: _batchTotal > 0 ? _batchCurrent / _batchTotal : null,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.batchInferenceRunning(_batchCurrent, _batchTotal),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isBatchRunning = false),
            icon: const Icon(Icons.stop),
            label: Text(l10n.cancel),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: _aiConfig.modelPath.isEmpty ? null : _runBatchInference,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.batchInference),
          ),
        ],
      ],
    );
  }

  /// 保存项目配置
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;

    if (_nameController.text.isEmpty) {
      ToastUtils.show(context, l10n.projectNameRequired);
      return;
    }

    final finalLabels = List<LabelDefinition>.from(_labels);
    finalLabels.sort((a, b) => a.classId.compareTo(b.classId));

    final config = ProjectConfig(
      id: widget.project?.id,
      name: _nameController.text,
      description: _descController.text,
      imagePath: _imagePath ?? '',
      labelPath: _labelPath ?? '',
      labelDefinitions: finalLabels,
      createdAt: widget.project?.createdAt,
      aiConfig: _aiConfig,
      lastViewedIndex: widget.project?.lastViewedIndex ?? 0,
      inferredImages: _inferredImages,
    );

    final provider = context.read<ProjectListProvider>();
    final projectProvider = context.read<ProjectProvider>();

    if (!_isEditing) {
      await provider.addProject(config);
    } else {
      await provider.updateProject(config);

      // 如果正在编辑当前活动项目，重新加载
      if (projectProvider.projectConfig?.id == config.id) {
        projectProvider.reloadConfig(config);
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 检查是否有未保存的更改
  Future<bool> _onWillPop() async {
    bool hasChanges = false;

    // 检查基本字段
    if (_nameController.text != (widget.project?.name ?? '') ||
        _descController.text != (widget.project?.description ?? '') ||
        _imagePath != (widget.project?.imagePath) ||
        _labelPath != (widget.project?.labelPath)) {
      hasChanges = true;
    }

    // 检查标签列表
    if (!hasChanges) {
      final origLabels = widget.project?.labelDefinitions ?? [];
      if (_labels.length != origLabels.length) {
        hasChanges = true;
      } else if (origLabels.isNotEmpty) {
        final origMap = {for (final l in origLabels) l.classId: l};
        for (final label in _labels) {
          final orig = origMap[label.classId];
          if (orig == null || label != orig) {
            hasChanges = true;
            break;
          }
        }
      } else if (_labels.isNotEmpty) {
        hasChanges = true;
      }
    }

    if (!hasChanges) return true;

    final l10n = AppLocalizations.of(context)!;
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.unsavedChangesTitle),
            content: Text(l10n.unsavedChangesMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.discard),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? l10n.editProject : l10n.newProject),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：基本信息和AI设置
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration:
                            InputDecoration(labelText: l10n.projectName),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descController,
                        decoration:
                            InputDecoration(labelText: l10n.projectDesc),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 24),
                      ListTile(
                        title: Text(l10n.imageDir),
                        subtitle: Text(_imagePath ?? l10n.notSelected),
                        trailing: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () => _pickPath(true),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      ListTile(
                        title: Text(l10n.labelDir),
                        subtitle: Text(_labelPath ?? l10n.notSelected),
                        trailing: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () => _pickPath(false),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 24),
                      AiSettingsWidget(
                        config: _aiConfig,
                        onChanged: (newConfig) {
                          setState(() {
                            _aiConfig = newConfig;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // 批量推理按钮
                      _buildBatchInferenceSection(l10n),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // 右侧：标签定义
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(l10n.tabLabels,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.file_upload),
                          tooltip: l10n.importLabels,
                          onPressed: _importLabels,
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download),
                          tooltip: l10n.exportLabels,
                          onPressed: _exportLabels,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addLabel,
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _labels.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final label = _labels[index];
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: label.color),
                            title: Text(label.name),
                            subtitle: Text(
                              l10n.labelDefinitionSubtitle(
                                label.classId,
                                _getLabelTypeName(label.type, l10n),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editLabel(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteLabel(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
