import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/canvas_provider.dart';

void main() {
  group('CanvasProvider interaction guards', () {
    test('tryStartDrawing returns false when not in labeling mode', () {
      final provider = CanvasProvider();

      final result = provider.tryStartDrawing(const Offset(0.1, 0.2));

      expect(result, isFalse);
      expect(provider.interactionMode, InteractionMode.none);
      expect(provider.drawStart, isNull);
      expect(provider.drawCurrent, isNull);
    });

    test(
        'tryStartInteraction returns false for edit interactions in labeling mode',
        () {
      final provider = CanvasProvider()..setLabelingMode(true);

      final result = provider.tryStartInteraction(
        InteractionMode.moving,
        const Offset(0.2, 0.3),
      );

      expect(result, isFalse);
      expect(provider.interactionMode, InteractionMode.none);
      expect(provider.drawCurrent, isNull);
    });

    test('panning is allowed regardless of labeling mode', () {
      final provider = CanvasProvider()..setLabelingMode(true);

      provider.startInteraction(
          InteractionMode.panning, const Offset(0.2, 0.3));

      expect(provider.interactionMode, InteractionMode.panning);
      expect(provider.drawCurrent, const Offset(0.2, 0.3));
    });

    test('tryStartInteraction returns false while already interacting', () {
      final provider = CanvasProvider()..setLabelingMode(true);
      provider.startDrawing(const Offset(0.1, 0.1));

      final result = provider.tryStartInteraction(
        InteractionMode.panning,
        const Offset(0.2, 0.2),
      );

      expect(result, isFalse);
      expect(provider.interactionMode, InteractionMode.drawing);
      expect(provider.drawStart, const Offset(0.1, 0.1));
    });

    test('mode switch to edit cancels drawing and clears labeling state', () {
      final provider = CanvasProvider()..setLabelingMode(true);
      provider.startDrawing(const Offset(0.1, 0.2));
      provider.addPolygonPoint(const Offset(0.3, 0.4));

      provider.setLabelingMode(false);

      expect(provider.interactionMode, InteractionMode.none);
      expect(provider.drawStart, isNull);
      expect(provider.drawCurrent, isNull);
      expect(provider.isCreatingPolygon, isFalse);
    });

    test('mode switch to labeling cancels edit interaction and clears handles',
        () {
      final provider = CanvasProvider();
      provider.startInteraction(
        InteractionMode.moving,
        const Offset(0.2, 0.3),
      );
      provider.setActiveHandle(1);
      provider.setHoveredHandle(2);
      provider.setHoveredKeypoint(0, 1);
      provider.setHoveredVertexIndex(3);

      provider.setLabelingMode(true);

      expect(provider.interactionMode, InteractionMode.none);
      expect(provider.activeHandle, isNull);
      expect(provider.hoveredHandle, isNull);
      expect(provider.hoveredKeypointIndex, isNull);
      expect(provider.hoveredKeypointLabelIndex, isNull);
      expect(provider.hoveredVertexIndex, isNull);
    });
  });
}
