import 'label_definition.dart';
import '../services/app/app_error.dart';

/// 标签数据模型
///
/// 表示图像上的一个标注对象，支持边界框、关键点和多边形。
class Label {
  /// 类别ID
  int id;

  /// 类别名称
  String name;

  /// 中心点X坐标（归一化，0-1）
  double x;

  /// 中心点Y坐标（归一化，0-1）
  double y;

  /// 宽度（归一化，0-1）
  double width;

  /// 高度（归一化，0-1）
  double height;

  /// 关键点或多边形顶点列表
  List<LabelPoint> points;

  /// 额外未解析的数据（即使截断也不丢失）
  List<String> extraData;

  /// AI检测置信度（可选）
  double? confidence;

  Label({
    required this.id,
    this.name = '',
    this.x = 0.5,
    this.y = 0.5,
    this.width = 0.1,
    this.height = 0.1,
    List<LabelPoint>? points,
    List<String>? extraData,
    this.confidence,
  })  : points = points ?? [],
        extraData = extraData ?? [];

  /// 从YOLO格式行创建标签
  ///
  /// [type] 根据标签定义指定的类型进行解析
  /// - Box: 解析前5列，后续存入 extraData
  /// - BoxWithPoint: 解析关键点，不能整除的尾部存入 extraData
  /// - Polygon: 解析多边形点，不能整除的尾部存入 extraData
  ///
  /// 解析失败时会抛出 [AppError]，错误码可能为：
  /// - [AppErrorCode.labelLineEmpty]
  /// - [AppErrorCode.labelInvalidClassId]
  /// - [AppErrorCode.labelInvalidBox]
  /// - [AppErrorCode.labelInvalidPolygon]
  factory Label.fromYoloLine(String line, String Function(int) getName,
      {LabelType type = LabelType.box}) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      throw const AppError(AppErrorCode.labelLineEmpty);
    }

    final parts = trimmed.split(RegExp(r'\s+'));

    final classId = int.tryParse(parts[0]);
    if (classId == null) {
      throw AppError(AppErrorCode.labelInvalidClassId, details: parts[0]);
    }

    final label = Label(
      id: classId,
      name: getName(classId),
      x: 0, y: 0, width: 0, height: 0, // 初始默认值
    );

    if (type == LabelType.polygon) {
      // 多边形格式: class_id x1 y1 x2 y2 x3 y3 ...
      // 至少需要3个点 (1 + 2*3 = 7列)
      if (parts.length < 7) {
        throw AppError(AppErrorCode.labelInvalidPolygon, details: line);
      }

      // 解析多边形顶点（从索引1开始的xy对）
      int i = 1;
      while (i + 1 < parts.length) {
        try {
          final px = double.parse(parts[i]);
          final py = double.parse(parts[i + 1]);
          label.points.add(LabelPoint(x: px, y: py));
          i += 2;
        } catch (e) {
          // 解析失败，停止并将剩余部分存入 extraData
          break;
        }
      }

      // 剩余未解析部分存入 extraData
      if (i < parts.length) {
        label.extraData.addAll(parts.sublist(i));
      }

      label.updateBboxFromPoints();
    } else {
      // Box 或 BoxWithPoint 格式: class_id cx cy w h ...
      if (parts.length < 5) {
        throw AppError(AppErrorCode.labelInvalidBox, details: line);
      }

      label.x = double.parse(parts[1]);
      label.y = double.parse(parts[2]);
      label.width = double.parse(parts[3]);
      label.height = double.parse(parts[4]);

      int i = 5;

      if (type == LabelType.boxWithPoint) {
        // 解析关键点 (x, y, visibility 三元组)
        while (i + 2 < parts.length) {
          try {
            final kx = double.parse(parts[i]);
            final ky = double.parse(parts[i + 1]);
            final kv = double.parse(parts[i + 2]);
            label.points.add(LabelPoint(
                x: kx, y: ky, visibility: kv.round().clamp(0, 2).toInt()));
            i += 3;
          } catch (e) {
            break;
          }
        }
      }

      // Box类型直接跳过关键点解析，或者 BWP类型剩下的残缺数据
      // 统一存入 extraData
      if (i < parts.length) {
        label.extraData.addAll(parts.sublist(i));
      }
    }

    return label;
  }

  /// 转换为YOLO格式字符串
  String toYoloLine({bool isPolygon = false}) {
    // 注意：这里的 isPolygon 参数主要为了兼容旧API调用习惯，
    // 但理想情况下应根据 Label 自身的数据特征或传入的 Definition 决定。
    // 现逻辑：如果有 points 且指定 isPolygon，则按多边形输出；否则按检测框输出。

    final buffer = StringBuffer();
    buffer.write(id);

    if (isPolygon && points.isNotEmpty) {
      for (final p in points) {
        buffer.write(' ${p.x.toStringAsFixed(6)} ${p.y.toStringAsFixed(6)}');
      }
    } else {
      buffer.write(' ${x.toStringAsFixed(6)} ${y.toStringAsFixed(6)} '
          '${width.toStringAsFixed(6)} ${height.toStringAsFixed(6)}');

      for (final p in points) {
        buffer.write(
            ' ${p.x.toStringAsFixed(6)} ${p.y.toStringAsFixed(6)} ${p.visibility}');
      }
    }

    // 追加保存的额外数据
    if (extraData.isNotEmpty) {
      buffer.write(' ${extraData.join(' ')}');
    }

    return buffer.toString();
  }

  /// 将标签以“完整点信息”格式输出（始终包含bbox和关键点/可见性）
  ///
  /// 用于在类型变更时最大化保留原始点数据。
  String toYoloLineFull() {
    final buffer = StringBuffer();
    buffer.write(id);
    buffer.write(' ${x.toStringAsFixed(6)} ${y.toStringAsFixed(6)} '
        '${width.toStringAsFixed(6)} ${height.toStringAsFixed(6)}');

    if (points.isNotEmpty) {
      for (final p in points) {
        buffer.write(
            ' ${p.x.toStringAsFixed(6)} ${p.y.toStringAsFixed(6)} ${p.visibility}');
      }
    }

    if (extraData.isNotEmpty) {
      buffer.write(' ${extraData.join(' ')}');
    }

    return buffer.toString();
  }

  /// 获取边界框 [left, top, right, bottom]（归一化坐标）
  List<double> get bbox => [
        x - width / 2,
        y - height / 2,
        x + width / 2,
        y + height / 2,
      ];

  /// 从两个角点设置边界框
  ///
  /// [x1]/[y1]/[x2]/[y2] 可为任意顺序，内部会自动取绝对宽高。
  void setFromCorners(double x1, double y1, double x2, double y2) {
    x = (x1 + x2) / 2;
    y = (y1 + y2) / 2;
    width = (x2 - x1).abs();
    height = (y2 - y1).abs();
  }

  /// 创建副本并可选地修改部分字段
  Label copyWith({
    int? id,
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    List<LabelPoint>? points,
    List<String>? extraData,
    double? confidence,
  }) {
    return Label(
      id: id ?? this.id,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      points: points ?? this.points.map((p) => p.copyWith()).toList(),
      extraData: extraData ?? List.from(this.extraData),
      confidence: confidence ?? this.confidence,
    );
  }

  /// 根据关键点更新边界框（使其包围所有点）
  ///
  /// 如果没有关键点则不做修改。
  void updateBboxFromPoints() {
    if (points.isEmpty) return;

    double minX = points[0].x;
    double minY = points[0].y;
    double maxX = points[0].x;
    double maxY = points[0].y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    setFromCorners(minX, minY, maxX, maxY);
  }

  /// 是否包含关键点
  bool get hasKeypoints => points.isNotEmpty;
}

/// 标签关键点
///
/// 表示标签中的一个关键点或多边形顶点。
class LabelPoint {
  /// X坐标（归一化，0-1）
  double x;

  /// Y坐标（归一化，0-1）
  double y;

  /// 可见性：0=未标注，1=被遮挡，2=可见
  int visibility;

  LabelPoint({
    required this.x,
    required this.y,
    this.visibility = 2,
  });

  /// 创建副本并可选地修改部分字段
  LabelPoint copyWith({
    double? x,
    double? y,
    int? visibility,
  }) {
    return LabelPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      visibility: visibility ?? this.visibility,
    );
  }
}
