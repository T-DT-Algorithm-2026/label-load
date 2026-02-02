/// AI推理模型类型枚举
enum ModelType {
  /// YOLOv8 目标检测
  yolo,

  /// YOLOv8-Pose 姿态估计（关键点检测）
  yoloPose,
}

/// 标签保存模式枚举
enum LabelSaveMode {
  /// 追加模式：将AI结果添加到现有标签
  append,

  /// 覆盖模式：用AI结果替换现有标签
  overwrite,
}

/// AI自动标注配置
///
/// 存储ONNX模型路径、推理参数和自动标注行为设置。
/// 所有阈值字段均为归一化范围（0.0-1.0）。
class AiConfig {
  /// 模型类型
  ModelType modelType;

  /// ONNX模型文件路径
  String modelPath;

  /// 置信度阈值（0.0-1.0）
  double confidenceThreshold;

  /// 非极大值抑制(NMS)阈值（0.0-1.0）
  double nmsThreshold;

  /// 切换图片时是否自动执行推理
  bool autoInferOnNext;

  /// 标签保存模式
  LabelSaveMode labelSaveMode;

  /// 关键点数量（仅Pose模型使用，如COCO格式为17）
  int numKeypoints;

  /// 关键点置信度阈值（0.0-1.0，仅Pose模型使用）
  double keypointConfThreshold;

  /// 类别ID偏置（仅在追加模式下生效，用于合并多模型的ID）
  int classIdOffset;

  AiConfig({
    this.modelType = ModelType.yolo,
    this.modelPath = '',
    this.confidenceThreshold = 0.25,
    this.nmsThreshold = 0.45,
    this.autoInferOnNext = false,
    this.labelSaveMode = LabelSaveMode.append,
    this.numKeypoints = 0,
    this.keypointConfThreshold = 0.5,
    this.classIdOffset = 0,
  });

  /// 从JSON创建配置（缺失或空字段使用默认值）
  factory AiConfig.fromJson(Map<String, dynamic> json) {
    return AiConfig(
      modelType: ModelType.values[json['modelType'] as int? ?? 0],
      modelPath: json['modelPath'] as String? ?? '',
      confidenceThreshold:
          (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.25,
      nmsThreshold: (json['nmsThreshold'] as num?)?.toDouble() ?? 0.45,
      autoInferOnNext: json['autoInferOnNext'] as bool? ?? false,
      labelSaveMode: LabelSaveMode.values[json['labelSaveMode'] as int? ?? 0],
      numKeypoints: json['numKeypoints'] as int? ?? 0,
      keypointConfThreshold:
          (json['keypointConfThreshold'] as num?)?.toDouble() ?? 0.5,
      classIdOffset: json['classIdOffset'] as int? ?? 0,
    );
  }

  /// 转换为JSON（用于持久化存储）
  Map<String, dynamic> toJson() {
    return {
      'modelType': modelType.index,
      'modelPath': modelPath,
      'confidenceThreshold': confidenceThreshold,
      'nmsThreshold': nmsThreshold,
      'autoInferOnNext': autoInferOnNext,
      'labelSaveMode': labelSaveMode.index,
      'numKeypoints': numKeypoints,
      'keypointConfThreshold': keypointConfThreshold,
      'classIdOffset': classIdOffset,
    };
  }

  /// 创建副本并可选地修改部分字段
  AiConfig copyWith({
    ModelType? modelType,
    String? modelPath,
    double? confidenceThreshold,
    double? nmsThreshold,
    bool? autoInferOnNext,
    LabelSaveMode? labelSaveMode,
    int? numKeypoints,
    double? keypointConfThreshold,
    int? classIdOffset,
  }) {
    return AiConfig(
      modelType: modelType ?? this.modelType,
      modelPath: modelPath ?? this.modelPath,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      nmsThreshold: nmsThreshold ?? this.nmsThreshold,
      autoInferOnNext: autoInferOnNext ?? this.autoInferOnNext,
      labelSaveMode: labelSaveMode ?? this.labelSaveMode,
      numKeypoints: numKeypoints ?? this.numKeypoints,
      keypointConfThreshold:
          keypointConfThreshold ?? this.keypointConfThreshold,
      classIdOffset: classIdOffset ?? this.classIdOffset,
    );
  }

  /// 是否已配置模型
  bool get hasModel => modelPath.isNotEmpty;

  /// 当前模型是否输出关键点
  bool get hasKeypoints => modelType == ModelType.yoloPose;
}
