import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/label.dart';

/// 点到线段距离（图像归一化空间或任意笛卡尔坐标）。
double distanceToSegment(Offset p, Offset s1, Offset s2) {
  final x = p.dx;
  final y = p.dy;
  final x1 = s1.dx;
  final y1 = s1.dy;
  final x2 = s2.dx;
  final y2 = s2.dy;

  final dx = x2 - x1;
  final dy = y2 - y1;
  if (dx == 0 && dy == 0) {
    return (p - s1).distance;
  }

  final t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
  if (t < 0) {
    return (p - s1).distance;
  }
  if (t > 1) {
    return (p - s2).distance;
  }

  final projX = x1 + t * dx;
  final projY = y1 + t * dy;
  return (Offset(x, y) - Offset(projX, projY)).distance;
}

/// 获取点到多边形边缘的最短距离。
///
/// [points] 至少包含两个点，否则返回正无穷。
double polygonEdgeDistance(Offset p, List<LabelPoint> points) {
  if (points.length < 2) return double.infinity;
  var minDist = double.infinity;
  for (int i = 0; i < points.length; i++) {
    final p1 = points[i];
    final p2 = points[(i + 1) % points.length];
    final dist = distanceToSegment(p, Offset(p1.x, p1.y), Offset(p2.x, p2.y));
    if (dist < minDist) minDist = dist;
  }
  return minDist;
}

/// 判断点是否在多边形内（射线法）。
bool isPointInPolygon(Offset p, List<LabelPoint> polygon) {
  var isInside = false;
  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    if (((polygon[i].y > p.dy) != (polygon[j].y > p.dy)) &&
        (p.dx <
            (polygon[j].x - polygon[i].x) *
                    (p.dy - polygon[i].y) /
                    (polygon[j].y - polygon[i].y) +
                polygon[i].x)) {
      isInside = !isInside;
    }
  }
  return isInside;
}

/// 判断点是否在边界框内。
///
/// [bbox] 格式为 [left, top, right, bottom]。
bool isPointInBBox(Offset point, List<double> bbox) {
  return point.dx >= bbox[0] &&
      point.dx <= bbox[2] &&
      point.dy >= bbox[1] &&
      point.dy <= bbox[3];
}

/// 点到线段距离（屏幕像素空间辅助）。
double distanceToSegmentPixels(Offset p, Offset s1, Offset s2) {
  final A = p.dx - s1.dx;
  final B = p.dy - s1.dy;
  final C = s2.dx - s1.dx;
  final D = s2.dy - s1.dy;

  final dot = A * C + B * D;
  final lenSq = C * C + D * D;

  double param = -1;
  if (lenSq != 0) {
    param = dot / lenSq;
  }

  double xx;
  double yy;

  if (param < 0) {
    xx = s1.dx;
    yy = s1.dy;
  } else if (param > 1) {
    xx = s2.dx;
    yy = s2.dy;
  } else {
    xx = s1.dx + param * C;
    yy = s1.dy + param * D;
  }

  final dx = p.dx - xx;
  final dy = p.dy - yy;
  return math.sqrt(dx * dx + dy * dy);
}
