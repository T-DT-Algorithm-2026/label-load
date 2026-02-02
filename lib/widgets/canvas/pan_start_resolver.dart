import '../../models/label_definition.dart';

/// 拖拽开始后的动作类型。
enum PanStartAction {
  /// 不处理。
  none,

  /// 进入绘制流程（标注）。
  draw,

  /// 进入编辑流程（移动/调整）。
  edit,
}

/// 根据当前模式解析拖拽开始的处理策略。
PanStartAction resolvePanStartAction({
  required bool isLabelingMode,
  required bool inImage,
  required bool createActive,
  required bool moveActive,
  required bool isTwoClickMode,
  required LabelType labelType,
}) {
  if (moveActive) return PanStartAction.none;
  if (!createActive) return PanStartAction.none;
  if (isLabelingMode && !inImage) return PanStartAction.none;

  if (isLabelingMode) {
    final supportsDrag =
        labelType == LabelType.box || labelType == LabelType.boxWithPoint;
    if (!supportsDrag) return PanStartAction.none;
    if (isTwoClickMode) return PanStartAction.none;
    return PanStartAction.draw;
  }

  return PanStartAction.edit;
}
