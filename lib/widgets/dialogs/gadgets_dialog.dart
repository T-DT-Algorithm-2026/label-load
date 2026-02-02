import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../app/theme.dart';
import 'gadgets/batch_rename_widget.dart';
import 'gadgets/xyxy2xywh_widget.dart';
import 'gadgets/bbox_expand_widget.dart';
import 'gadgets/check_and_fix_widget.dart';
import 'gadgets/convert_labels_widget.dart';
import 'gadgets/delete_keypoints_widget.dart';
import 'gadgets/add_bbox_widget.dart';

/// 工具箱对话框
///
/// 提供各种数据处理工具，包括批量重命名、坐标转换、边界框扩展等。
class GadgetsDialog extends StatefulWidget {
  const GadgetsDialog({super.key});

  @override
  State<GadgetsDialog> createState() => _GadgetsDialogState();
}

class _GadgetsDialogState extends State<GadgetsDialog> {
  /// 当前选中的工具索引。
  int _selectedIndex = 0;

  /// 工具列表（预创建，避免重复构建）
  late final List<Widget> _gadgetWidgets;

  /// 工具元数据（顺序需与 [_gadgetWidgets] 一致）。
  static const List<_GadgetMeta> _gadgetsMeta = [
    _GadgetMeta(
        icon: Icons.drive_file_rename_outline,
        titleKey: 'gadgetRename',
        descKey: 'gadgetRenameDesc'),
    _GadgetMeta(
        icon: Icons.transform,
        titleKey: 'gadgetCoord',
        descKey: 'gadgetCoordDesc'),
    _GadgetMeta(
        icon: Icons.zoom_out_map,
        titleKey: 'gadgetExpand',
        descKey: 'gadgetExpandDesc'),
    _GadgetMeta(
        icon: Icons.check_circle_outline,
        titleKey: 'gadgetCheck',
        descKey: 'gadgetCheckDesc'),
    _GadgetMeta(
        icon: Icons.swap_horiz,
        titleKey: 'gadgetConvert',
        descKey: 'gadgetConvertDesc'),
    _GadgetMeta(
        icon: Icons.delete_sweep,
        titleKey: 'gadgetPointDelete',
        descKey: 'gadgetPointDeleteDesc'),
    _GadgetMeta(
        icon: Icons.add_box,
        titleKey: 'gadgetBboxAdd',
        descKey: 'gadgetBboxAddDesc'),
  ];

  @override
  void initState() {
    super.initState();
    _gadgetWidgets = const [
      BatchRenameWidget(),
      Xyxy2XywhWidget(),
      BboxExpandWidget(),
      CheckAndFixWidget(),
      ConvertLabelsWidget(),
      DeleteKeypointsWidget(),
      AddBboxWidget(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: AppTheme.getCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 800,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(l10n),
            const SizedBox(height: 16),
            Divider(color: AppTheme.getBorderColor(context)),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(l10n),
                  const SizedBox(width: 16),
                  VerticalDivider(color: AppTheme.getBorderColor(context)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _gadgetWidgets,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      children: [
        const Icon(Icons.build, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Text(
          l10n.gadgetsTitle,
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close, color: AppTheme.getTextMuted(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// 构建侧边栏
  Widget _buildSidebar(AppLocalizations l10n) {
    return SizedBox(
      width: 200,
      child: ListView.builder(
        itemCount: _gadgetsMeta.length,
        itemBuilder: (context, index) {
          final meta = _gadgetsMeta[index];
          final isSelected = index == _selectedIndex;
          return _GadgetListTile(
            icon: meta.icon,
            title: _getLocalizedString(l10n, meta.titleKey),
            description: _getLocalizedString(l10n, meta.descKey),
            isSelected: isSelected,
            onTap: () => setState(() => _selectedIndex = index),
          );
        },
      ),
    );
  }

  /// 根据 key 获取本地化字符串。
  String _getLocalizedString(AppLocalizations l10n, String key) {
    switch (key) {
      case 'gadgetRename':
        return l10n.gadgetRename;
      case 'gadgetRenameDesc':
        return l10n.gadgetRenameDesc;
      case 'gadgetCoord':
        return l10n.gadgetCoord;
      case 'gadgetCoordDesc':
        return l10n.gadgetCoordDesc;
      case 'gadgetExpand':
        return l10n.gadgetExpand;
      case 'gadgetExpandDesc':
        return l10n.gadgetExpandDesc;
      case 'gadgetCheck':
        return l10n.gadgetCheck;
      case 'gadgetCheckDesc':
        return l10n.gadgetCheckDesc;
      case 'gadgetConvert':
        return l10n.gadgetConvert;
      case 'gadgetConvertDesc':
        return l10n.gadgetConvertDesc;
      case 'gadgetPointDelete':
        return l10n.gadgetPointDelete;
      case 'gadgetPointDeleteDesc':
        return l10n.gadgetPointDeleteDesc;
      case 'gadgetBboxAdd':
        return l10n.gadgetBboxAdd;
      case 'gadgetBboxAddDesc':
        return l10n.gadgetBboxAddDesc;
      default:
        return key;
    }
  }
}

/// 工具元数据
class _GadgetMeta {
  /// 图标。
  final IconData icon;

  /// 标题本地化 key。
  final String titleKey;

  /// 描述本地化 key。
  final String descKey;

  const _GadgetMeta({
    required this.icon,
    required this.titleKey,
    required this.descKey,
  });
}

/// 工具列表项
class _GadgetListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _GadgetListTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppTheme.primaryColor.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.getTextMuted(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.getTextPrimary(context),
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
