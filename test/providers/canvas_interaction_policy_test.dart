import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/canvas_provider.dart';

void main() {
  group('CanvasInteractionPolicy', () {
    test('labeling mode allows drawing and panning only', () {
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.drawing,
          isLabelingMode: true,
        ).allowed,
        isTrue,
      );
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.panning,
          isLabelingMode: true,
        ).allowed,
        isTrue,
      );
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.moving,
          isLabelingMode: true,
        ).allowed,
        isFalse,
      );
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.resizing,
          isLabelingMode: true,
        ).allowed,
        isFalse,
      );
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.movingKeypoint,
          isLabelingMode: true,
        ).allowed,
        isFalse,
      );
    });

    test('editing mode allows edit interactions and panning only', () {
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.moving,
          isLabelingMode: false,
        ).allowed,
        isTrue,
      );
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.resizing,
          isLabelingMode: false,
        ).allowed,
        isTrue,
      );
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.movingKeypoint,
          isLabelingMode: false,
        ).allowed,
        isTrue,
      );
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.panning,
          isLabelingMode: false,
        ).allowed,
        isTrue,
      );
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.none,
          InteractionMode.drawing,
          isLabelingMode: false,
        ).allowed,
        isFalse,
      );
    });

    test('cannot start a new interaction while already interacting', () {
      expect(
        CanvasInteractionPolicy.validateStart(
          InteractionMode.drawing,
          InteractionMode.panning,
          isLabelingMode: true,
        ).allowed,
        isFalse,
      );
    });
  });
}
