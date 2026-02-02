import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/canvas_provider.dart';

void main() {
  group('CanvasInteractionSnapshot', () {
    test('captures idle state', () {
      final provider = CanvasProvider();
      final snapshot = provider.debugSnapshot();

      expect(snapshot.interactionMode, InteractionMode.none);
      expect(snapshot.drawStart, isNull);
      expect(snapshot.dragCurrentPoint, isNull);
      expect(snapshot.polygonPointCount, 0);
      expect(snapshot.bindingCandidateCount, 0);
    });

    test('captures drawing lifecycle', () {
      final provider = CanvasProvider()..setLabelingMode(true);

      provider.startDrawing(const Offset(0.1, 0.2));
      var snapshot = provider.debugSnapshot();
      expect(snapshot.interactionMode, InteractionMode.drawing);
      expect(snapshot.drawStart, const Offset(0.1, 0.2));
      expect(snapshot.dragCurrentPoint, const Offset(0.1, 0.2));

      provider.updateDrag(const Offset(0.4, 0.6));
      snapshot = provider.debugSnapshot();
      expect(snapshot.dragCurrentPoint, const Offset(0.4, 0.6));

      provider.endInteraction();
      snapshot = provider.debugSnapshot();
      expect(snapshot.interactionMode, InteractionMode.none);
      expect(snapshot.drawStart, isNull);
      expect(snapshot.dragCurrentPoint, isNull);
    });

    test('captures binding candidate cycling', () {
      final provider = CanvasProvider();
      provider.setBindingCandidates([2, 4, 7]);

      var snapshot = provider.debugSnapshot();
      expect(snapshot.bindingCandidateCount, 3);
      expect(snapshot.bindingCandidateIndex, 0);

      provider.cycleBindingCandidate();
      snapshot = provider.debugSnapshot();
      expect(snapshot.bindingCandidateIndex, 1);
    });
  });
}
