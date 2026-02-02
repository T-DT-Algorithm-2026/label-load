import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/widgets/canvas/canvas_hover_handler.dart';
import 'package:label_load/widgets/canvas/edit_mode_selection_handler.dart';

void main() {
  group('applyEditModeSelection', () {
    test('selects handle on selected label', () {
      final provider = CanvasProvider()..selectLabel(2);

      applyEditModeSelection(
        canvasProvider: provider,
        hoverResult: const CanvasHoverResult(
          hoveredHandle: 1,
          hoveredKeypointIndex: null,
          hoveredKeypointLabelIndex: null,
          hoveredVertexIndex: null,
          hoveredLabelIndex: null,
        ),
      );

      expect(provider.selectedLabelIndex, 2);
      expect(provider.activeHandle, 1);
      expect(provider.activeKeypointIndex, isNull);
    });

    test('selects keypoint when keypoint is hit', () {
      final provider = CanvasProvider();

      applyEditModeSelection(
        canvasProvider: provider,
        hoverResult: const CanvasHoverResult(
          hoveredHandle: null,
          hoveredKeypointIndex: 3,
          hoveredKeypointLabelIndex: 1,
          hoveredVertexIndex: null,
          hoveredLabelIndex: null,
        ),
      );

      expect(provider.selectedLabelIndex, 1);
      expect(provider.activeKeypointIndex, 3);
    });

    test('selects label when body is hit', () {
      final provider = CanvasProvider();

      applyEditModeSelection(
        canvasProvider: provider,
        hoverResult: const CanvasHoverResult(
          hoveredHandle: null,
          hoveredKeypointIndex: null,
          hoveredKeypointLabelIndex: null,
          hoveredVertexIndex: null,
          hoveredLabelIndex: 5,
        ),
      );

      expect(provider.selectedLabelIndex, 5);
      expect(provider.activeKeypointIndex, isNull);
    });

    test('clears selection when nothing is hit', () {
      final provider = CanvasProvider()..selectLabel(1);

      applyEditModeSelection(
        canvasProvider: provider,
        hoverResult: const CanvasHoverResult(
          hoveredHandle: null,
          hoveredKeypointIndex: null,
          hoveredKeypointLabelIndex: null,
          hoveredVertexIndex: null,
          hoveredLabelIndex: null,
        ),
      );

      expect(provider.selectedLabelIndex, isNull);
    });
  });
}
