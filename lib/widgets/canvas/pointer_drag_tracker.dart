import 'package:flutter/material.dart';

/// 指针拖拽追踪状态。
class PointerDragTracker {
  /// 按下时的位置（用于点击/拖拽判定）。
  Offset? downPosition;

  /// 最近一次指针的全局位置。
  Offset? lastGlobalPosition;

  /// 最近一次记录的按键掩码。
  int lastButtons = 0;

  /// 是否已超过拖拽阈值。
  bool moved = false;

  /// 初始化一次指针交互追踪。
  void start(Offset position, int buttons) {
    lastButtons = buttons;
    lastGlobalPosition = position;
    downPosition = position;
    moved = false;
  }

  /// 更新当前指针位置，并基于 [threshold] 判断是否拖拽。
  void update(Offset position, {double threshold = 5.0}) {
    lastGlobalPosition = position;
    if (downPosition != null && !moved) {
      final dist = (position - downPosition!).distance;
      if (dist > threshold) moved = true;
    }
  }

  /// 手动设置按下位置（会重置拖拽状态）。
  void setDownPosition(Offset? position) {
    downPosition = position;
    moved = false;
  }

  /// 清理本次交互状态。
  void reset() {
    downPosition = null;
    moved = false;
  }

  /// 是否为点击（未移动且有按下点）。
  bool get wasClick => downPosition != null && !moved;
}
