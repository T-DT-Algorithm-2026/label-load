import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/canvas_provider.dart';

void main() {
  group('CanvasInteractionPolicy', () {
    test('allows drawing only in labeling mode', () {
      expect(
        CanvasInteractionPolicy.canStart(
          InteractionMode.none,
          InteractionMode.drawing,
          isLabelingMode: true,
        ),
        isTrue,
      );
      expect(
        CanvasInteractionPolicy.canStart(
          InteractionMode.none,
          InteractionMode.drawing,
          isLabelingMode: false,
        ),
        isFalse,
      );
    });

    test('allows edit interactions only outside labeling mode', () {
      for (final mode in [
        InteractionMode.moving,
        InteractionMode.resizing,
        InteractionMode.movingKeypoint,
      ]) {
        expect(
          CanvasInteractionPolicy.canStart(
            InteractionMode.none,
            mode,
            isLabelingMode: false,
          ),
          isTrue,
        );
        expect(
          CanvasInteractionPolicy.canStart(
            InteractionMode.none,
            mode,
            isLabelingMode: true,
          ),
          isFalse,
        );
      }
    });

    test('allows panning regardless of labeling mode', () {
      expect(
        CanvasInteractionPolicy.canStart(
          InteractionMode.none,
          InteractionMode.panning,
          isLabelingMode: true,
        ),
        isTrue,
      );
      expect(
        CanvasInteractionPolicy.canStart(
          InteractionMode.none,
          InteractionMode.panning,
          isLabelingMode: false,
        ),
        isTrue,
      );
    });

    test('rejects transitions from non-none states', () {
      expect(
        CanvasInteractionPolicy.canStart(
          InteractionMode.drawing,
          InteractionMode.moving,
          isLabelingMode: false,
        ),
        isFalse,
      );
      expect(CanvasInteractionPolicy.canEnd(InteractionMode.none), isFalse);
      expect(CanvasInteractionPolicy.canEnd(InteractionMode.drawing), isTrue);
    });
  });
}
