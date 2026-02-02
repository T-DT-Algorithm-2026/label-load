import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/widgets/canvas/interaction_update_handler.dart';

void main() {
  group('InteractionUpdateHandler', () {
    test('dispatches to the correct handler per interaction mode', () {
      int panCalls = 0;
      int resizeCalls = 0;
      int moveCalls = 0;
      int drawCalls = 0;
      int keypointCalls = 0;
      int hoverCalls = 0;

      void resetCounters() {
        panCalls = 0;
        resizeCalls = 0;
        moveCalls = 0;
        drawCalls = 0;
        keypointCalls = 0;
        hoverCalls = 0;
      }

      InteractionUpdateHandler handler(InteractionMode mode) {
        final provider = CanvasProvider();
        if (mode == InteractionMode.drawing) {
          provider.setLabelingMode(true);
          provider.startDrawing(const Offset(0.1, 0.1));
        } else if (mode != InteractionMode.none) {
          provider.setLabelingMode(false);
          provider.startInteraction(mode, const Offset(0.2, 0.2));
        }

        return InteractionUpdateHandler(
          canvasProvider: provider,
          normalized: const Offset(0.3, 0.3),
          applyPan: (_, __) => panCalls += 1,
          handleResize: () => resizeCalls += 1,
          handleMove: () => moveCalls += 1,
          handleMoveKeypoint: () => keypointCalls += 1,
          handlePolygonHover: () => hoverCalls += 1,
          updateDrawing: () => drawCalls += 1,
        );
      }

      resetCounters();
      handler(InteractionMode.panning).run(const Offset(1, 1));
      expect(panCalls, 1);
      expect(resizeCalls + moveCalls + drawCalls + keypointCalls, 0);

      resetCounters();
      handler(InteractionMode.resizing).run(const Offset(1, 1));
      expect(resizeCalls, 1);
      expect(panCalls + moveCalls + drawCalls + keypointCalls, 0);

      resetCounters();
      handler(InteractionMode.moving).run(const Offset(1, 1));
      expect(moveCalls, 1);
      expect(panCalls + resizeCalls + drawCalls + keypointCalls, 0);

      resetCounters();
      handler(InteractionMode.drawing).run(const Offset(1, 1));
      expect(drawCalls, 1);
      expect(panCalls + resizeCalls + moveCalls + keypointCalls, 0);

      resetCounters();
      handler(InteractionMode.movingKeypoint).run(const Offset(1, 1));
      expect(keypointCalls, 1);
      expect(panCalls + resizeCalls + moveCalls + drawCalls, 0);
    });

    test('hover handler runs when creating polygon in none mode', () {
      final provider = CanvasProvider()
        ..addPolygonPoint(const Offset(0.1, 0.1));
      int hoverCalls = 0;

      InteractionUpdateHandler(
        canvasProvider: provider,
        normalized: const Offset(0.2, 0.2),
        applyPan: (_, __) {},
        handleResize: () {},
        handleMove: () {},
        handleMoveKeypoint: () {},
        handlePolygonHover: () => hoverCalls += 1,
        updateDrawing: () {},
      ).run(const Offset(1, 1));

      expect(hoverCalls, 1);
    });
  });
}
