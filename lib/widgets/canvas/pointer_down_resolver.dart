/// 指针按下后的动作类型。
enum PointerDownAction {
  /// 不触发任何交互。
  none,

  /// 进入创建拖拽（绘制新标签）。
  startCreateDrag,
}

/// 基于状态判定按下时的交互行为。
PointerDownAction resolvePointerDownAction({
  required bool isLabelingMode,
  required bool inImage,
  required bool createActive,
  required bool allowCreate,
}) {
  if (!createActive) return PointerDownAction.none;
  if (!allowCreate) return PointerDownAction.none;
  if (isLabelingMode && !inImage) return PointerDownAction.none;
  return PointerDownAction.startCreateDrag;
}
