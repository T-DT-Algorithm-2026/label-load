import 'package:flutter/material.dart';

/// 根据边界框构建 8 个调整手柄点（角点 + 边中点）。
List<Offset> buildHandlePoints(Rect rect) {
  return [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
    rect.topCenter,
    rect.centerRight,
    rect.bottomCenter,
    rect.centerLeft,
  ];
}
