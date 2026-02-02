import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/input/keyboard_state_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HardwareKeyboardStateReader reflects pressed keys',
      (tester) async {
    const reader = HardwareKeyboardStateReader();

    expect(reader.logicalKeysPressed, isEmpty);
    expect(reader.isControlPressed, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(reader.isControlPressed, isTrue);
    expect(
      reader.logicalKeysPressed,
      contains(LogicalKeyboardKey.controlLeft),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(reader.isShiftPressed, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(reader.isAltPressed, isTrue);
    expect(reader.isMetaPressed, isTrue);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(reader.isControlPressed, isFalse);
    expect(reader.isShiftPressed, isFalse);
    expect(reader.isAltPressed, isFalse);
    expect(reader.isMetaPressed, isFalse);
  });
}
