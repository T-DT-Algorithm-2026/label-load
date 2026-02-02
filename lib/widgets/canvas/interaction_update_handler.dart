import 'package:flutter/material.dart';
import '../../providers/canvas_provider.dart';

/// 拖拽/交互更新分发器。
///
/// 根据 [CanvasProvider.interactionMode] 分发到具体处理函数。
class InteractionUpdateHandler {
  const InteractionUpdateHandler({
    required this.canvasProvider,
    required this.normalized,
    required this.applyPan,
    required this.handleResize,
    required this.handleMove,
    required this.handleMoveKeypoint,
    required this.handlePolygonHover,
    required this.updateDrawing,
  });

  final CanvasProvider canvasProvider;
  final Offset normalized;
  final void Function(double dx, double dy) applyPan;
  final void Function() handleResize;
  final void Function() handleMove;
  final void Function() handleMoveKeypoint;
  final void Function() handlePolygonHover;
  final void Function() updateDrawing;

  /// 执行一次交互更新。
  void run(Offset delta) {
    switch (canvasProvider.interactionMode) {
      case InteractionMode.panning:
        applyPan(delta.dx, delta.dy);
        return;
      case InteractionMode.resizing:
        handleResize();
        return;
      case InteractionMode.moving:
        handleMove();
        return;
      case InteractionMode.drawing:
        updateDrawing();
        return;
      case InteractionMode.movingKeypoint:
        handleMoveKeypoint();
        return;
      case InteractionMode.none:
        if (canvasProvider.isCreatingPolygon) {
          handlePolygonHover();
        }
        return;
    }
  }
}
