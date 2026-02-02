import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../providers/project_provider.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import '../../services/labels/label_type_converter.dart';
import '../../services/image/image_preview_provider.dart';
import '../../utils/toast_utils.dart';
import '../../services/app/app_services.dart';

/// 侧边栏
///
/// 包含标签列表和图片列表两个标签页。
class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    this.imagePreviewProvider,
  });

  /// 注入缩略图提供器，便于测试或替换预览策略。
  final ImagePreviewProvider? imagePreviewProvider;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        border: Border(
          left: BorderSide(color: AppTheme.getBorderColor(context), width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildTabs(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _LabelListTab(),
                _ImageListTab(
                  imagePreviewProvider: widget.imagePreviewProvider,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标签页栏（标签/图片）。
  Widget _buildTabs(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getElevatedColor(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.getBorderColor(context), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 2,
        labelColor: AppTheme.getTextPrimary(context),
        unselectedLabelColor: AppTheme.getTextMuted(context),
        tabs: [
          Tab(
              text: l10n.tabLabels,
              icon: const Icon(Icons.label_outline, size: 18)),
          Tab(
              text: l10n.tabImages,
              icon: const Icon(Icons.image_outlined, size: 18)),
        ],
      ),
    );
  }
}

/// 标签列表标签页
class _LabelListTab extends StatelessWidget {
  const _LabelListTab();

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final canvasProvider = context.watch<CanvasProvider>();
    final labels = projectProvider.labels;
    final l10n = AppLocalizations.of(context)!;

    if (labels.isEmpty) {
      return _buildEmptyState(context, l10n);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: labels.length,
      itemBuilder: (context, index) {
        final label = labels[index];
        final isSelected = index == canvasProvider.selectedLabelIndex &&
            canvasProvider.activeKeypointIndex == null;
        final hasPoints = label.points.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLabelTile(context, index, label, isSelected, hasPoints,
                projectProvider, canvasProvider),
            if (hasPoints)
              _buildReorderablePointsList(
                  context, index, label, canvasProvider, projectProvider),
          ],
        );
      },
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.label_off_outlined,
            size: 48,
            color: AppTheme.getTextMuted(context).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noLabels,
            style: TextStyle(color: AppTheme.getTextMuted(context)),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.drawToCreate,
            style: TextStyle(
              color: AppTheme.getTextMuted(context).withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标签项（包含选中状态、尺寸信息与删除入口）。
  Widget _buildLabelTile(
    BuildContext context,
    int index,
    Label label,
    bool isSelected,
    bool hasPoints,
    ProjectProvider projectProvider,
    CanvasProvider canvasProvider,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.2)
            : (index == canvasProvider.hoveredLabelIndex)
                ? AppTheme.getOverlayColor(context)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: AppTheme.primaryColor, width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: projectProvider.getLabelColor(label.id),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: _buildLabelTitle(
            context, index, label, isSelected, projectProvider),
        subtitle: Text(
          '${(label.width * 100).toStringAsFixed(0)}% × ${(label.height * 100).toStringAsFixed(0)}%'
          '${hasPoints ? ' • ${AppLocalizations.of(context)!.pointsCount(label.points.length)}' : ''}',
          style: TextStyle(
            color: AppTheme.getTextMuted(context),
            fontSize: 11,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppTheme.getTextMuted(context),
          hoverColor: AppTheme.errorColor.withValues(alpha: 0.2),
          onPressed: () => projectProvider.removeLabel(index),
        ),
        onTap: () => canvasProvider.selectLabel(index),
      ),
    );
  }

  /// 构建标签标题（点击可切换类别）。
  Widget _buildLabelTitle(
    BuildContext context,
    int index,
    Label label,
    bool isSelected,
    ProjectProvider projectProvider,
  ) {
    final className = projectProvider.labelDefinitions.nameForClassId(label.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (titleContext) => InkWell(
            onTap: () => _showLabelChangeMenu(
                titleContext, index, label, projectProvider),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    className,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: AppTheme.getTextMuted(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 显示类别切换菜单（必要时执行类型转换以保留数据）。
  void _showLabelChangeMenu(BuildContext context, int labelIndex, Label label,
      ProjectProvider projectProvider) {
    final definitions = projectProvider.labelDefinitions;
    if (definitions.isEmpty) return;

    final currentType = definitions.typeForClassId(label.id);

    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset position = button.localToGlobal(Offset.zero);

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + button.size.height,
        position.dx + 200,
        0,
      ),
      items: definitions.map((def) {
        final isCurrent = def.classId == label.id;
        final isSameType = def.type == currentType;

        return PopupMenuItem<int>(
          value: def.classId,
          child: Row(
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
              Expanded(
                child: Text(
                  def.name,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? AppTheme.primaryColor : null,
                  ),
                ),
              ),
              if (!isSameType)
                Icon(
                  Icons.swap_horiz,
                  size: 14,
                  color: AppTheme.getTextMuted(context),
                ),
            ],
          ),
        );
      }).toList(),
    ).then((newClassId) {
      if (newClassId != null && newClassId != label.id) {
        final newDef = definitions.findByClassId(newClassId);
        if (newDef != null) {
          final newType = newDef.type;
          final convertedLabel = LabelTypeConverter.convert(
            label,
            newClassId,
            currentType,
            newType,
          );
          projectProvider.updateLabel(labelIndex, convertedLabel);
        }
      }
    });
  }

  /// 构建可拖拽排序的关键点列表（同步调整选中关键点索引）。
  Widget _buildReorderablePointsList(
    BuildContext context,
    int labelIndex,
    Label label,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: label.points.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final newPoints = List<LabelPoint>.from(label.points);
        final item = newPoints.removeAt(oldIndex);
        newPoints.insert(newIndex, item);
        projectProvider.updateLabel(
            labelIndex, label.copyWith(points: newPoints));
        // 更新选中的关键点索引
        if (canvasProvider.activeKeypointIndex == oldIndex) {
          canvasProvider.setActiveKeypoint(newIndex);
        } else if (canvasProvider.activeKeypointIndex != null) {
          final active = canvasProvider.activeKeypointIndex!;
          if (oldIndex < active && newIndex >= active) {
            canvasProvider.setActiveKeypoint(active - 1);
          } else if (oldIndex > active && newIndex <= active) {
            canvasProvider.setActiveKeypoint(active + 1);
          }
        }
      },
      itemBuilder: (context, i) {
        return ReorderableDragStartListener(
          key: ValueKey('point_${labelIndex}_$i'),
          index: i,
          child: _buildPointTile(
              context, labelIndex, i, label.points[i], canvasProvider),
        );
      },
    );
  }

  /// 构建关键点项
  Widget _buildPointTile(
    BuildContext context,
    int labelIndex,
    int pointIndex,
    LabelPoint point,
    CanvasProvider canvasProvider,
  ) {
    final isPointSelected = (labelIndex == canvasProvider.selectedLabelIndex) &&
        (canvasProvider.activeKeypointIndex == pointIndex);

    // 可见性图标和颜色
    IconData visibilityIcon;
    Color visibilityColor;
    switch (point.visibility) {
      case 0:
        visibilityIcon = Icons.visibility_off;
        visibilityColor = AppTheme.getTextMuted(context);
        break;
      case 1:
        visibilityIcon = Icons.visibility_outlined;
        visibilityColor = Colors.orange;
        break;
      default:
        visibilityIcon = Icons.visibility;
        visibilityColor = Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20.0, bottom: 2),
      child: InkWell(
        onTap: () {
          canvasProvider.selectLabel(labelIndex);
          canvasProvider.setActiveKeypoint(pointIndex);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isPointSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.drag_indicator,
                  size: 14, color: AppTheme.getTextMuted(context)),
              const SizedBox(width: 4),
              Text(
                '${pointIndex + 1}',
                style: TextStyle(
                  color: isPointSelected
                      ? AppTheme.primaryColor
                      : AppTheme.getTextSecondary(context),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Icon(visibilityIcon, size: 14, color: visibilityColor),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '(${point.x.toStringAsFixed(3)}, ${point.y.toStringAsFixed(3)})',
                    style: TextStyle(
                        color: AppTheme.getTextMuted(context), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppTheme.getTextMuted(context),
                hoverColor: AppTheme.errorColor,
                onPressed: () => _deletePoint(context, labelIndex, pointIndex),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 删除关键点
  void _deletePoint(BuildContext context, int labelIndex, int pointIndex) {
    final project = Provider.of<ProjectProvider>(context, listen: false);
    final label = project.labels[labelIndex];
    if (pointIndex < label.points.length) {
      final newPoints = List<LabelPoint>.from(label.points);
      newPoints.removeAt(pointIndex);
      final newLabel = label.copyWith(points: newPoints);
      project.updateLabel(labelIndex, newLabel);
    }
  }
}

/// 图片列表标签页
class _ImageListTab extends StatelessWidget {
  const _ImageListTab({this.imagePreviewProvider});

  /// 注入图片预览提供器，便于测试或替换实现。
  final ImagePreviewProvider? imagePreviewProvider;

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final l10n = AppLocalizations.of(context)!;
    final project = projectProvider.project;

    if (project == null || !project.hasImages) {
      return _buildEmptyState(context, l10n);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: project.imageFiles.length,
      itemBuilder: (context, index) {
        final imagePath = project.imageFiles[index];
        final fileName = imagePath.split('/').last;
        final isSelected = index == project.currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppTheme.primaryColor, width: 1)
                : null,
          ),
          child: ListTile(
            dense: true,
            leading: _buildThumbnail(context, imagePath),
            title: Text(
              fileName,
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${index + 1} / ${project.imageFiles.length}',
              style: TextStyle(
                color: AppTheme.getTextMuted(context),
                fontSize: 11,
              ),
            ),
            onTap: () async {
              final settingsProvider = context.read<SettingsProvider>();
              final moved = await projectProvider.goToImage(
                index,
                autoSave: settingsProvider.autoSaveOnNavigate,
              );
              if (!context.mounted) return;
              final error = projectProvider.error;
              if (!moved && error != null) {
                ToastUtils.showError(
                  context,
                  error,
                  AppLocalizations.of(context)!,
                );
              }
            },
          ),
        );
      },
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 48,
            color: AppTheme.getTextMuted(context).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noImagesLoaded,
            style: TextStyle(color: AppTheme.getTextMuted(context)),
          ),
        ],
      ),
    );
  }

  /// 构建缩略图（使用预览提供器降低解码成本）。
  Widget _buildThumbnail(BuildContext context, String imagePath) {
    final services = context.read<AppServices>();
    final provider = imagePreviewProvider ?? services.imagePreviewProvider;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.getOverlayColor(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image(
          image: provider.create(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.image_outlined,
              color: AppTheme.getTextMuted(context),
              size: 20,
            );
          },
        ),
      ),
    );
  }
}
