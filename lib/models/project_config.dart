import 'package:uuid/uuid.dart';
import 'label_definition.dart';
import 'ai_config.dart';

/// 项目配置
///
/// 存储项目的持久化配置信息，包括名称、路径、标签定义和AI设置。
/// 项目配置保存在应用目录的 projects.json 文件中。
class ProjectConfig {
  /// 项目唯一标识符（UUID）
  final String id;

  /// 项目名称
  String name;

  /// 项目描述
  String description;

  /// 图片目录路径
  String imagePath;

  /// 标签目录路径
  String labelPath;

  /// 标签定义列表
  List<LabelDefinition> labelDefinitions;

  /// 创建时间
  final DateTime createdAt;

  /// AI自动标注配置
  AiConfig aiConfig;

  /// 上次查看的图片索引
  int lastViewedIndex;

  /// 已执行过AI推理的图片列表（存储相对路径或文件名）
  List<String> inferredImages;

  ProjectConfig({
    String? id,
    required this.name,
    this.description = '',
    this.imagePath = '',
    this.labelPath = '',
    List<LabelDefinition>? labelDefinitions,
    DateTime? createdAt,
    AiConfig? aiConfig,
    this.lastViewedIndex = 0,
    List<String>? inferredImages,
  })  : id = id ?? const Uuid().v4(),
        labelDefinitions = labelDefinitions ?? [],
        createdAt = createdAt ?? DateTime.now(),
        aiConfig = aiConfig ?? AiConfig(),
        inferredImages = inferredImages ?? [];

  /// 从JSON创建配置
  ///
  /// 支持旧格式（基于索引的 classId），并在字段缺失时回退默认值。
  factory ProjectConfig.fromJson(Map<String, dynamic> json) {
    final rawDefinitions = json['labelDefinitions'] as List<dynamic>? ?? [];

    // 解析标签定义，支持旧格式（基于索引的classId）
    final labelDefinitions = <LabelDefinition>[];
    for (int i = 0; i < rawDefinitions.length; i++) {
      labelDefinitions.add(LabelDefinition.fromJson(
        rawDefinitions[i] as Map<String, dynamic>,
        fallbackClassId: i,
      ));
    }

    return ProjectConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      labelPath: json['labelPath'] as String? ?? '',
      labelDefinitions: labelDefinitions,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      aiConfig: json['aiConfig'] != null
          ? AiConfig.fromJson(json['aiConfig'] as Map<String, dynamic>)
          : AiConfig(),
      lastViewedIndex: json['lastViewedIndex'] as int? ?? 0,
      inferredImages: (json['inferredImages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imagePath': imagePath,
      'labelPath': labelPath,
      'labelDefinitions': labelDefinitions.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'aiConfig': aiConfig.toJson(),
      'lastViewedIndex': lastViewedIndex,
      'inferredImages': inferredImages,
    };
  }

  /// 创建副本并可选地修改部分字段
  ///
  /// 列表字段会进行浅拷贝，`aiConfig` 会通过 `copyWith` 复制。
  ProjectConfig copyWith({
    String? name,
    String? description,
    String? imagePath,
    String? labelPath,
    List<LabelDefinition>? labelDefinitions,
    AiConfig? aiConfig,
    int? lastViewedIndex,
    List<String>? inferredImages,
  }) {
    return ProjectConfig(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      labelPath: labelPath ?? this.labelPath,
      labelDefinitions: labelDefinitions ?? List.from(this.labelDefinitions),
      createdAt: createdAt,
      aiConfig: aiConfig ?? this.aiConfig.copyWith(),
      lastViewedIndex: lastViewedIndex ?? this.lastViewedIndex,
      inferredImages: inferredImages ?? List.from(this.inferredImages),
    );
  }
}
