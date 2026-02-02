import 'package:flutter/material.dart';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import '../../providers/canvas_provider.dart';
import 'canvas_helpers.dart';
import 'handle_utils.dart';

/// 画布悬停命中结果。
///
/// 统一收集手柄、关键点、顶点和标签主体的命中信息。
class CanvasHoverResult {
  const CanvasHoverResult({
    required this.hoveredHandle,
    required this.hoveredKeypointIndex,
    required this.hoveredKeypointLabelIndex,
    required this.hoveredVertexIndex,
    required this.hoveredLabelIndex,
  });

  final int? hoveredHandle;
  final int? hoveredKeypointIndex;
  final int? hoveredKeypointLabelIndex;
  final int? hoveredVertexIndex;
  final int? hoveredLabelIndex;

  /// 是否命中可交互实体（手柄/关键点/顶点）。
  bool get hasActiveHit =>
      hoveredHandle != null ||
      hoveredKeypointIndex != null ||
      hoveredVertexIndex != null;
}

/// 悬停解析器。
///
/// 负责在当前坐标下判定优先命中项，并生成完整悬停结果。
class CanvasHoverResolver {
  const CanvasHoverResolver({
    required this.labels,
    required this.imageSize,
    required this.selectedLabelIndex,
    required this.getLabelDefinition,
    required this.findKeypointAt,
    required this.findHandleAt,
    required this.findLabelAt,
  });

  final List<Label> labels;
  final Size imageSize;
  final int? selectedLabelIndex;
  final LabelDefinition? Function(int classId) getLabelDefinition;
  final HitKeypoint? Function(Offset normalized) findKeypointAt;
  final int? Function(Offset localPos, Label label) findHandleAt;
  final int? Function(Offset normalized) findLabelAt;

  /// 解析最优命中（仅手柄/关键点）。
  CanvasPrimaryHit? resolvePrimaryHit(Offset normalized) {
    final localPos = Offset(
      normalized.dx * imageSize.width,
      normalized.dy * imageSize.height,
    );
    return _resolveHit(localPos, normalized, selectedLabelIndex);
  }

  /// 解析完整悬停结果。
  CanvasHoverResult resolve(Offset normalized) {
    final localPos = Offset(
      normalized.dx * imageSize.width,
      normalized.dy * imageSize.height,
    );

    final hitResult = _resolveHit(localPos, normalized, selectedLabelIndex);

    int? hoveredHandle;
    int? hoveredKeypointIndex;
    int? hoveredKeypointLabelIndex;
    int? hoveredVertexIndex;

    if (hitResult is CanvasKeypointHit) {
      hoveredKeypointLabelIndex = hitResult.labelIndex;
      hoveredKeypointIndex = hitResult.pointIndex;

      final label = labels[hitResult.labelIndex];
      final labelDef = getLabelDefinition(label.id);
      if (labelDef?.type == LabelType.polygon) {
        hoveredVertexIndex = hitResult.pointIndex;
      }
    } else if (hitResult is CanvasHandleHit) {
      hoveredHandle = hitResult.handle;
    }

    final hoveredLabelIndex = (hoveredHandle != null ||
            hoveredKeypointIndex != null ||
            hoveredVertexIndex != null)
        ? null
        : findLabelAt(normalized);

    return CanvasHoverResult(
      hoveredHandle: hoveredHandle,
      hoveredKeypointIndex: hoveredKeypointIndex,
      hoveredKeypointLabelIndex: hoveredKeypointLabelIndex,
      hoveredVertexIndex: hoveredVertexIndex,
      hoveredLabelIndex: hoveredLabelIndex,
    );
  }

  CanvasPrimaryHit? _resolveHit(
    Offset localPos,
    Offset normalized,
    int? selectedIndex,
  ) {
    final hitPoint = findKeypointAt(normalized);
    final keypointDist = _distanceToKeypoint(localPos, hitPoint);

    int? handle;
    double? handleDist;
    if (selectedIndex != null && selectedIndex < labels.length) {
      final label = labels[selectedIndex];
      handle = findHandleAt(localPos, label);
      handleDist = _distanceToHandle(localPos, label, handle);
    }

    if (hitPoint != null &&
        handle != null &&
        keypointDist != null &&
        handleDist != null) {
      return handleDist < keypointDist
          ? CanvasHandleHit(handle)
          : CanvasKeypointHit(hitPoint.labelIndex, hitPoint.pointIndex);
    }
    if (hitPoint != null) {
      return CanvasKeypointHit(hitPoint.labelIndex, hitPoint.pointIndex);
    }
    if (handle != null) {
      return CanvasHandleHit(handle);
    }
    return null;
  }

  double? _distanceToKeypoint(Offset localPos, HitKeypoint? hitPoint) {
    if (hitPoint == null || hitPoint.labelIndex >= labels.length) return null;
    final label = labels[hitPoint.labelIndex];
    if (hitPoint.pointIndex >= label.points.length) return null;
    final p = label.points[hitPoint.pointIndex];
    final pPos = Offset(p.x * imageSize.width, p.y * imageSize.height);
    return (pPos - localPos).distance;
  }

  double? _distanceToHandle(
    Offset localPos,
    Label label,
    int? handle,
  ) {
    if (handle == null) return null;
    final rect = Rect.fromLTWH(
      label.bbox[0] * imageSize.width,
      label.bbox[1] * imageSize.height,
      label.width * imageSize.width,
      label.height * imageSize.height,
    );
    final handles = buildHandlePoints(rect);
    if (handle < 0 || handle >= handles.length) return null;
    return (handles[handle] - localPos).distance;
  }
}

/// 悬停解析后的主命中类型。
sealed class CanvasPrimaryHit {
  const CanvasPrimaryHit();
}

/// 手柄命中。
class CanvasHandleHit extends CanvasPrimaryHit {
  const CanvasHandleHit(this.handle);

  final int handle;
}

/// 关键点命中。
class CanvasKeypointHit extends CanvasPrimaryHit {
  const CanvasKeypointHit(this.labelIndex, this.pointIndex);

  final int labelIndex;
  final int pointIndex;
}

/// 应用悬停状态到画布状态。
void applyHoverState({
  required CanvasProvider canvasProvider,
  required bool isLabelingMode,
  required CanvasHoverResult result,
}) {
  if (!isLabelingMode) {
    canvasProvider.setHoveredHandle(result.hoveredHandle);
    canvasProvider.setHoveredKeypoint(
        result.hoveredKeypointLabelIndex, result.hoveredKeypointIndex);
    canvasProvider.setHoveredVertexIndex(result.hoveredVertexIndex);
    canvasProvider.setActiveHandle(result.hoveredHandle);

    if (result.hasActiveHit) {
      canvasProvider.hoverLabel(result.hoveredKeypointLabelIndex ??
          canvasProvider.selectedLabelIndex);
    } else {
      canvasProvider.hoverLabel(result.hoveredLabelIndex);
    }
  } else {
    canvasProvider.setHoveredHandle(null);
    canvasProvider.setHoveredKeypoint(null, null);
    canvasProvider.setHoveredVertexIndex(null);
    canvasProvider.setActiveHandle(null);
    canvasProvider.hoverLabel(null);
  }
}
