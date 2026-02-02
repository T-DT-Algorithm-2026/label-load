import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/services/input/keybindings_store.dart';
import 'package:label_load/services/input/keyboard_state_reader.dart';

import 'test_helpers.dart';

class FakeKeyBindingsStore implements KeyBindingsStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class ThrowingKeyBindingsStore implements KeyBindingsStore {
  @override
  Future<String?> read() async {
    throw Exception('read failed');
  }

  @override
  Future<void> write(String value) async {
    throw Exception('write failed');
  }
}

class FakeKeyboardStateReader implements KeyboardStateReader {
  FakeKeyboardStateReader({
    this.isControlPressed = false,
    this.isMetaPressed = false,
    this.isShiftPressed = false,
    this.isAltPressed = false,
    Set<LogicalKeyboardKey>? logicalKeysPressed,
  }) : logicalKeysPressed = logicalKeysPressed ?? {};

  @override
  bool isControlPressed;

  @override
  bool isMetaPressed;

  @override
  bool isShiftPressed;

  @override
  bool isAltPressed;

  @override
  Set<LogicalKeyboardKey> logicalKeysPressed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyBindingsProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('matchesScroll respects scroll direction', () async {
      final provider = KeyBindingsProvider();
      await provider.setBinding(
        BindableAction.zoomIn,
        const KeyBinding.scroll(ScrollActionType.scrollUp),
      );
      await provider.setBinding(
        BindableAction.zoomOut,
        const KeyBinding.scroll(ScrollActionType.scrollDown),
      );

      expect(provider.matchesScroll(BindableAction.zoomIn, -10.0), isTrue);
      expect(provider.matchesScroll(BindableAction.zoomIn, 10.0), isFalse);
      expect(provider.matchesScroll(BindableAction.zoomOut, 10.0), isTrue);
      expect(provider.matchesScroll(BindableAction.zoomOut, -10.0), isFalse);
    });

    test('matchesKeyEvent handles Alt key binding', () async {
      final provider = KeyBindingsProvider();
      await provider.setBinding(
        BindableAction.cancelOperation,
        const KeyBinding.keyboard(LogicalKeyboardKey.altLeft),
      );

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.altLeft,
        logicalKey: LogicalKeyboardKey.altLeft,
        timeStamp: Duration.zero,
      );

      expect(provider.matchesKeyEvent(BindableAction.cancelOperation, event),
          isTrue);
    });

    test('writes bindings through injected store', () async {
      final store = FakeKeyBindingsStore();
      final provider = KeyBindingsProvider(store: store);

      await provider.setBinding(
        BindableAction.save,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyP),
      );

      expect(store.value, isNotNull);
      final json = jsonDecode(store.value!) as Map<String, dynamic>;
      expect(json.containsKey(BindableAction.save.index.toString()), isTrue);
    });

    test('matchesKeyEvent uses injected keyboard state', () async {
      final reader = FakeKeyboardStateReader(isControlPressed: true);
      final provider = KeyBindingsProvider(keyboardStateReader: reader);
      await provider.setBinding(
        BindableAction.save,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyS, ctrl: true),
      );

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyS,
        logicalKey: LogicalKeyboardKey.keyS,
        timeStamp: Duration.zero,
      );

      expect(provider.matchesKeyEvent(BindableAction.save, event), isTrue);
    });

    test('KeyBinding serializes and deserializes for keyboard/mouse/scroll',
        () {
      const keyboard = KeyBinding.keyboard(
        LogicalKeyboardKey.keyA,
        ctrl: true,
        shift: false,
        alt: true,
      );
      const mouse = KeyBinding.mouse(MouseButton.middle);
      const scroll = KeyBinding.scroll(ScrollActionType.scrollDown);

      final keyboardJson = keyboard.toJson();
      final mouseJson = mouse.toJson();
      final scrollJson = scroll.toJson();

      expect(KeyBinding.fromJson(keyboardJson), keyboard);
      expect(KeyBinding.fromJson(mouseJson), mouse);
      expect(KeyBinding.fromJson(scrollJson), scroll);
    });

    test('KeyBinding getDisplayName covers none and mouse', () {
      expect(KeyBinding.none.getDisplayName(), '(无)');
      expect(
        const KeyBinding.mouse(MouseButton.left).getDisplayName(),
        contains('鼠标左键'),
      );
      expect(
        const KeyBinding.mouse(MouseButton.right).getDisplayName(),
        contains('鼠标右键'),
      );
      expect(
        const KeyBinding.mouse(MouseButton.middle).getDisplayName(),
        contains('鼠标中键'),
      );
      expect(
        const KeyBinding.mouse(MouseButton.back).getDisplayName(),
        contains('鼠标后退键'),
      );
      expect(
        const KeyBinding.mouse(MouseButton.forward).getDisplayName(),
        contains('鼠标前进键'),
      );
      expect(
        const KeyBinding.scroll(ScrollActionType.scrollUp).getDisplayName(),
        contains('滚轮上滚'),
      );
      expect(
        const KeyBinding.scroll(ScrollActionType.scrollDown).getDisplayName(),
        contains('滚轮下滚'),
      );
    });

    test('KeyBinding hashCode matches equality', () {
      const bindingA = KeyBinding.keyboard(LogicalKeyboardKey.keyA);
      const bindingB = KeyBinding.keyboard(LogicalKeyboardKey.keyA);
      expect(bindingA, bindingB);
      expect(bindingA.hashCode, bindingB.hashCode);
    });

    test('setBinding clears conflicts for other actions', () async {
      final store = FakeKeyBindingsStore();
      final provider = KeyBindingsProvider(store: store);

      await Future<void>.delayed(Duration.zero);

      await provider.setBinding(
        BindableAction.nextImage,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyA),
      );

      expect(
        provider.getBinding(BindableAction.prevImage).isNone,
        isTrue,
      );
    });

    test('clearBinding and resetToDefault update bindings', () async {
      final provider = KeyBindingsProvider();
      await Future<void>.delayed(Duration.zero);

      await provider.clearBinding(BindableAction.save);
      expect(provider.getBinding(BindableAction.save).isNone, isTrue);

      await provider.resetToDefault();
      expect(provider.getBinding(BindableAction.save).isNone, isFalse);
    });

    test('matchesKeyboardState checks pressed keys with modifiers', () async {
      final reader = FakeKeyboardStateReader(
        isControlPressed: true,
        logicalKeysPressed: {LogicalKeyboardKey.keyZ},
      );
      final provider = KeyBindingsProvider(keyboardStateReader: reader);
      await provider.setBinding(
        BindableAction.undo,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyZ, ctrl: true),
      );

      expect(provider.matchesKeyboardState(BindableAction.undo), isTrue);
    });

    test('mouse button mapping helpers', () async {
      final provider = KeyBindingsProvider();
      await Future<void>.delayed(Duration.zero);

      await provider.setBinding(
        BindableAction.mouseCreate,
        const KeyBinding.mouse(MouseButton.left),
      );

      expect(
        provider.getPointerButton(BindableAction.mouseCreate),
        kPrimaryMouseButton,
      );
      expect(
        KeyBindingsProvider.mouseButtonFromButtons(kSecondaryMouseButton),
        MouseButton.right,
      );
      expect(
        KeyBindingsProvider.sideButtonFromButtons(kBackMouseButton),
        MouseButton.back,
      );
      expect(
        KeyBindingsProvider.sideButtonFromKey(LogicalKeyboardKey.browserBack),
        MouseButton.back,
      );

      final action = provider.getActionForMouseButtons(kPrimaryMouseButton);
      expect(action, BindableAction.mouseCreate);
    });

    test('bindings getter exposes loaded values', () async {
      final store = FakeKeyBindingsStore()
        ..value = jsonEncode({
          BindableAction.save.index.toString(): const KeyBinding.keyboard(
            LogicalKeyboardKey.keyP,
          ).toJson(),
        });
      final provider = KeyBindingsProvider(store: store);

      await Future<void>.delayed(Duration.zero);

      expect(provider.isInitialized, isTrue);
      expect(provider.bindings, isNotEmpty);
      expect(
        provider.getBinding(BindableAction.save),
        const KeyBinding.keyboard(LogicalKeyboardKey.keyP),
      );
    });

    test('mouse button actions and display names cover all buttons', () async {
      final provider = KeyBindingsProvider();
      await Future<void>.delayed(Duration.zero);

      await provider.setBinding(
        BindableAction.mouseCreate,
        const KeyBinding.mouse(MouseButton.left),
      );
      await provider.setBinding(
        BindableAction.mouseDelete,
        const KeyBinding.mouse(MouseButton.right),
      );
      await provider.setBinding(
        BindableAction.mouseMove,
        const KeyBinding.mouse(MouseButton.middle),
      );
      await provider.setBinding(
        BindableAction.save,
        const KeyBinding.mouse(MouseButton.back),
      );
      await provider.setBinding(
        BindableAction.undo,
        const KeyBinding.mouse(MouseButton.forward),
      );

      expect(
        provider.getPointerButton(BindableAction.mouseCreate),
        kPrimaryMouseButton,
      );
      expect(
        provider.getPointerButton(BindableAction.mouseDelete),
        kSecondaryMouseButton,
      );
      expect(
        provider.getPointerButton(BindableAction.mouseMove),
        kMiddleMouseButton,
      );
      expect(
        provider.getPointerButton(BindableAction.save),
        kBackMouseButton,
      );
      expect(
        provider.getPointerButton(BindableAction.undo),
        kForwardMouseButton,
      );

      expect(
        provider.getActionForSideButton(kBackMouseButton),
        BindableAction.save,
      );
      expect(
        provider.getActionForSideButton(kForwardMouseButton),
        BindableAction.undo,
      );
      expect(
        provider.getActionForSideButtonKey(LogicalKeyboardKey.browserBack),
        BindableAction.save,
      );
      expect(
        provider.getActionForSideButtonKey(LogicalKeyboardKey.browserForward),
        BindableAction.undo,
      );

      expect(
        provider.getMouseActionDisplayName(BindableAction.mouseCreate),
        contains('左键'),
      );
      expect(
        provider.getMouseActionDisplayName(BindableAction.mouseDelete),
        contains('右键'),
      );
      expect(
        provider.getMouseActionDisplayName(BindableAction.mouseMove),
        contains('中键'),
      );
      expect(
        provider.getMouseActionDisplayName(BindableAction.save),
        contains('后退键'),
      );
      expect(
        provider.getMouseActionDisplayName(BindableAction.undo),
        contains('前进键'),
      );
    });

    test('action descriptions and categories cover all actions', () {
      for (final action in BindableAction.values) {
        final desc = KeyBindingsProvider.getActionDescription(action);
        final category = KeyBindingsProvider.getActionCategory(action);
        expect(desc, isNotEmpty);
        expect(category, isNotEmpty);
      }
    });

    test('getMouseActionDisplayName returns keyboard and none labels',
        () async {
      final provider = KeyBindingsProvider();
      await Future<void>.delayed(Duration.zero);

      await provider.setBinding(
        BindableAction.save,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyP),
      );
      await provider.clearBinding(BindableAction.mouseDelete);

      final keyboardName =
          provider.getMouseActionDisplayName(BindableAction.save);
      final noneName =
          provider.getMouseActionDisplayName(BindableAction.mouseDelete);

      expect(keyboardName, contains('P'));
      expect(noneName, contains('未绑定'));
    });

    test('matchesKeyboard uses keyboard state reader', () async {
      final reader = FakeKeyboardStateReader(
        isShiftPressed: true,
        logicalKeysPressed: {LogicalKeyboardKey.keyE},
      );
      final provider = KeyBindingsProvider(keyboardStateReader: reader);
      await provider.setBinding(
        BindableAction.nextLabel,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyE, shift: true),
      );

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyE,
        logicalKey: LogicalKeyboardKey.keyE,
        timeStamp: Duration.zero,
      );

      expect(provider.matchesKeyboard(BindableAction.nextLabel, event), isTrue);
    });

    test('matchesKeyboardState handles Alt-only binding', () async {
      final reader = FakeKeyboardStateReader(isAltPressed: true);
      final provider = KeyBindingsProvider(keyboardStateReader: reader);
      await provider.setBinding(
        BindableAction.cancelOperation,
        const KeyBinding.keyboard(LogicalKeyboardKey.altLeft),
      );

      expect(provider.matchesKeyboardState(BindableAction.cancelOperation),
          isTrue);
    });

    test('mouse button helpers return null for empty buttons', () {
      expect(KeyBindingsProvider.mouseButtonFromButtons(0), isNull);
      expect(KeyBindingsProvider.sideButtonFromButtons(0), isNull);
      expect(
        KeyBindingsProvider.sideButtonFromKey(LogicalKeyboardKey.keyA),
        isNull,
      );
    });

    test('load bindings handles invalid json', () async {
      await runWithFlutterErrorsSuppressed(() async {
        final store = FakeKeyBindingsStore()..value = 'invalid';
        final provider = KeyBindingsProvider(store: store);

        await Future<void>.delayed(Duration.zero);

        expect(provider.isInitialized, isTrue);
        expect(provider.error, isNotNull);
      });
    });

    test('save bindings reports error on write failure', () async {
      await runWithFlutterErrorsSuppressed(() async {
        final provider = KeyBindingsProvider(store: ThrowingKeyBindingsStore());
        await Future<void>.delayed(Duration.zero);

        await provider.setBinding(
          BindableAction.save,
          const KeyBinding.keyboard(LogicalKeyboardKey.keyP),
        );

        expect(provider.error, isNotNull);
      });
    });
  });
}
