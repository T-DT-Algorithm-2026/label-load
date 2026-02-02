import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/input/input_action_gate.dart';
import 'package:label_load/providers/keybindings_provider.dart';

void main() {
  group('InputActionGate', () {
    final gate = InputActionGate.instance;

    setUp(() {
      gate.reset();
    });

    test('first action should pass', () {
      final allowed = gate.shouldHandle(
        BindableAction.nextImage,
        InputSource.keyboard,
        window: const Duration(days: 1),
      );
      expect(allowed, isTrue);
    });

    test('same action different source within window should be blocked', () {
      gate.shouldHandle(
        BindableAction.nextImage,
        InputSource.keyboard,
        window: const Duration(days: 1),
      );
      final allowed = gate.shouldHandle(
        BindableAction.nextImage,
        InputSource.pointer,
        window: const Duration(days: 1),
      );
      expect(allowed, isFalse);
    });

    test('same action same source should pass', () {
      gate.shouldHandle(
        BindableAction.nextImage,
        InputSource.keyboard,
        window: const Duration(days: 1),
      );
      final allowed = gate.shouldHandle(
        BindableAction.nextImage,
        InputSource.keyboard,
        window: const Duration(days: 1),
      );
      expect(allowed, isTrue);
    });

    test('different action should pass even within window', () {
      gate.shouldHandle(
        BindableAction.nextImage,
        InputSource.keyboard,
        window: const Duration(days: 1),
      );
      final allowed = gate.shouldHandle(
        BindableAction.prevImage,
        InputSource.pointer,
        window: const Duration(days: 1),
      );
      expect(allowed, isTrue);
    });
  });
}
