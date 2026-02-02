import 'package:flutter/material.dart';

/// 标签类型枚举
enum LabelType {
  /// 纯边界框
  box,

  /// 边界框 + 关键点
  boxWithPoint,

  /// 多边形（语义分割）
  polygon,
}

/// 标签颜色调色板集合
///
/// 用于在未指定颜色时分配可读性较好的默认颜色。
class LabelPalettes {
  /// 默认调色板（长度较短，适用于小类别数量）
  static const List<Color> defaultPalette = [
    Color(0xFFEF4444), // Red
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime
    Color(0xFF14B8A6), // Teal
  ];

  /// 扩展调色板（覆盖更多类别）
  static const List<Color> extendedPalette = [
    Color(0xFFEF4444), // Red
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime
    Color(0xFF14B8A6), // Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFFD946EF), // Fuchsia
    Color(0xFF64748B), // Slate
    Color(0xFFE11D48), // Rose
    Color(0xFF0EA5E9), // Sky
  ];
}

/// 标签定义
///
/// 定义一个标签类别的属性，包括ID、名称、颜色和类型。
/// 在YOLO格式中，classId对应标签文件中的类别索引。
class LabelDefinition {
  /// 将颜色编码为 0xAARRGGBB 格式整数
  static int encodeColor(Color color) {
    return ((color.a * 255).round() << 24) |
        ((color.r * 255).round() << 16) |
        ((color.g * 255).round() << 8) |
        (color.b * 255).round();
  }

  /// 从 0xAARRGGBB 格式整数解码为颜色
  static Color decodeColor(int value) {
    return Color(value);
  }

  /// 类别ID，用于标签文件（YOLO格式的第一列）
  final int classId;

  /// 类别名称，用于显示
  final String name;

  /// 显示颜色
  final Color color;

  /// 标签类型
  final LabelType type;

  LabelDefinition({
    required this.classId,
    required this.name,
    required this.color,
    this.type = LabelType.box,
  });

  /// 从JSON创建定义
  ///
  /// [fallbackClassId] 用于兼容旧格式（基于列表索引的classId）
  factory LabelDefinition.fromJson(Map<String, dynamic> json,
      {int? fallbackClassId}) {
    final typeIndex = json['type'] as int? ?? 0;
    final classId = json['classId'] as int? ?? fallbackClassId ?? 0;
    return LabelDefinition(
      classId: classId,
      name: json['name'] as String,
      color: decodeColor(json['color'] as int),
      type: (typeIndex >= 0 && typeIndex < LabelType.values.length)
          ? LabelType.values[typeIndex]
          : LabelType.box,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'name': name,
      'color': encodeColor(color),
      'type': type.index,
    };
  }

  /// 创建副本并可选地修改部分字段
  LabelDefinition copyWith({
    int? classId,
    String? name,
    Color? color,
    LabelType? type,
  }) {
    return LabelDefinition(
      classId: classId ?? this.classId,
      name: name ?? this.name,
      color: color ?? this.color,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LabelDefinition &&
        other.classId == classId &&
        other.name == name &&
        other.color == color &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(classId, name, color, type);
}

/// 标签定义列表扩展方法
extension LabelDefinitionListExtension on List<LabelDefinition> {
  /// 根据classId查找定义，未找到返回null
  LabelDefinition? findByClassId(int classId) {
    for (final def in this) {
      if (def.classId == classId) return def;
    }
    return null;
  }

  /// 根据classId获取类型，未找到返回fallback
  LabelType typeForClassId(int classId, {LabelType fallback = LabelType.box}) {
    return findByClassId(classId)?.type ?? fallback;
  }

  /// 根据classId获取名称，未找到返回fallback或默认命名
  String nameForClassId(int classId, {String? fallback}) {
    return findByClassId(classId)?.name ?? (fallback ?? 'class_$classId');
  }

  /// 根据classId获取颜色，未找到使用默认调色板
  Color colorForClassId(int classId,
      {List<Color> palette = LabelPalettes.defaultPalette}) {
    final def = findByClassId(classId);
    if (def != null) return def.color;
    return palette[classId % palette.length];
  }

  /// 获取下一个可用的classId（当前最大值+1）
  int get nextClassId {
    if (isEmpty) return 0;
    int maxId = 0;
    for (final def in this) {
      if (def.classId > maxId) maxId = def.classId;
    }
    return maxId + 1;
  }
}
