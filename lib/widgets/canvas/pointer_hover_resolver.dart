/// 悬停处理动作。
enum HoverAction {
  /// 不处理。
  none,

  /// 更新悬停状态。
  update,

  /// 清理悬停状态。
  clear,
}

/// 根据状态解析悬停行为（标注模式下离开图像会清理）。
HoverAction resolveHoverAction({
  required bool isLabelingMode,
  required bool inImage,
}) {
  if (isLabelingMode && !inImage) {
    return HoverAction.clear;
  }
  return HoverAction.update;
}
