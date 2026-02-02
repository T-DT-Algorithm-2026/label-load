import 'package:flutter/material.dart';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import 'canvas_geometry.dart';
import 'handle_utils.dart';
import 'canvas_helpers.dart';

/// 画布命中检测工具。
///
/// 负责在像素/归一化坐标中查找手柄、关键点、边缘和标签主体。
class CanvasHitTester {
  /// 查找命中边界框手柄。
  ///
  /// [localPos] 为像素坐标，[imageSize] 为原图尺寸，返回最近的手柄索引。
  static int? findHandleAt({
    required Offset localPos,
    required Label label,
    required Size imageSize,
    required double pointHitRadius,
    required double scale,
  }) {
    final r = pointHitRadius / scale;

    final rect = Rect.fromLTWH(
      label.bbox[0] * imageSize.width,
      label.bbox[1] * imageSize.height,
      label.width * imageSize.width,
      label.height * imageSize.height,
    );

    final handles = buildHandlePoints(rect);

    int? bestHandle;
    double minDesc = double.infinity;

    for (int index = 0; index < handles.length; index++) {
      final dist = (handles[index] - localPos).distance;
      if (dist < r && dist < minDesc) {
        minDesc = dist;
        bestHandle = index;
      }
    }

    return bestHandle;
  }

  /// 查找命中关键点。
  ///
  /// [normalized] 为归一化坐标（0~1），支持按 [showUnlabeledPoints] 控制
  /// visibility=0 的关键点是否可命中。
  static HitKeypoint? findKeypointAt({
    required Offset normalized,
    required List<Label> labels,
    required Size imageSize,
    required double pointHitRadius,
    required double scale,
    required bool showUnlabeledPoints,
  }) {
    final r = pointHitRadius / scale;

    HitKeypoint? bestMatch;
    double minDesc = double.infinity;

    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];
      for (int j = 0; j < label.points.length; j++) {
        final p = label.points[j];

        if (p.visibility == 0 && !showUnlabeledPoints) {
          continue;
        }

        final screenP = Offset(p.x * imageSize.width, p.y * imageSize.height);
        final localP = Offset(
            normalized.dx * imageSize.width, normalized.dy * imageSize.height);
        final dist = (screenP - localP).distance;

        if (dist < r && dist < minDesc) {
          minDesc = dist;
          bestMatch = HitKeypoint(i, j);
        }
      }
    }
    return bestMatch;
  }

  /// 查找多边形边缘命中索引。
  ///
  /// 返回边起点索引（即点 i 到点 i+1 的边），或 null。
  static int? findEdgeAt({
    required Offset localPos,
    required Label label,
    required Size imageSize,
    required double pointHitRadius,
    required double scale,
  }) {
    if (label.points.length < 2) return null;

    final threshold = pointHitRadius / scale;

    int? bestEdge;
    double minDesc = double.infinity;

    for (int i = 0; i < label.points.length; i++) {
      final p1 = label.points[i];
      final p2 = label.points[(i + 1) % label.points.length];

      final s1 = Offset(p1.x * imageSize.width, p1.y * imageSize.height);
      final s2 = Offset(p2.x * imageSize.width, p2.y * imageSize.height);

      final dist = distanceToSegmentPixels(localPos, s1, s2);

      if (dist < threshold && dist < minDesc) {
        minDesc = dist;
        bestEdge = i;
      }
    }
    return bestEdge;
  }

  /// 查找命中标签主体的索引。
  ///
  /// 多个标签重叠时返回距离边缘最近者。
  static int? findLabelAt({
    required Offset normalized,
    required List<Label> labels,
    required List<LabelDefinition> definitions,
  }) {
    final candidates = <int, double>{};

    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];

      LabelType type = LabelType.box;
      if (label.id < definitions.length) {
        type = definitions[label.id].type;
      }

      bool isInside = false;
      double distToEdge = double.infinity;

      if (type == LabelType.polygon && label.points.isNotEmpty) {
        if (isPointInPolygon(normalized, label.points)) {
          isInside = true;
          distToEdge = polygonEdgeDistance(normalized, label.points);
        }
      } else {
        final bbox = label.bbox;
        if (normalized.dx >= bbox[0] &&
            normalized.dx <= bbox[2] &&
            normalized.dy >= bbox[1] &&
            normalized.dy <= bbox[3]) {
          isInside = true;
          final distL = (normalized.dx - bbox[0]).abs();
          final distR = (bbox[2] - normalized.dx).abs();
          final distT = (normalized.dy - bbox[1]).abs();
          final distB = (bbox[3] - normalized.dy).abs();
          distToEdge =
              [distL, distR, distT, distB].reduce((a, b) => a < b ? a : b);
        }
      }

      if (isInside) {
        candidates[i] = distToEdge;
      }
    }

    if (candidates.isEmpty) return null;

    var bestIndex = -1;
    var minDist = double.infinity;

    candidates.forEach((index, dist) {
      if (dist < minDist) {
        minDist = dist;
        bestIndex = index;
      }
    });

    return bestIndex;
  }
}
