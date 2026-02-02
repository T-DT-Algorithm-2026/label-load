import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 根据拖拽手柄位置调整矩形大小。
///
/// [handle] 与 [buildHandlePoints] 的索引一致：
/// 0/1/2/3 为四角，4/5/6/7 为上/右/下/左中点。
Rect resizeRectFromHandle({
  required Rect base,
  required Offset current,
  required int handle,
}) {
  final affectsLeft = handle == 0 || handle == 3 || handle == 7;
  final affectsRight = handle == 1 || handle == 2 || handle == 5;
  final affectsTop = handle == 0 || handle == 1 || handle == 4;
  final affectsBottom = handle == 2 || handle == 3 || handle == 6;

  double l = base.left;
  double r = base.right;
  double t = base.top;
  double b = base.bottom;

  if (affectsLeft || affectsRight) {
    final anchorX = affectsLeft ? base.right : base.left;
    l = math.min(current.dx, anchorX);
    r = math.max(current.dx, anchorX);
  }

  if (affectsTop || affectsBottom) {
    final anchorY = affectsTop ? base.bottom : base.top;
    t = math.min(current.dy, anchorY);
    b = math.max(current.dy, anchorY);
  }

  return Rect.fromLTRB(l, t, r, b);
}
