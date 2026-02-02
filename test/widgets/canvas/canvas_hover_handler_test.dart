import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/widgets/canvas/canvas_helpers.dart';
import 'package:label_load/widgets/canvas/canvas_hover_handler.dart';

void main() {
  group('CanvasHoverResolver', () {
    test('prefers handle when closer than keypoint', () {
      final label = Label(
        id: 0,
        x: 0.2,
        y: 0.2,
        width: 0.2,
        height: 0.2,
        points: [LabelPoint(x: 0.2, y: 0.2)],
      );

      final resolver = CanvasHoverResolver(
        labels: [label],
        imageSize: const Size(100, 100),
        selectedLabelIndex: 0,
        getLabelDefinition: (_) => null,
        findKeypointAt: (_) => HitKeypoint(0, 0),
        findHandleAt: (_, __) => 0,
        findLabelAt: (_) => null,
      );

      final result = resolver.resolve(const Offset(0.105, 0.105));
      expect(result.hoveredHandle, 0);
      expect(result.hoveredKeypointIndex, isNull);
      expect(result.hoveredKeypointLabelIndex, isNull);
    });

    test('prefers keypoint when closer than handle', () {
      final label = Label(
        id: 0,
        x: 0.2,
        y: 0.2,
        width: 0.2,
        height: 0.2,
        points: [LabelPoint(x: 0.2, y: 0.2)],
      );

      final resolver = CanvasHoverResolver(
        labels: [label],
        imageSize: const Size(100, 100),
        selectedLabelIndex: 0,
        getLabelDefinition: (_) => null,
        findKeypointAt: (_) => HitKeypoint(0, 0),
        findHandleAt: (_, __) => 0,
        findLabelAt: (_) => null,
      );

      final result = resolver.resolve(const Offset(0.2, 0.2));
      expect(result.hoveredHandle, isNull);
      expect(result.hoveredKeypointLabelIndex, 0);
      expect(result.hoveredKeypointIndex, 0);
    });

    test('marks polygon vertex when keypoint hovered', () {
      final label = Label(
        id: 0,
        x: 0.2,
        y: 0.2,
        width: 0.2,
        height: 0.2,
        points: [LabelPoint(x: 0.2, y: 0.2)],
      );

      final resolver = CanvasHoverResolver(
        labels: [label],
        imageSize: const Size(100, 100),
        selectedLabelIndex: 0,
        getLabelDefinition: (_) => LabelDefinition(
          classId: 0,
          name: 'poly',
          color: const Color(0xFF000000),
          type: LabelType.polygon,
        ),
        findKeypointAt: (_) => HitKeypoint(0, 0),
        findHandleAt: (_, __) => 0,
        findLabelAt: (_) => null,
      );

      final result = resolver.resolve(const Offset(0.2, 0.2));
      expect(result.hoveredVertexIndex, 0);
    });
  });

  group('applyHoverState', () {
    test('clears hover state in labeling mode', () {
      final provider = CanvasProvider();

      applyHoverState(
        canvasProvider: provider,
        isLabelingMode: true,
        result: const CanvasHoverResult(
          hoveredHandle: 1,
          hoveredKeypointIndex: 2,
          hoveredKeypointLabelIndex: 3,
          hoveredVertexIndex: 4,
          hoveredLabelIndex: 5,
        ),
      );

      expect(provider.hoveredHandle, isNull);
      expect(provider.hoveredKeypointIndex, isNull);
      expect(provider.hoveredKeypointLabelIndex, isNull);
      expect(provider.hoveredVertexIndex, isNull);
      expect(provider.activeHandle, isNull);
      expect(provider.hoveredLabelIndex, isNull);
    });

    test('uses selected label when a handle is active', () {
      final provider = CanvasProvider();
      provider.selectLabel(3);

      applyHoverState(
        canvasProvider: provider,
        isLabelingMode: false,
        result: const CanvasHoverResult(
          hoveredHandle: 2,
          hoveredKeypointIndex: null,
          hoveredKeypointLabelIndex: null,
          hoveredVertexIndex: null,
          hoveredLabelIndex: 1,
        ),
      );

      expect(provider.hoveredHandle, 2);
      expect(provider.activeHandle, 2);
      expect(provider.hoveredLabelIndex, 3);
    });
  });
}
