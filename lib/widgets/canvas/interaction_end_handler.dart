import 'package:flutter/material.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/project_provider.dart';

/// 交互结束处理器。
///
/// 负责结束绘制/编辑交互，并同步更新标签数据。
class InteractionEndHandler {
  const InteractionEndHandler({
    required this.canvasProvider,
    required this.projectProvider,
    required this.onFinish,
  });

  final CanvasProvider canvasProvider;
  final ProjectProvider projectProvider;
  final VoidCallback onFinish;

  /// 结束交互并触发数据更新。
  void run() {
    final mode = canvasProvider.interactionMode;
    final rect = canvasProvider.endInteraction();

    // 若有有效矩形，创建新标签；否则在编辑类交互后通知刷新。
    if (rect != null) {
      final label = projectProvider.createLabelFromRect(
        canvasProvider.currentClassId,
        rect,
      );
      projectProvider.addLabel(label);
      canvasProvider.selectLabel(projectProvider.labels.length - 1);
    } else if (mode == InteractionMode.moving ||
        mode == InteractionMode.resizing ||
        mode == InteractionMode.movingKeypoint) {
      projectProvider.notifyLabelChange();
    }

    onFinish();
  }
}
