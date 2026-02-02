import '../../providers/canvas_provider.dart';
import 'canvas_hover_handler.dart';

/// 在编辑模式下，根据悬停结果更新选中/激活状态。
void applyEditModeSelection({
  required CanvasProvider canvasProvider,
  required CanvasHoverResult hoverResult,
}) {
  final selectedIndex = canvasProvider.selectedLabelIndex;

  // 优先处理手柄命中，其次关键点，再次标签主体。
  if (hoverResult.hoveredHandle != null && selectedIndex != null) {
    canvasProvider.selectLabel(selectedIndex);
    canvasProvider.setActiveHandle(hoverResult.hoveredHandle);
    canvasProvider.setActiveKeypoint(null);
    return;
  }

  if (hoverResult.hoveredKeypointLabelIndex != null &&
      hoverResult.hoveredKeypointIndex != null) {
    canvasProvider.selectLabel(hoverResult.hoveredKeypointLabelIndex);
    canvasProvider.setActiveKeypoint(hoverResult.hoveredKeypointIndex);
    return;
  }

  if (hoverResult.hoveredLabelIndex != null) {
    canvasProvider.selectLabel(hoverResult.hoveredLabelIndex);
    canvasProvider.setActiveKeypoint(null);
    return;
  }

  // 无命中时清理选中状态。
  canvasProvider.clearSelection();
}
