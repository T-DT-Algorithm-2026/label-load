import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../providers/keybindings_provider.dart';
import 'pointer_drag_tracker.dart';

/// 键盘驱动的指针动作状态。
///
/// 用于在键盘按下/释放时模拟鼠标创建、删除与拖拽流程。
class KeyboardPointerActionState {
  /// 当前激活的动作。
  BindableAction? action;

  /// 两次点击创建时记录的起点。
  Offset? createAnchor;

  /// 是否处于创建待定状态。
  bool createPending = false;

  /// 启动指定动作，并同步指针追踪状态。
  void startAction(
    BindableAction action,
    Offset? position,
    PointerDragTracker tracker,
  ) {
    if (this.action == action) return;
    this.action = action;

    if (action != BindableAction.mouseCreate) {
      createPending = false;
      createAnchor = null;
    }

    if (position != null) {
      tracker.setDownPosition(position);
    }
    tracker.lastButtons = 0;

    if (action == BindableAction.mouseCreate) {
      createAnchor = position;
      createPending = true;
    }
  }

  /// 结束动作并触发对应回调。
  void finishAction({
    required BindableAction action,
    required PointerDragTracker tracker,
    required bool isInteractionActive,
    required Offset Function(Offset global) toLocal,
    required void Function(TapUpDetails details) onCreateClick,
    required void Function(TapUpDetails details) onDeleteClick,
    required VoidCallback onPanEnd,
  }) {
    final position = tracker.lastGlobalPosition;
    final wasClick = tracker.wasClick;

    if (action == BindableAction.mouseCreate) {
      createPending = false;
      createAnchor = null;
    }

    if (position != null) {
      final details = TapUpDetails(
        kind: PointerDeviceKind.mouse,
        localPosition: toLocal(position),
        globalPosition: position,
      );
      if (action == BindableAction.mouseCreate) {
        if (!wasClick || isInteractionActive) {
          onPanEnd();
        } else {
          onCreateClick(details);
        }
      } else if (action == BindableAction.mouseDelete) {
        onDeleteClick(details);
      }
    }

    this.action = null;
    tracker.reset();
  }
}
