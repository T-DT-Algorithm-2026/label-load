/// 应用全局配置
///
/// 存储应用运行时的基本配置信息，包括路径、类名列表和语言设置。
/// 注意：AI推理相关配置已移至 [AiConfig]，项目相关配置存储在 [ProjectConfig]。
class AppConfig {
  /// 图片目录路径
  String imagePath;

  /// 标签目录路径
  String labelPath;

  /// 类名列表，与标签ID对应
  List<String> classNames;

  /// 界面语言代码（'zh' 或 'en'）
  String locale;

  AppConfig({
    this.imagePath = '',
    this.labelPath = '',
    List<String>? classNames,
    this.locale = 'zh',
  }) : classNames = classNames ?? [];

  /// 从JSON创建配置
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      imagePath: json['imagePath'] ?? '',
      labelPath: json['labelPath'] ?? '',
      classNames: (json['classNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      locale: json['locale'] ?? 'zh',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'imagePath': imagePath,
      'labelPath': labelPath,
      'classNames': classNames,
      'locale': locale,
    };
  }

  /// 创建副本并可选地修改部分字段
  ///
  /// 为避免外部修改影响原配置，`classNames` 会进行浅拷贝。
  AppConfig copyWith({
    String? imagePath,
    String? labelPath,
    List<String>? classNames,
    String? locale,
  }) {
    return AppConfig(
      imagePath: imagePath ?? this.imagePath,
      labelPath: labelPath ?? this.labelPath,
      classNames: classNames ?? List.from(this.classNames),
      locale: locale ?? this.locale,
    );
  }
}
