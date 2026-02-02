import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/canvas_provider.dart';

void main() {
  group('CanvasProvider', () {
    test('tryStartDrawing fails when not in labeling mode', () {
      final provider = CanvasProvider();

      final started = provider.tryStartDrawing(const Offset(0.1, 0.1));

      expect(started, isFalse);
      expect(provider.interactionMode, InteractionMode.none);
    });

    test('startDrawing/endInteraction returns rect and resets state', () {
      final provider = CanvasProvider();
      provider.setLabelingMode(true);

      provider.startDrawing(const Offset(0.1, 0.1));
      provider.updateDrag(const Offset(0.5, 0.6));

      final rect = provider.endInteraction();

      expect(rect, isNotNull);
      expect(rect!.width, closeTo(0.4, 1e-6));
      expect(rect.height, closeTo(0.5, 1e-6));
      expect(provider.interactionMode, InteractionMode.none);
      expect(provider.drawStart, isNull);
      expect(provider.drawCurrent, isNull);
    });

    test('endInteraction returns null for tiny draw', () {
      final provider = CanvasProvider();
      provider.setLabelingMode(true);

      provider.startDrawing(const Offset(0.1, 0.1));
      provider.updateDrag(const Offset(0.105, 0.105));

      final rect = provider.endInteraction();
      expect(rect, isNull);
    });

    test('startInteraction enters edit mode and endInteraction clears', () {
      final provider = CanvasProvider();

      provider.startInteraction(
        InteractionMode.moving,
        const Offset(0.2, 0.3),
      );

      expect(provider.interactionMode, InteractionMode.moving);
      expect(provider.drawCurrent, const Offset(0.2, 0.3));

      provider.updateDrag(const Offset(0.25, 0.35));
      expect(provider.drawCurrent, const Offset(0.25, 0.35));

      final rect = provider.endInteraction();
      expect(rect, isNull);
      expect(provider.interactionMode, InteractionMode.none);
    });

    test('cancelInteraction resets drawing state', () {
      final provider = CanvasProvider();
      provider.setLabelingMode(true);
      provider.startDrawing(const Offset(0.1, 0.1));

      provider.cancelInteraction();

      expect(provider.interactionMode, InteractionMode.none);
      expect(provider.drawStart, isNull);
      expect(provider.drawCurrent, isNull);
    });

    test('selection and hover state updates', () {
      final provider = CanvasProvider();

      provider.selectLabel(2);
      provider.hoverLabel(3);
      provider.setActiveHandle(1);
      provider.setActiveKeypoint(4);
      provider.setHoveredHandle(5);
      provider.setHoveredKeypoint(1, 2);
      provider.setHoveredVertexIndex(3);

      expect(provider.selectedLabelIndex, 2);
      expect(provider.hoveredLabelIndex, 3);
      expect(provider.activeHandle, 1);
      expect(provider.activeKeypointIndex, 4);
      expect(provider.hoveredHandle, 5);
      expect(provider.hoveredKeypointLabelIndex, 1);
      expect(provider.hoveredKeypointIndex, 2);
      expect(provider.hoveredVertexIndex, 3);
    });

    test('clearSelection resets selection and hover state', () {
      final provider = CanvasProvider();
      provider.selectLabel(1);
      provider.hoverLabel(2);
      provider.setActiveHandle(3);
      provider.setHoveredHandle(4);
      provider.setHoveredVertexIndex(5);

      provider.clearSelection();

      expect(provider.selectedLabelIndex, isNull);
      expect(provider.hoveredLabelIndex, isNull);
      expect(provider.activeHandle, isNull);
      expect(provider.hoveredHandle, isNull);
      expect(provider.hoveredVertexIndex, isNull);
    });

    test('binding candidates cycle and update selection', () {
      final provider = CanvasProvider();
      provider.setBindingCandidates([1, 2, 3]);

      expect(provider.currentBindingCandidate, 1);
      provider.cycleBindingCandidate();
      expect(provider.currentBindingCandidate, 2);
      expect(provider.selectedLabelIndex, 2);

      provider.cycleBindingCandidate();
      expect(provider.currentBindingCandidate, 3);

      provider.clearBindingCandidates();
      expect(provider.isBindingKeypoint, isFalse);
    });

    test('polygon point add/reset updates state', () {
      final provider = CanvasProvider();

      provider.addPolygonPoint(const Offset(0.1, 0.1));
      provider.addPolygonPoint(const Offset(0.2, 0.2));
      expect(provider.isCreatingPolygon, isTrue);
      expect(provider.currentPolygonPoints.length, 2);

      provider.resetPolygon();
      expect(provider.isCreatingPolygon, isFalse);
      expect(provider.currentPolygonPoints, isEmpty);
    });

    test('toggles crosshair and dark enhancement', () {
      final provider = CanvasProvider();
      final crosshair = provider.showCrosshair;
      final dark = provider.enhanceDark;

      provider.toggleCrosshair();
      provider.toggleDarkEnhancement();

      expect(provider.showCrosshair, !crosshair);
      expect(provider.enhanceDark, !dark);
    });

    test('exposes snapshot and debug string', () {
      final provider = CanvasProvider();
      provider.setLabelingMode(true);
      provider.startDrawing(const Offset(0.1, 0.1));
      provider.updateDrag(const Offset(0.2, 0.2));

      final snapshot = provider.debugSnapshot();
      final text = snapshot.toDebugString();

      expect(snapshot.interactionMode, InteractionMode.drawing);
      expect(text, contains('mode='));
    });

    test('toggleLabelingMode flips state', () {
      final provider = CanvasProvider();
      final before = provider.isLabelingMode;
      provider.toggleLabelingMode();
      expect(provider.isLabelingMode, !before);
    });

    test('label type and class id setters update state', () {
      final provider = CanvasProvider();
      provider.setLabelType(2);
      expect(provider.labelType, 2);

      provider.cycleLabelType();
      expect(provider.labelType, 0);

      provider.setCurrentClassId(4);
      expect(provider.currentClassId, 4);
    });

    test('mouse position update is reflected', () {
      final provider = CanvasProvider();
      provider.updateMousePosition(const Offset(0.3, 0.4));
      expect(provider.mousePosition, const Offset(0.3, 0.4));
      provider.updateMousePosition(null);
      expect(provider.mousePosition, isNull);
    });
  });

  group('CanvasInteractionPolicy helpers', () {
    test('canStart/CanEnd respond to state', () {
      expect(
        CanvasInteractionPolicy.canStart(
          InteractionMode.none,
          InteractionMode.none,
          isLabelingMode: true,
        ),
        isFalse,
      );
      expect(
        CanvasInteractionPolicy.canStart(
          InteractionMode.none,
          InteractionMode.panning,
          isLabelingMode: true,
        ),
        isTrue,
      );
      expect(CanvasInteractionPolicy.canEnd(InteractionMode.none), isFalse);
      expect(CanvasInteractionPolicy.canEnd(InteractionMode.panning), isTrue);
    });
  });

  test('CanvasProvider detects invalid hover mismatch', () {
    final provider = CanvasProvider();

    expect(
      () {
        provider.setHoveredKeypoint(null, 1);
        provider.addPolygonPoint(const Offset(0.2, 0.2));
      },
      throwsA(isA<AssertionError>()),
    );
  });
}
