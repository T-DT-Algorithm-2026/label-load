import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/widgets/canvas/keyboard_pointer_action_state.dart';
import 'package:label_load/widgets/canvas/pointer_drag_tracker.dart';

void main() {
  group('KeyboardPointerActionState', () {
    test('startAction initializes create state', () {
      final state = KeyboardPointerActionState();
      final tracker = PointerDragTracker();
      const position = Offset(10, 20);

      state.startAction(BindableAction.mouseCreate, position, tracker);

      expect(state.action, BindableAction.mouseCreate);
      expect(state.createPending, isTrue);
      expect(state.createAnchor, position);
      expect(tracker.downPosition, position);
      expect(tracker.lastButtons, 0);
    });

    test('finishAction triggers create click when click and idle', () {
      final state = KeyboardPointerActionState();
      final tracker = PointerDragTracker();
      const position = Offset(5, 6);
      tracker.start(position, 1);

      bool createCalled = false;
      bool panEnded = false;

      state.finishAction(
        action: BindableAction.mouseCreate,
        tracker: tracker,
        isInteractionActive: false,
        toLocal: (global) => global,
        onCreateClick: (_) => createCalled = true,
        onDeleteClick: (_) {},
        onPanEnd: () => panEnded = true,
      );

      expect(createCalled, isTrue);
      expect(panEnded, isFalse);
      expect(state.action, isNull);
    });

    test('finishAction ends pan when create was dragging', () {
      final state = KeyboardPointerActionState();
      final tracker = PointerDragTracker();
      const position = Offset(5, 6);
      tracker.start(position, 1);
      tracker.update(const Offset(20, 20));

      bool panEnded = false;

      state.finishAction(
        action: BindableAction.mouseCreate,
        tracker: tracker,
        isInteractionActive: true,
        toLocal: (global) => global,
        onCreateClick: (_) {},
        onDeleteClick: (_) {},
        onPanEnd: () => panEnded = true,
      );

      expect(panEnded, isTrue);
      expect(state.action, isNull);
    });

    test('finishAction triggers delete click', () {
      final state = KeyboardPointerActionState();
      final tracker = PointerDragTracker();
      const position = Offset(1, 2);
      tracker.start(position, 2);

      bool deleteCalled = false;

      state.finishAction(
        action: BindableAction.mouseDelete,
        tracker: tracker,
        isInteractionActive: false,
        toLocal: (global) => global,
        onCreateClick: (_) {},
        onDeleteClick: (_) => deleteCalled = true,
        onPanEnd: () {},
      );

      expect(deleteCalled, isTrue);
      expect(state.action, isNull);
    });
  });
}
