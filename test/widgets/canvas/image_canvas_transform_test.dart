import '../../helpers/canvas_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCanvas transform', () {
    testWidgets('pans when middle button moves inside image', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.blueGrey,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(false);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
      final keyboardStateReader = FakeKeyboardStateReader();
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: keyboardStateReader,
      );
      final imageRepository = FakeImageRepository(testPngBytes);

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: imageRepository,
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);
      final viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      final controller = viewer.transformationController!;
      final beforeTx = controller.value.entry(0, 3);
      final beforeTy = controller.value.entry(1, 3);
      final center = globalFromNormalized(tester, const Offset(0.4, 0.4));

      await mouseDrag(
        tester,
        center,
        center + const Offset(-40, -20),
        buttons: kMiddleMouseButton,
      );

      final afterTx = controller.value.entry(0, 3);
      final afterTy = controller.value.entry(1, 3);
      expect(afterTx != beforeTx || afterTy != beforeTy, isTrue);
    });

    testWidgets('clamps transform and pans outside image', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.teal,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(false);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
      final keyboardStateReader = FakeKeyboardStateReader();
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: keyboardStateReader,
      );
      final imageRepository = FakeImageRepository(testPngBytes);

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: imageRepository,
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);
      final viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      final controller = viewer.transformationController!;
      controller.value = Matrix4.identity()
        ..scale(0.1, 0.1)
        ..setEntry(0, 3, 10000)
        ..setEntry(1, 3, 10000);
      await tester.pump();

      final viewerRect = tester.getRect(find.byType(InteractiveViewer));
      final scale = controller.value.entry(0, 0);
      final scaledW = testImageSize.width * scale;
      final scaledH = testImageSize.height * scale;
      final marginX = viewerRect.width / 2;
      final marginY = viewerRect.height / 2;
      final minTx = marginX - scaledW;
      final maxTx = marginX;
      final minTy = marginY - scaledH;
      final maxTy = marginY;

      final tx = controller.value.entry(0, 3);
      final ty = controller.value.entry(1, 3);
      expect(tx, inInclusiveRange(minTx, maxTx));
      expect(ty, inInclusiveRange(minTy, maxTy));

      final imageTopLeft = Offset(viewerRect.left + tx, viewerRect.top + ty);
      final outside = imageTopLeft - const Offset(5, 5);
      final drag = await tester.startGesture(
        outside,
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await tester.pump();
      await drag.moveBy(const Offset(-30, -20));
      await tester.pump();
      await drag.up();
      await tester.pump();

      final txAfter = controller.value.entry(0, 3);
      final tyAfter = controller.value.entry(1, 3);
      expect(txAfter != tx || tyAfter != ty, isTrue);
    });

    testWidgets('handles auto-pan and keyboard cycle binding', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.teal,
          type: LabelType.box,
        ),
      ];
      final labelA = Label(
        id: 0,
        x: 0.4,
        y: 0.4,
        width: 0.3,
        height: 0.3,
        points: [LabelPoint(x: 0.4, y: 0.4)],
      );
      final labelB = Label(
        id: 0,
        x: 0.6,
        y: 0.6,
        width: 0.3,
        height: 0.3,
        points: [LabelPoint(x: 0.6, y: 0.6)],
      );
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [labelA, labelB],
        config: AppConfig(classNames: const ['box']),
      );
      projectProvider.setUndoRedo(canUndo: true, canRedo: true);

      final canvasProvider = CanvasProvider()..setLabelingMode(false);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );
      await keyBindingsProvider.setBinding(
        BindableAction.cycleBinding,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyB),
      );
      await keyBindingsProvider.setBinding(
        BindableAction.undo,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyU),
      );
      await keyBindingsProvider.setBinding(
        BindableAction.redo,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyR),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
      final keyboardStateReader = FakeKeyboardStateReader();
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: keyboardStateReader,
      );
      final imageRepository = FakeImageRepository(testPngBytes);

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: imageRepository,
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);

      final viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      viewer.transformationController!.value = Matrix4.identity()
        ..scale(2.0, 2.0);
      await tester.pump();

      final start = globalFromNormalized(tester, const Offset(0.4, 0.4));
      final viewerRect = tester.getRect(find.byType(InteractiveViewer));
      final edge = Offset(viewerRect.left + 1, viewerRect.center.dy);

      final drag = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await tester.pump();
      await drag.moveTo(edge);
      await tester.pump(const Duration(milliseconds: 200));
      await drag.up();
      await tester.pump();

      canvasProvider.selectLabel(0);
      canvasProvider.setActiveKeypoint(0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.pump();

      expect(projectProvider.labels[0].points, isEmpty);
      expect(projectProvider.labels[1].points.length, 2);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyR);
      await tester.pump();

      expect(projectProvider.undoCalls, 1);
      expect(projectProvider.redoCalls, 1);
    });

    testWidgets('overlay pointer cancel and hover outside image',
        (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.green,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(false);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
      final keyboardStateReader = FakeKeyboardStateReader();
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: keyboardStateReader,
      );
      final imageRepository = FakeImageRepository(testPngBytes);

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: imageRepository,
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);
      final outside = globalFromNormalized(tester, const Offset(1.2, 0.2));

      await tester.sendEventToBinding(
        PointerDownEvent(
          position: outside,
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton,
        ),
      );
      await tester.sendEventToBinding(
        PointerMoveEvent(
          position: outside + const Offset(-5, -5),
          kind: PointerDeviceKind.mouse,
          delta: const Offset(-5, -5),
          buttons: kPrimaryMouseButton,
        ),
      );
      await tester.sendEventToBinding(
        PointerCancelEvent(
          position: outside + const Offset(-5, -5),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await mouseHoverAt(tester, outside);

      expect(canvasProvider.interactionMode, InteractionMode.none);
    });

    testWidgets('keyboard pointer move pans on hover', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.teal,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(false);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );
      await keyBindingsProvider.setBinding(
        BindableAction.mouseMove,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyM),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
      final keyboardStateReader = FakeKeyboardStateReader();
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: keyboardStateReader,
      );
      final imageRepository = FakeImageRepository(testPngBytes);

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: imageRepository,
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyM);
      await tester.pump();

      final viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      final controller = viewer.transformationController!;
      final beforeTx = controller.value.entry(0, 3);
      final center = globalFromNormalized(tester, const Offset(0.5, 0.5));

      await tester.sendEventToBinding(
        PointerHoverEvent(
          position: center + const Offset(20, 0),
          kind: PointerDeviceKind.mouse,
          delta: const Offset(20, 0),
        ),
      );
      await tester.pump();

      final afterTx = controller.value.entry(0, 3);
      expect(afterTx, isNot(equals(beforeTx)));
    });

    testWidgets('keyboard create drag uses anchor inside image',
        (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.indigo,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(true);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      await settingsProvider.setBoxDrawMode(BoxDrawMode.drag);
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );
      await keyBindingsProvider.setBinding(
        BindableAction.mouseCreate,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyA),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
      final keyboardStateReader = FakeKeyboardStateReader();
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: keyboardStateReader,
      );
      final imageRepository = FakeImageRepository(testPngBytes);

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: imageRepository,
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);
      final outside = globalFromNormalized(tester, const Offset(1.2, 0.2));
      await mouseHoverAt(tester, outside);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      final inside = globalFromNormalized(tester, const Offset(0.3, 0.3));
      await tester.sendEventToBinding(
        PointerHoverEvent(
          position: inside,
          kind: PointerDeviceKind.mouse,
          delta: const Offset(5, 0),
        ),
      );
      await tester.sendEventToBinding(
        PointerMoveEvent(
          position: inside + const Offset(5, 0),
          kind: PointerDeviceKind.mouse,
          delta: const Offset(5, 0),
          buttons: kPrimaryMouseButton,
        ),
      );
      await tester.pump();

      expect(canvasProvider.interactionMode, isNot(InteractionMode.none));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
    });

    testWidgets('ignores pointer move outside image in labeling mode',
        (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.red,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(true);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
      final keyboardStateReader = FakeKeyboardStateReader();
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: keyboardStateReader,
      );
      final imageRepository = FakeImageRepository(testPngBytes);

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: imageRepository,
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);
      final outside = globalFromNormalized(tester, const Offset(1.2, 1.2));

      await tester.sendEventToBinding(
        PointerMoveEvent(
          position: outside,
          kind: PointerDeviceKind.mouse,
          delta: const Offset(5, 5),
          buttons: 0,
        ),
      );
      await tester.pump();

      expect(canvasProvider.interactionMode, InteractionMode.none);
    });

    testWidgets('auto-pans near edges while moving', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.blue,
          type: LabelType.box,
        ),
      ];
      final label = Label(id: 0, x: 0.5, y: 0.5, width: 0.2, height: 0.2);
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [label],
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(false);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
      final keyboardStateReader = FakeKeyboardStateReader();
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: keyboardStateReader,
      );
      final imageRepository = FakeImageRepository(testPngBytes);

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: imageRepository,
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);

      final viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      viewer.transformationController!.value = Matrix4.identity()
        ..scale(6.0, 6.0);
      await tester.pump();

      final viewerRect = tester.getRect(find.byType(InteractiveViewer));
      final leftEdge = Offset(viewerRect.left + 5, viewerRect.top + 5);
      final rightEdge = Offset(viewerRect.right - 5, viewerRect.bottom - 5);
      final center = viewerRect.center;

      canvasProvider.selectLabel(0);
      canvasProvider.startInteraction(
        InteractionMode.moving,
        const Offset(0.5, 0.5),
      );

      final controller = viewer.transformationController!;
      final beforeTx = controller.value.entry(0, 3);

      final gesture = await tester.startGesture(
        leftEdge,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await tester.pump();
      await gesture.moveTo(leftEdge + const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 80));
      final leftTx = controller.value.entry(0, 3);
      await gesture.moveTo(rightEdge);
      await tester.pump(const Duration(milliseconds: 200));
      final rightTx = controller.value.entry(0, 3);
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.up();
      await tester.pump();

      expect(leftTx != beforeTx || rightTx != beforeTx, isTrue);
    });

    testWidgets('auto-pan updates draw drag', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.purple,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(true);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      await settingsProvider.setBoxDrawMode(BoxDrawMode.drag);
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
      final keyboardStateReader = FakeKeyboardStateReader();
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: keyboardStateReader,
      );
      final imageRepository = FakeImageRepository(testPngBytes);

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: imageRepository,
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);

      final viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      viewer.transformationController!.value = Matrix4.identity()
        ..scale(6.0, 6.0);
      await tester.pump();

      final viewerRect = tester.getRect(find.byType(InteractiveViewer));
      final edge = Offset(viewerRect.left + 5, viewerRect.center.dy);
      canvasProvider.tryStartDrawing(const Offset(0.2, 0.2));
      canvasProvider.updateDrag(const Offset(0.25, 0.25));
      expect(canvasProvider.drawStart, isNotNull);

      final gesture = await tester.startGesture(
        edge,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await tester.pump();

      canvasProvider.cancelInteraction();
      expect(canvasProvider.drawStart, isNull);
    });
  });
}
