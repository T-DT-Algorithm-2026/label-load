import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 图片绘制器
///
/// 简单地将图片绘制到画布上，支持颜色滤镜。
class ImagePainter extends CustomPainter {
  final ui.Image image;
  final ColorFilter? colorFilter;
  final ui.FilterQuality filterQuality;

  ImagePainter({
    required this.image,
    this.colorFilter,
    this.filterQuality = ui.FilterQuality.none,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }
    paint.filterQuality = filterQuality;
    canvas.drawImage(image, Offset.zero, paint);
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return image != oldDelegate.image ||
        colorFilter != oldDelegate.colorFilter ||
        filterQuality != oldDelegate.filterQuality;
  }
}

/// 屏幕空间十字准星绘制器
///
/// 使用绝对屏幕坐标绘制十字线，用于平滑跟踪。
class ScreenCrosshairPainter extends CustomPainter {
  final Offset position;

  ScreenCrosshairPainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
        Offset(0, position.dy), Offset(size.width, position.dy), paint);
    canvas.drawLine(
        Offset(position.dx, 0), Offset(position.dx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant ScreenCrosshairPainter oldDelegate) {
    return position != oldDelegate.position;
  }
}

/// 关键点命中结果
///
/// 存储命中检测时找到的关键点信息。
class HitKeypoint {
  final int labelIndex;
  final int pointIndex;

  HitKeypoint(this.labelIndex, this.pointIndex);
}
