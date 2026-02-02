import 'package:flutter/material.dart';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/project_provider.dart';
import 'canvas_helpers.dart';
import 'canvas_hover_handler.dart';

/// 编辑模式拖拽起始处理器。
///
/// 根据命中结果决定进入移动、调整大小或关键点编辑等交互。
class EditModeDragStartHandler {
  EditModeDragStartHandler({
    required this.canvasProvider,
    required this.projectProvider,
    required this.labels,
    required this.definitions,
    required this.imageSize,
    required this.normalized,
    required this.localPos,
    required this.findKeypointAt,
    required this.findHandleAt,
    required this.findEdgeAt,
    required this.findLabelAt,
    required this.setResizeStartRect,
  });

  final CanvasProvider canvasProvider;
  final ProjectProvider projectProvider;
  final List<Label> labels;
  final List<LabelDefinition> definitions;
  final Size imageSize;
  final Offset normalized;
  final Offset localPos;

  final HitKeypoint? Function(Offset normalized) findKeypointAt;
  final int? Function(Offset localPos, Label label) findHandleAt;
  final int? Function(Offset localPos, Label label) findEdgeAt;
  final int? Function(Offset normalized) findLabelAt;
  final void Function(Rect rect) setResizeStartRect;

  /// 执行拖拽起始判定流程。
  void run() {
    LabelType getLabelType(Label label) {
      return definitions.typeForClassId(label.id);
    }

    void startKeypointMove(int labelIndex, int pointIndex) {
      canvasProvider.selectLabel(labelIndex);
      canvasProvider.setActiveKeypoint(pointIndex);
      projectProvider.addToHistory();
      canvasProvider.tryStartInteraction(
        InteractionMode.movingKeypoint,
        normalized,
      );
    }

    void startHandleResize(int handle, int labelIndex) {
      canvasProvider.setActiveHandle(handle);
      final label = labels[labelIndex];
      setResizeStartRect(
        Rect.fromLTRB(
          label.bbox[0],
          label.bbox[1],
          label.bbox[2],
          label.bbox[3],
        ),
      );
      projectProvider.addToHistory();
      canvasProvider.tryStartInteraction(InteractionMode.resizing, normalized);
    }

    // 步骤 1：检查关键点与手柄（按距离优先级）。
    final selectedIndex = canvasProvider.selectedLabelIndex;
    final hoverResolver = CanvasHoverResolver(
      labels: labels,
      imageSize: imageSize,
      selectedLabelIndex: selectedIndex,
      getLabelDefinition: projectProvider.getLabelDefinition,
      findKeypointAt: findKeypointAt,
      findHandleAt: (pos, label) {
        final type = getLabelType(label);
        if (type == LabelType.box ||
            type == LabelType.boxWithPoint ||
            type == LabelType.polygon) {
          return findHandleAt(pos, label);
        }
        return null;
      },
      findLabelAt: findLabelAt,
    );
    final primaryHit = hoverResolver.resolvePrimaryHit(normalized);
    final hoverResult = hoverResolver.resolve(normalized);

    if (primaryHit is CanvasHandleHit && selectedIndex != null) {
      startHandleResize(primaryHit.handle, selectedIndex);
      return;
    }

    if (primaryHit is CanvasKeypointHit) {
      startKeypointMove(
        primaryHit.labelIndex,
        primaryHit.pointIndex,
      );
      return;
    }

    // 步骤 2：检查多边形边缘并插入新顶点。
    if (selectedIndex != null && selectedIndex < labels.length) {
      final idx = selectedIndex;
      final label = labels[idx];
      final type = getLabelType(label);
      if (type == LabelType.polygon) {
        final edgeIndex = findEdgeAt(localPos, label);

        if (edgeIndex != null) {
          projectProvider.addToHistory();
          final newPoints = List<LabelPoint>.from(label.points);
          newPoints.insert(
            edgeIndex + 1,
            LabelPoint(x: normalized.dx, y: normalized.dy),
          );
          final newLabel = label.copyWith(points: newPoints);
          newLabel.updateBboxFromPoints();
          projectProvider.updateLabel(idx, newLabel, addToHistory: false);
          canvasProvider.setActiveKeypoint(edgeIndex + 1);
          canvasProvider.tryStartInteraction(
            InteractionMode.movingKeypoint,
            normalized,
          );
          return;
        }
      }
    }

    // 步骤 3：检查标签主体命中。
    final hoveredIndex = hoverResult.hoveredLabelIndex;
    if (hoveredIndex != null) {
      if (selectedIndex != hoveredIndex) {
        canvasProvider.selectLabel(hoveredIndex);
      }
      projectProvider.addToHistory();
      canvasProvider.tryStartInteraction(InteractionMode.moving, normalized);
      return;
    }

    canvasProvider.clearSelection();
  }
}
