import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../app/theme.dart';

/// 目录选择器组件
class DirectorySelector extends StatelessWidget {
  /// 显示在选择器中的标签文本。
  final String label;

  /// 当前已选择的目录（为空则显示占位文案）。
  final String? value;

  /// 点击“选择目录”按钮的回调。
  final VoidCallback onSelect;

  const DirectorySelector({
    super.key,
    required this.label,
    required this.value,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.getBorderColor(context)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.folder,
                    size: 18, color: AppTheme.getTextMuted(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value ?? l10n.notSelected,
                    style: TextStyle(
                      color: value != null
                          ? AppTheme.getTextPrimary(context)
                          : AppTheme.getTextMuted(context),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onSelect,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.getCardColor(context),
            foregroundColor: AppTheme.getTextPrimary(context),
          ),
          child: Text(l10n.selectDirButton),
        ),
      ],
    );
  }
}

/// 文件选择器组件
class FileSelector extends StatelessWidget {
  /// 未选择时显示的占位文本。
  final String label;

  /// 当前已选择的文件路径。
  final String? value;

  /// 点击“选择文件”按钮的回调。
  final VoidCallback onSelect;

  const FileSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.getBorderColor(context)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.description,
                    size: 18, color: AppTheme.getTextMuted(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value ?? label,
                    style: TextStyle(
                      color: value != null
                          ? AppTheme.getTextPrimary(context)
                          : AppTheme.getTextMuted(context),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onSelect,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.getCardColor(context),
            foregroundColor: AppTheme.getTextPrimary(context),
          ),
          child: Text(l10n.selectFileButton),
        ),
      ],
    );
  }
}

/// 数字输入框组件
class NumberField extends StatelessWidget {
  /// 输入框上方的标签。
  final String label;

  /// 输入控制器，由外部状态管理。
  final TextEditingController controller;

  const NumberField({
    super.key,
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
