import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path/path.dart' as path;
import '../../app/theme.dart';
import '../../providers/project_provider.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/project_config.dart';
import '../../models/label_definition.dart';
import '../../pages/project_settings_page.dart';
import '../../services/app/app_error.dart';
import '../../services/image/image_repository.dart';
import '../../services/labels/label_file_repository.dart';
import '../../services/app/app_services.dart';
import '../../utils/toast_utils.dart';

/// 主工具栏
///
/// 包含项目标题、文件操作、导航控制、设置按钮和状态信息。
class MainToolbar extends StatelessWidget {
  const MainToolbar({
    super.key,
    this.imageRepository,
    this.labelRepository,
  });

  /// 注入图片仓库，便于测试或替换默认文件系统实现。
  final ImageRepository? imageRepository;

  /// 注入标签仓库，便于测试或替换默认文件系统实现。
  final LabelFileRepository? labelRepository;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.getBorderColor(context), width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildLogo(context),
          const SizedBox(width: 24),
          _buildFileActions(context),
          const SizedBox(width: 16),
          _buildDivider(context),
          const SizedBox(width: 16),
          _buildNavigationControls(context),
          const SizedBox(width: 16),
          _buildDivider(context),
          const SizedBox(width: 8),
          _buildSettingsButton(context),
          const SizedBox(width: 16),
          _buildDivider(context),
          const SizedBox(width: 16),
          const _ClassSelector(),
          const Spacer(),
          _buildStatusInfo(context),
        ],
      ),
    );
  }

  /// 构建项目标题
  Widget _buildLogo(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final l10n = AppLocalizations.of(context)!;
    final projectName =
        projectProvider.projectConfig?.name ?? l10n.unknownProjectName;

    return Text(
      l10n.projectTitle(projectName),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.getTextPrimary(context),
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 构建文件操作按钮
  Widget _buildFileActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _ToolbarButton(
          icon: Icons.exit_to_app,
          tooltip: l10n.exitProject,
          onPressed: () => _exitProject(context),
        ),
        const SizedBox(width: 4),
        _ToolbarButton(
          icon: Icons.save_outlined,
          tooltip: l10n.save,
          onPressed: () => _save(context),
        ),
      ],
    );
  }

  /// 退出项目（必要时提示未保存更改）。
  ///
  /// 当项目处于 Dirty 状态时，会弹出确认对话框；选择保存会先尝试写盘。
  Future<void> _exitProject(BuildContext context) async {
    final projectProvider = context.read<ProjectProvider>();
    final l10n = AppLocalizations.of(context)!;

    if (projectProvider.isDirty) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.unsavedChangesTitle),
          content: Text(l10n.unsavedChangesMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.discard),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('save'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: Text(l10n.saveAndExit),
            ),
          ],
        ),
      );

      if (result == 'cancel' || result == null) return;

      if (result == 'save') {
        final saved = await projectProvider.saveLabels();
        if (!saved) {
          if (!context.mounted) return;
          final error = projectProvider.error ??
              const AppError(AppErrorCode.ioOperationFailed);
          ToastUtils.showError(context, error, l10n);
          return;
        }
      }
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 构建导航控制按钮
  Widget _buildNavigationControls(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        _ToolbarButton(
          icon: Icons.arrow_back,
          tooltip: '${l10n.prevImage} (A)',
          onPressed: projectProvider.project?.canGoPrevious == true
              ? () => _navigate(context, previous: true)
              : null,
        ),
        const SizedBox(width: 4),
        _ToolbarButton(
          icon: Icons.arrow_forward,
          tooltip: '${l10n.nextImage} (D)',
          onPressed: projectProvider.project?.canGoNext == true
              ? () => _navigate(context, previous: false)
              : null,
        ),
        const SizedBox(width: 4),
        _ToolbarButton(
          icon: Icons.delete_outline,
          tooltip: l10n.deleteImageAndLabel,
          onPressed: projectProvider.project != null
              ? () => _deleteCurrentImage(context)
              : null,
        ),
      ],
    );
  }

  /// 删除当前图片和标签，并在删除后刷新项目状态。
  ///
  /// 删除成功后会重新加载项目配置并校正当前索引，避免跳转到无效位置。
  void _deleteCurrentImage(BuildContext context) async {
    final projectProvider = context.read<ProjectProvider>();
    final l10n = AppLocalizations.of(context)!;
    final services = context.read<AppServices>();
    final project = projectProvider.project;

    if (project == null || project.imageFiles.isEmpty) return;

    // 确认删除
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteImageAndLabel),
        content: Text(l10n.deleteImageConfirm),
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

    if (confirmed != true) return;

    final currentImagePath = project.currentImagePath;
    if (currentImagePath == null) return;

    // 计算下一张的索引
    final currentIndex = project.currentIndex;

    try {
      final imageRepo = imageRepository ?? services.imageRepository;
      final labelRepo = labelRepository ?? services.labelRepository;

      // 删除图片文件
      await imageRepo.deleteIfExists(currentImagePath);

      // 删除标签文件
      final baseName = path.basenameWithoutExtension(currentImagePath);
      final labelPath = path.join(project.labelPath, '$baseName.txt');
      await labelRepo.deleteIfExists(labelPath);

      // 重新加载项目配置（不迁移标签，避免写入到其他图片）
      if (projectProvider.projectConfig != null) {
        await projectProvider.loadProject(projectProvider.projectConfig!);

        final newTotalImages = projectProvider.project?.imageFiles.length ?? 0;
        if (newTotalImages > 0) {
          final newIndex = currentIndex >= newTotalImages
              ? newTotalImages - 1
              : currentIndex;
          await projectProvider.goToImage(newIndex);
        }
      }

      if (context.mounted) {
        ToastUtils.show(context, l10n.imageDeleted);
      }
    } catch (e, stack) {
      if (context.mounted) {
        ToastUtils.showException(
          context,
          e,
          AppErrorCode.ioOperationFailed,
          l10n,
          stackTrace: stack,
          details: 'delete image: $currentImagePath ($e)',
          message: l10n.toolbarDeleteFailed(e.toString()),
        );
      }
    }
  }

  /// 构建设置按钮
  Widget _buildSettingsButton(BuildContext context) {
    final projectProvider = context.read<ProjectProvider>();
    final l10n = AppLocalizations.of(context)!;
    final services = context.read<AppServices>();

    return _ToolbarButton(
      icon: Icons.settings_outlined,
      tooltip: l10n.toolbarSettingsTooltip,
      onPressed: () {
        if (projectProvider.project != null) {
          final config = projectProvider.projectConfig ??
              ProjectConfig(
                id: projectProvider.project!.imagePath,
                name: l10n.currentProjectName,
                imagePath: projectProvider.project!.imagePath,
                labelPath: projectProvider.project!.labelPath,
                labelDefinitions: projectProvider.labelDefinitions,
              );

          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => ProjectSettingsPage(
                      project: config,
                      batchInferenceService: services.batchInferenceService,
                    )),
          );
        }
      },
    );
  }

  /// 构建状态信息（包含未保存提示、当前图片索引与标签数量）。
  Widget _buildStatusInfo(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final project = projectProvider.project;
    final l10n = AppLocalizations.of(context)!;

    if (project == null) {
      return Text(
        l10n.noProjectOpen,
        style: TextStyle(color: AppTheme.getTextMuted(context), fontSize: 13),
      );
    }

    return Row(
      children: [
        // 未保存指示器
        if (projectProvider.isDirty)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: AppTheme.warningColor,
              shape: BoxShape.circle,
            ),
          ),
        // 图片索引
        Text(
          l10n.imageIndex(project.currentIndex + 1, project.imageFiles.length),
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        // 标签数量
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.getOverlayColor(context),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            l10n.labelsCount(projectProvider.labels.length),
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建分隔线
  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: AppTheme.getBorderColor(context),
    );
  }

  /// 执行图片导航，并在失败时提示错误。
  Future<void> _navigate(BuildContext context, {required bool previous}) async {
    final projectProvider = context.read<ProjectProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final moved = previous
        ? await projectProvider.previousImage(
            autoSave: settingsProvider.autoSaveOnNavigate,
          )
        : await projectProvider.nextImage(
            autoSave: settingsProvider.autoSaveOnNavigate,
          );
    if (!context.mounted) return;
    if (!moved && projectProvider.error != null) {
      ToastUtils.showError(context, projectProvider.error!, l10n);
    }
  }

  /// 保存标签并反馈结果。
  Future<void> _save(BuildContext context) async {
    final projectProvider = context.read<ProjectProvider>();
    final l10n = AppLocalizations.of(context)!;
    final saved = await projectProvider.saveLabels();
    if (!context.mounted) return;
    if (saved) {
      ToastUtils.show(context, l10n.labelsSaved);
    } else {
      final error = projectProvider.error ??
          const AppError(AppErrorCode.ioOperationFailed);
      ToastUtils.showError(context, error, l10n);
    }
  }
}

/// 工具栏按钮
class _ToolbarButton extends StatelessWidget {
  /// 图标。
  final IconData icon;

  /// 悬停提示文本。
  final String tooltip;

  /// 点击回调（为 null 时显示禁用样式）。
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null
                  ? AppTheme.getTextMuted(context).withValues(alpha: 0.5)
                  : AppTheme.getTextSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// 类别选择器（确保当前类别与定义列表保持一致）。
class _ClassSelector extends StatelessWidget {
  const _ClassSelector();

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final canvasProvider = context.watch<CanvasProvider>();
    final definitions = projectProvider.labelDefinitions;

    if (definitions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.getOverlayColor(context),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          AppLocalizations.of(context)!.noClasses,
          style: TextStyle(color: AppTheme.getTextMuted(context), fontSize: 12),
        ),
      );
    }

    final currentId = canvasProvider.currentClassId;
    final matchedDef = definitions.findByClassId(currentId);
    final currentDef = matchedDef ?? definitions.first;

    // 如果当前 ID 无效，自动修正为第一个 ID。
    if (matchedDef == null && definitions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        canvasProvider.setCurrentClassId(definitions.first.classId);
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.getOverlayColor(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: PopupMenuButton<int>(
        initialValue: currentDef.classId,
        tooltip: '',
        offset: const Offset(0, 40),
        onSelected: (value) => canvasProvider.setCurrentClassId(value),
        itemBuilder: (context) => definitions.map((def) {
          return PopupMenuItem<int>(
            value: def.classId,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: def.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${def.classId}. ${def.name}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          );
        }).toList(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: currentDef.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${currentDef.classId}. ${currentDef.name}',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.getTextPrimary(context)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 18, color: AppTheme.getTextMuted(context)),
          ],
        ),
      ),
    );
  }
}
