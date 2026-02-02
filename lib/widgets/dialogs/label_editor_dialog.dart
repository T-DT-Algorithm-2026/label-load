import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/label_definition.dart';

/// 标签定义编辑对话框
///
/// 用于添加或编辑标签定义，包括ID、名称、颜色和类型。
class LabelEditorDialog extends StatefulWidget {
  /// 要编辑的标签定义，为null时创建新定义
  final LabelDefinition? definition;

  /// 新标签的classId（仅创建时使用）
  final int? nextClassId;

  /// 已使用的颜色列表（用于自动选择不重复的颜色）
  final List<Color> usedColors;

  const LabelEditorDialog({
    super.key,
    this.definition,
    this.nextClassId,
    this.usedColors = const [],
  });

  @override
  State<LabelEditorDialog> createState() => _LabelEditorDialogState();
}

class _LabelEditorDialogState extends State<LabelEditorDialog> {
  /// 标签名称输入控制器。
  late TextEditingController _nameController;

  /// 当前选择颜色。
  late Color _color;

  /// 当前标签类型。
  late LabelType _type;

  /// 当前 classId。
  late int _classId;

  /// 是否处于编辑模式（definition 非空）。
  bool get _isEditing => widget.definition != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.definition?.name ?? '');

    if (widget.definition != null) {
      _color = widget.definition!.color;
    } else {
      // 智能选择默认颜色：在色板中找第一个未被使用的颜色
      // 如果都用过了，随机选一个
      _color = LabelPalettes.extendedPalette.firstWhere(
        (c) => !widget.usedColors.contains(c),
        orElse: () => LabelPalettes.extendedPalette[
            Random().nextInt(LabelPalettes.extendedPalette.length)],
      );
    }

    _type = widget.definition?.type ?? LabelType.box;
    _classId = widget.definition?.classId ?? widget.nextClassId ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(_isEditing ? l10n.editLabel : l10n.addLabel),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildClassIdField(l10n),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.labelName),
            ),
            const SizedBox(height: 16),
            _buildColorPicker(l10n),
            const SizedBox(height: 16),
            _buildTypePicker(l10n),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  /// 构建类别ID输入字段
  Widget _buildClassIdField(AppLocalizations l10n) {
    if (_isEditing) {
      // 编辑时只读显示
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Text('${l10n.classIdLabel}: '),
            Text('$_classId',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else {
      // 创建时可编辑
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          decoration: InputDecoration(labelText: l10n.classIdLabel),
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: '$_classId'),
          onChanged: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null && parsed >= 0) {
              _classId = parsed;
            }
          },
        ),
      );
    }
  }

  /// 构建颜色选择器
  Widget _buildColorPicker(AppLocalizations l10n) {
    return Row(
      children: [
        Text(l10n.colorLabel),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showColorPicker,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
        ),
      ],
    );
  }

  /// 显示颜色选择对话框
  void _showColorPicker() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pickColor),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _color,
            onColorChanged: (color) {
              setState(() => _color = color);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  /// 构建类型选择器
  Widget _buildTypePicker(AppLocalizations l10n) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.labelType,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: PopupMenuButton<LabelType>(
        initialValue: _type,
        offset: const Offset(0, 40),
        onSelected: (value) => setState(() => _type = value),
        itemBuilder: (context) => LabelType.values.map((type) {
          return PopupMenuItem<LabelType>(
            value: type,
            child: Text(_getTypeName(type)),
          );
        }).toList(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_getTypeName(_type)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  /// 获取类型显示名称。
  String _getTypeName(LabelType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case LabelType.box:
        return l10n.labelTypeBox;
      case LabelType.boxWithPoint:
        return l10n.labelTypeBoxWithPoint;
      case LabelType.polygon:
        return l10n.labelTypePolygon;
    }
  }

  /// 保存标签定义
  void _save() {
    if (_nameController.text.isNotEmpty) {
      final def = LabelDefinition(
        classId: _classId,
        name: _nameController.text,
        color: _color,
        type: _type,
      );
      Navigator.of(context).pop(def);
    }
  }
}
