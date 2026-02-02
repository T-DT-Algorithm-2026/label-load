import '../../models/label_definition.dart';

/// 指针抬起后的动作类型。
enum PointerUpAction {
  /// 无动作。
  none,

  /// 创建标签。
  create,

  /// 删除标签或关键点。
  delete,

  /// 两点模式下移动关键点。
  moveKeypoint,
}

/// 基于当前状态解析抬起事件的处理策略。
PointerUpAction resolvePointerUpAction({
  required bool wasClick,
  required bool isPolygonClose,
  required bool isLabelingMode,
  required bool inImage,
  required int lastButtons,
  required int? createButton,
  required int? deleteButton,
  required int? moveButton,
  required bool isTwoClickMode,
  required LabelType labelType,
}) {
  if (isLabelingMode && !inImage) return PointerUpAction.none;
  if (!wasClick && !isPolygonClose) return PointerUpAction.none;

  if (createButton != null && (lastButtons & createButton) != 0) {
    return PointerUpAction.create;
  }

  if (deleteButton != null && (lastButtons & deleteButton) != 0) {
    return PointerUpAction.delete;
  }

  if (moveButton != null && (lastButtons & moveButton) != 0) {
    if (isLabelingMode &&
        isTwoClickMode &&
        labelType == LabelType.boxWithPoint) {
      return PointerUpAction.moveKeypoint;
    }
  }

  return PointerUpAction.none;
}
