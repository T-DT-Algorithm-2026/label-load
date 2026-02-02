import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import 'handle_utils.dart';
import 'label_text_metrics.dart';

/// 标签绘制器
///
/// 负责在画布上渲染所有标签（边界框、多边形、关键点等）。
class LabelPainter extends CustomPainter {
  /// 当前所有标签数据。
  final List<Label> labels;

  /// 选中的标签索引。
  final int? selectedIndex;

  /// 选中标签的关键点索引。
  final int? activeKeypointIndex;

  /// 悬停中的标签索引。
  final int? hoveredIndex;

  /// 绘制中的临时矩形（拖拽创建）。
  final Rect? drawingRect;

  /// 当前选择的类别 ID（用于新建标签）。
  final int currentClassId;

  /// 类别定义列表（用于颜色/类型）。
  final List<LabelDefinition> definitions;

  /// 当前激活的调整手柄索引。
  final int? activeHandle;

  /// 是否处于标注模式。
  final bool isLabelingMode;

  /// 是否绘制十字准星。
  final bool showCrosshair;

  /// 鼠标位置（归一化坐标）。
  final Offset? mousePosition;

  /// 多边形创建中的点集合。
  final List<Offset> polygonPoints;

  // 编辑模式悬停状态
  /// 悬停手柄索引。
  final int? hoveredHandle;

  /// 悬停关键点索引。
  final int? hoveredKeypointIndex;

  /// 悬停关键点所属标签索引。
  final int? hoveredKeypointLabelIndex;

  /// 多边形顶点悬停索引。
  final int? hoveredVertexIndex;

  // 点大小和缩放
  /// 关键点渲染大小（像素）。
  final double pointSize;

  /// 当前画布缩放比例。
  final double currentScale;

  /// 命中检测半径（像素）。
  final double pointHitRadius;

  // 是否填充形状
  /// 是否填充标签形状。
  final bool fillShape;

  // 是否显示未标注点（visibility=0）
  /// 是否显示 visibility=0 的关键点。
  final bool showUnlabeledPoints;

  LabelPainter({
    required this.labels,
    this.selectedIndex,
    this.activeKeypointIndex,
    this.hoveredIndex,
    this.drawingRect,
    required this.currentClassId,
    required this.definitions,
    this.activeHandle,
    required this.isLabelingMode,
    this.showCrosshair = false,
    this.mousePosition,
    required this.polygonPoints,
    this.hoveredHandle,
    this.hoveredKeypointIndex,
    this.hoveredKeypointLabelIndex,
    this.hoveredVertexIndex,
    this.pointSize = 6.0,
    this.currentScale = 1.0,
    this.pointHitRadius = 60.0,
    this.fillShape = true,
    this.showUnlabeledPoints = true,
  });

  /// 获取类别颜色
  Color _getColor(int classId) {
    return definitions.colorForClassId(classId);
  }

  /// 获取缩放调整后的点大小
  double _getAdjustedPointSize([double multiplier = 1.0]) {
    return (pointSize * multiplier) / currentScale;
  }

  /// 获取缩放调整后的手柄大小
  double _getAdjustedHandleSize([double multiplier = 1.0]) {
    return (8.0 * multiplier) / currentScale;
  }

  /// 获取缩放调整后的线宽
  double _getAdjustedStrokeWidth([double baseWidth = 2.0]) {
    return baseWidth / currentScale;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制所有标签
    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];
      final isSelected = i == selectedIndex;
      final isHovered = i == hoveredIndex;
      _drawLabel(canvas, size, label, i, isSelected, isHovered);
    }

    // 绘制当前正在绘制的矩形
    if (drawingRect != null) {
      _drawDrawingRect(canvas, size, drawingRect!);
    }

    // 绘制十字准星
    if (isLabelingMode && showCrosshair && mousePosition != null) {
      _drawCrosshair(canvas, size, mousePosition!);
    }

    // 绘制未完成的多边形
    if (polygonPoints.isNotEmpty) {
      _drawUnfinishedPolygon(canvas, size);
    }
  }

  /// 绘制十字准星
  void _drawCrosshair(Canvas canvas, Size size, Offset normalizedPos) {
    final pos =
        Offset(normalizedPos.dx * size.width, normalizedPos.dy * size.height);
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, pos.dy), Offset(size.width, pos.dy), paint);
    canvas.drawLine(Offset(pos.dx, 0), Offset(pos.dx, size.height), paint);
  }

  /// 绘制单个标签
  void _drawLabel(Canvas canvas, Size size, Label label, int labelIndex,
      bool isSelected, bool isHovered) {
    final color = _getColor(label.id);

    final type = definitions.typeForClassId(label.id);

    if (type == LabelType.polygon && label.points.isNotEmpty) {
      _drawPolygonLabel(canvas, size, label, color, isSelected, isHovered);
    } else {
      _drawBoxLabel(
          canvas, size, label, labelIndex, color, isSelected, isHovered);
    }
  }

  /// 绘制多边形标签
  void _drawPolygonLabel(Canvas canvas, Size size, Label label, Color color,
      bool isSelected, bool isHovered) {
    final path = Path();
    final p0 = label.points[0];
    path.moveTo(p0.x * size.width, p0.y * size.height);
    for (int i = 1; i < label.points.length; i++) {
      path.lineTo(
          label.points[i].x * size.width, label.points[i].y * size.height);
    }
    path.close();

    // 填充
    if (fillShape) {
      final fillPaint = Paint()
        ..color = color.withValues(
            alpha: isSelected
                ? 0.4
                : isHovered
                    ? 0.3
                    : 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    // 边框
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _getAdjustedStrokeWidth(isSelected
          ? 3.0
          : isHovered
              ? 2.5
              : 2.0);
    canvas.drawPath(path, borderPaint);

    // 选中或悬停时绘制顶点
    if (isSelected || isHovered) {
      final activePointIndex = isSelected ? activeKeypointIndex : null;
      final hoverPointIndex = isSelected ? hoveredVertexIndex : null;
      _drawPolygonVertices(
          canvas, size, label, color, activePointIndex, hoverPointIndex);
    }

    // 选中时绘制标签文本
    if (isSelected) {
      final rect = Rect.fromLTWH(
        label.bbox[0] * size.width,
        label.bbox[1] * size.height,
        label.width * size.width,
        label.height * size.height,
      );
      _drawLabelText(canvas, rect, label, size);
    }
  }

  /// 绘制边界框标签
  void _drawBoxLabel(Canvas canvas, Size size, Label label, int labelIndex,
      Color color, bool isSelected, bool isHovered) {
    final rect = Rect.fromLTWH(
      label.bbox[0] * size.width,
      label.bbox[1] * size.height,
      label.width * size.width,
      label.height * size.height,
    );

    // 填充
    if (fillShape) {
      final fillPaint = Paint()
        ..color = color.withValues(
            alpha: isSelected
                ? 0.3
                : isHovered
                    ? 0.2
                    : 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);
    }

    // 边框
    final strokeWidth = _getAdjustedStrokeWidth(isSelected
        ? 3.0
        : isHovered
            ? 2.5
            : 2.0);
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRect(rect, borderPaint);

    // 选中时绘制角点手柄
    bool showHandles = false;
    if (isSelected) {
      showHandles = true;
      if (definitions.typeForClassId(label.id) == LabelType.polygon) {
        showHandles = false;
      }
    }

    if (showHandles) {
      _drawCornerHandles(
          canvas, rect, color, isSelected ? hoveredHandle : null);
    }

    // 绘制标签文本
    _drawLabelText(canvas, rect, label, size);

    // 绘制关键点
    if (label.points.isNotEmpty) {
      final activePointIndex = isSelected ? activeKeypointIndex : null;
      final hoverPointIndex = (labelIndex == hoveredKeypointLabelIndex)
          ? hoveredKeypointIndex
          : null;
      _drawKeypoints(
          canvas, size, label, color, activePointIndex, hoverPointIndex);
    }
  }

  /// 绘制角点手柄
  void _drawCornerHandles(
      Canvas canvas, Rect rect, Color color, int? hoverIndex) {
    final handleSize = _getAdjustedHandleSize();
    final hoverHandleSize = _getAdjustedHandleSize(1.25);

    final handles = buildHandlePoints(rect);

    for (int i = 0; i < handles.length; i++) {
      final center = handles[i];
      final isHovered = (i == hoverIndex);
      final size = isHovered ? hoverHandleSize : handleSize;

      final handlePaint = Paint()
        ..color = isHovered ? Colors.cyan.shade100 : Colors.white
        ..style = PaintingStyle.fill;
      final handleBorderPaint = Paint()
        ..color = isHovered ? Colors.cyan : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _getAdjustedStrokeWidth(isHovered ? 2.5 : 2.0);

      final handleRect = Rect.fromCenter(
        center: center,
        width: size,
        height: size,
      );

      // 悬停时绘制光晕
      if (isHovered) {
        final glowPaint = Paint()
          ..color = Colors.cyan.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, size, glowPaint);
      }

      canvas.drawRect(handleRect, handlePaint);
      canvas.drawRect(handleRect, handleBorderPaint);
    }
  }

  /// 绘制标签文本
  void _drawLabelText(Canvas canvas, Rect rect, Label label, Size size) {
    final className = definitions.nameForClassId(label.id);
    const maxWidth = 200.0;
    final textRect = LabelTextMetrics.buildTextRect(
      labelRect: rect,
      text: className,
      maxWidth: maxWidth,
    );
    final isHovered = LabelTextMetrics.isHovered(
      textRect: textRect,
      mousePosition: mousePosition,
      canvasSize: size,
    );
    final paragraph = LabelTextMetrics.buildParagraph(
      text: className,
      color: Colors.white,
      isHovered: isHovered,
      maxWidth: maxWidth,
    );

    // 背景颜色
    final color = _getColor(label.id);
    final bgPaint = Paint()
      ..color = isHovered ? color.withValues(alpha: 0.2) : color;

    canvas.drawRRect(
      RRect.fromRectAndRadius(textRect, const Radius.circular(3)),
      bgPaint,
    );

    canvas.drawParagraph(paragraph, LabelTextMetrics.textOffset(rect));
  }

  /// 绘制关键点
  void _drawKeypoints(Canvas canvas, Size size, Label label, Color color,
      int? activeIndex, int? hoverIndex) {
    for (int i = 0; i < label.points.length; i++) {
      final point = label.points[i];

      // 跳过未标注点（visibility=0），除非设置为显示
      if (point.visibility == 0 && !showUnlabeledPoints) {
        continue;
      }

      final offset = Offset(point.x * size.width, point.y * size.height);
      final isActive = (i == activeIndex);
      final isHovered = (i == hoverIndex) && !isActive;

      // 根据 visibility 调整透明度
      final opacity =
          point.visibility == 0 ? 0.3 : (point.visibility == 1 ? 0.6 : 1.0);

      // 悬停光晕
      if (isHovered) {
        final glowPaint = Paint()
          ..color = Colors.cyan.withValues(alpha: 0.4 * opacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offset, _getAdjustedPointSize(1.5), glowPaint);
      }

      // 外圈
      final outerRadius = _getAdjustedPointSize(isActive
          ? 1.2
          : isHovered
              ? 1.1
              : 1.0);
      final baseColor = isActive
          ? Colors.yellow
          : isHovered
              ? Colors.cyan
              : color;
      final outerPaint = Paint()
        ..color = baseColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offset, outerRadius, outerPaint);

      // 内圈
      final innerRadius = outerRadius * 0.5;
      final innerPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offset, innerRadius, innerPaint);

      // 序号
      _drawPointIndex(canvas, offset, i + 1);
    }
  }

  /// 绘制点序号
  void _drawPointIndex(Canvas canvas, Offset offset, int index) {
    final fontSize = 10.0 / currentScale;
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        shadows: [
          Shadow(
              color: Colors.black87,
              blurRadius: 2 / currentScale,
              offset: Offset(0.5 / currentScale, 0.5 / currentScale)),
        ],
      ))
      ..addText('$index');
    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 30));

    final offsetX = 5.0 / currentScale;
    final offsetY = 12.0 / currentScale;
    canvas.drawParagraph(
        paragraph, Offset(offset.dx + offsetX, offset.dy - offsetY));
  }

  /// 绘制多边形顶点
  void _drawPolygonVertices(Canvas canvas, Size size, Label label, Color color,
      int? activeIndex, int? hoverIndex) {
    for (int i = 0; i < label.points.length; i++) {
      final point = label.points[i];
      final offset = Offset(point.x * size.width, point.y * size.height);
      final isActive = (i == activeIndex);
      final isHovered = (i == hoverIndex) && !isActive;

      // 悬停光晕
      if (isHovered) {
        final glowPaint = Paint()
          ..color = Colors.cyan.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offset, _getAdjustedPointSize(1.8), glowPaint);
      }

      // 菱形顶点
      final vertexSize = _getAdjustedPointSize(isActive
          ? 1.3
          : isHovered
              ? 1.15
              : 1.0);

      final path = Path()
        ..moveTo(offset.dx, offset.dy - vertexSize)
        ..lineTo(offset.dx + vertexSize, offset.dy)
        ..lineTo(offset.dx, offset.dy + vertexSize)
        ..lineTo(offset.dx - vertexSize, offset.dy)
        ..close();

      final fillPaint = Paint()
        ..color = isActive
            ? Colors.yellow
            : isHovered
                ? Colors.cyan
                : color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = _getAdjustedStrokeWidth(1.5);
      canvas.drawPath(path, borderPaint);

      // 序号
      _drawPointIndex(canvas, offset, i + 1);
    }
  }

  /// 绘制正在绘制的矩形
  void _drawDrawingRect(Canvas canvas, Size size, Rect normalizedRect) {
    final rect = Rect.fromLTWH(
      normalizedRect.left * size.width,
      normalizedRect.top * size.height,
      normalizedRect.width * size.width,
      normalizedRect.height * size.height,
    );

    final color = _getColor(currentClassId);

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _getAdjustedStrokeWidth(2.0);
    canvas.drawRect(rect, borderPaint);
  }

  /// 绘制未完成的多边形
  void _drawUnfinishedPolygon(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _getColor(currentClassId)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _getAdjustedStrokeWidth(2.0);

    final points = polygonPoints
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    // 绘制线段
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // 绘制到鼠标的橡皮筋线
    if (points.isNotEmpty && mousePosition != null) {
      final mousePixel = Offset(
          mousePosition!.dx * size.width, mousePosition!.dy * size.height);
      canvas.drawLine(points.last, mousePixel,
          paint..color = paint.color.withValues(alpha: 0.5));
    }

    // 检查是否接近起点
    bool isNearStart = false;
    if (points.length > 2 &&
        mousePosition != null &&
        polygonPoints.isNotEmpty) {
      final startNormalized = polygonPoints.first;
      final startPx = Offset(
          startNormalized.dx * size.width, startNormalized.dy * size.height);
      final mousePx = Offset(
          mousePosition!.dx * size.width, mousePosition!.dy * size.height);
      final distScreen = (mousePx - startPx).distance * currentScale;
      isNearStart = distScreen < pointHitRadius;
    }

    // 绘制顶点
    final vertexPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    final vertexRadius = _getAdjustedPointSize(0.7);
    final highlightRadius = _getAdjustedPointSize(1.5);
    for (int i = 0; i < points.length; i++) {
      if (i == 0 && isNearStart) {
        final startPaint = Paint()
          ..color = Colors.greenAccent
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points[i], highlightRadius, startPaint);

        final ringPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = _getAdjustedStrokeWidth(2.0);
        canvas.drawCircle(points[i], highlightRadius, ringPaint);
      } else {
        canvas.drawCircle(points[i], vertexRadius, vertexPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LabelPainter oldDelegate) {
    return labels != oldDelegate.labels ||
        selectedIndex != oldDelegate.selectedIndex ||
        hoveredIndex != oldDelegate.hoveredIndex ||
        drawingRect != oldDelegate.drawingRect ||
        currentClassId != oldDelegate.currentClassId ||
        activeHandle != oldDelegate.activeHandle ||
        polygonPoints != oldDelegate.polygonPoints ||
        mousePosition != oldDelegate.mousePosition ||
        pointSize != oldDelegate.pointSize ||
        currentScale != oldDelegate.currentScale ||
        pointHitRadius != oldDelegate.pointHitRadius;
  }
}
