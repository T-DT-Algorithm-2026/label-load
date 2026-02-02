import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/widgets/dialogs/keybindings_dialog.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('KeyBindingsDialog binds keyboard input and clears',
      (tester) async {
    await setLargeSurface(tester, size: const Size(1200, 1600));
    final l10n = await loadL10n(const Locale('zh'));

    final keyboard = FakeKeyboardStateReader(isControlPressed: true);
    final provider = KeyBindingsProvider(
      store: FakeKeyBindingsStore(),
      keyboardStateReader: keyboard,
    );
    final services = buildAppServices(keyboardStateReader: keyboard);

    await tester.pumpWidget(buildDialogTestApp(
      child: const KeyBindingsDialog(),
      locale: const Locale('zh'),
      textScaleFactor: 0.85,
      services: services,
      providers: [ChangeNotifierProvider.value(value: provider)],
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(l10n.actionSave));
    await tester.tap(find.text(l10n.actionSave));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.capsLock);
    await tester.pump();
    expect(find.text(l10n.pressKeyOrMouseButton), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();

    final saveBinding = provider.getBinding(BindableAction.save);
    expect(saveBinding.key, LogicalKeyboardKey.keyK);
    expect(saveBinding.ctrl, isTrue);

    final saveRow = find.ancestor(
      of: find.text(l10n.actionSave),
      matching: find.byType(InkWell),
    );
    final clearButton = find.descendant(
      of: saveRow,
      matching: find.byTooltip(l10n.clearBinding),
    );
    await tester.tap(clearButton);
    await tester.pump();

    expect(provider.getBinding(BindableAction.save).isNone, isTrue);
  });

  testWidgets('KeyBindingsDialog handles mouse, scroll, and side buttons',
      (tester) async {
    await setLargeSurface(tester, size: const Size(1200, 1600));
    final l10n = await loadL10n(const Locale('zh'));

    final keyboard = FakeKeyboardStateReader();
    final provider = KeyBindingsProvider(
      store: FakeKeyBindingsStore(),
      keyboardStateReader: keyboard,
    );
    final services = buildAppServices(keyboardStateReader: keyboard);

    await tester.pumpWidget(buildDialogTestApp(
      child: const KeyBindingsDialog(),
      locale: const Locale('zh'),
      textScaleFactor: 0.85,
      services: services,
      providers: [ChangeNotifierProvider.value(value: provider)],
    ));
    await tester.pumpAndSettle();

    // Act: bind mouse create, scroll zoom, then side button.
    await tester.ensureVisible(find.text(l10n.actionMouseCreate));
    await tester.tap(find.text(l10n.actionMouseCreate));
    await tester.pump();
    final position = tester.getCenter(find.byType(Dialog));
    tester.binding.handlePointerEvent(
      PointerDownEvent(position: position, buttons: kPrimaryButton, pointer: 1),
    );
    tester.binding.handlePointerEvent(
      PointerUpEvent(position: position, pointer: 1),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final mouseBinding = provider.getBinding(BindableAction.mouseCreate);
    expect(mouseBinding.mouseButton, MouseButton.left);

    await tester.ensureVisible(find.text(l10n.actionZoomIn));
    await tester.tap(find.text(l10n.actionZoomIn));
    await tester.pump();
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: position,
        scrollDelta: const Offset(0, -20),
      ),
    );
    await tester.pump();
    final scrollBinding = provider.getBinding(BindableAction.zoomIn);
    expect(scrollBinding.scrollAction, ScrollActionType.scrollUp);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text(l10n.actionMouseMove));
    await tester.tap(find.text(l10n.actionMouseMove));
    await tester.pump();
    await sendSideButtonEvent(button: MouseButton.back, isDown: true);
    await tester.pump();
    final sideBinding = provider.getBinding(BindableAction.mouseMove);
    expect(sideBinding.isMouse, isTrue);
  });

  testWidgets('KeyBindingsDialog resets to defaults', (tester) async {
    await setLargeSurface(tester, size: const Size(1200, 1600));
    final l10n = await loadL10n(const Locale('zh'));

    final keyboard = FakeKeyboardStateReader();
    final provider = KeyBindingsProvider(
      store: FakeKeyBindingsStore(),
      keyboardStateReader: keyboard,
    );
    final services = buildAppServices(keyboardStateReader: keyboard);

    await provider.setBinding(
      BindableAction.save,
      const KeyBinding.keyboard(LogicalKeyboardKey.keyZ),
    );

    await tester.pumpWidget(buildDialogTestApp(
      child: const KeyBindingsDialog(),
      locale: const Locale('zh'),
      textScaleFactor: 0.85,
      services: services,
      providers: [ChangeNotifierProvider.value(value: provider)],
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(l10n.resetToDefault));
    await tester.tap(find.text(l10n.resetToDefault));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.reset));
    await tester.pumpAndSettle();

    final binding = provider.getBinding(BindableAction.save);
    expect(binding.key, LogicalKeyboardKey.keyS);
  });
}
