import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/widgets/canvas/pointer_drag_tracker.dart';

void main() {
  group('PointerDragTracker', () {
    test('start initializes state', () {
      final tracker = PointerDragTracker();
      tracker.start(const Offset(10, 20), 3);

      expect(tracker.downPosition, const Offset(10, 20));
      expect(tracker.lastGlobalPosition, const Offset(10, 20));
      expect(tracker.lastButtons, 3);
      expect(tracker.moved, isFalse);
      expect(tracker.wasClick, isTrue);
    });

    test('update marks moved when beyond threshold', () {
      final tracker = PointerDragTracker();
      tracker.start(const Offset(0, 0), 1);
      tracker.update(const Offset(10, 0), threshold: 5.0);

      expect(tracker.moved, isTrue);
      expect(tracker.wasClick, isFalse);
    });

    test('setDownPosition resets moved', () {
      final tracker = PointerDragTracker();
      tracker.start(const Offset(0, 0), 1);
      tracker.update(const Offset(10, 0));
      expect(tracker.moved, isTrue);

      tracker.setDownPosition(const Offset(5, 5));
      expect(tracker.downPosition, const Offset(5, 5));
      expect(tracker.moved, isFalse);
    });

    test('reset clears click tracking', () {
      final tracker = PointerDragTracker();
      tracker.start(const Offset(0, 0), 1);
      tracker.reset();

      expect(tracker.downPosition, isNull);
      expect(tracker.moved, isFalse);
      expect(tracker.wasClick, isFalse);
    });
  });
}
