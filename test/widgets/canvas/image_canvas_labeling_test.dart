import '../../helpers/canvas_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCanvas labeling', () {
    testWidgets('shows empty state when no image path', (tester) async {
      final projectProvider = TestProjectProvider(
        imagePath: null,
        definitions: const [],
      );
      final canvasProvider = CanvasProvider();
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      await settingsProvider.setBoxDrawMode(BoxDrawMode.drag);
      await settingsProvider.setPointHitRadius(10);
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

      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: FakeImageRepository(testPngBytes),
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('creates box label on drag', (tester) async {
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

      final start = globalFromNormalized(tester, const Offset(0.2, 0.2));
      final end = globalFromNormalized(tester, const Offset(0.8, 0.6));
      await mouseDrag(tester, start, end);
      await tester.pump();

      expect(projectProvider.labels, hasLength(1));
      expect(projectProvider.labels.first.id, 0);
    });

    testWidgets('supports two-click box and keypoint binding', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'pose',
          color: Colors.blue,
          type: LabelType.boxWithPoint,
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
      await settingsProvider.setBoxDrawMode(BoxDrawMode.twoClick);
      await settingsProvider.setPointHitRadius(10);
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

      final topLeft = globalFromNormalized(tester, const Offset(0.2, 0.2));
      final bottomRight = globalFromNormalized(tester, const Offset(0.6, 0.6));
      await mouseTapAt(tester, topLeft);
      await mouseTapAt(tester, bottomRight);
      await tester.pump();

      expect(projectProvider.labels, hasLength(1));
      expect(projectProvider.labels.first.id, 0);

      await settingsProvider.setBoxDrawMode(BoxDrawMode.drag);
      await tester.pump();
      final keypointPos = globalFromNormalized(tester, const Offset(0.3, 0.3));
      await mouseTapAt(tester, keypointPos);
      await tester.pump();

      expect(projectProvider.labels.first.points, hasLength(1));
    });

    testWidgets('ignores polygon point when too close', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.orange,
          type: LabelType.polygon,
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

      final viewerRect = tester.getRect(find.byType(InteractiveViewer));
      final p1 = viewerRect.center + const Offset(-30, -30);
      final p2 = p1 + const Offset(1, 1);
      await mouseTapAt(tester, p1);
      await mouseTapAt(tester, p2);

      expect(canvasProvider.currentPolygonPoints, hasLength(1));
    });

    testWidgets('finalizes polygon on delete click', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.orange,
          type: LabelType.polygon,
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

      final viewerRect = tester.getRect(find.byType(InteractiveViewer));
      final p1 = viewerRect.center + const Offset(-40, -40);
      final p2 = viewerRect.center + const Offset(40, -40);
      final p3 = viewerRect.center + const Offset(0, 40);
      await mouseTapAt(tester, p1);
      await mouseTapAt(tester, p2);
      await mouseTapAt(tester, p3);
      await mouseTapAt(tester, p3, buttons: kSecondaryMouseButton);

      expect(projectProvider.labels, hasLength(1));
      expect(canvasProvider.isCreatingPolygon, isFalse);
    });

    testWidgets('cancel clears polygon on escape', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.orange,
          type: LabelType.polygon,
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

      final p1 = globalFromNormalized(tester, const Offset(0.2, 0.2));
      final p2 = globalFromNormalized(tester, const Offset(0.6, 0.2));
      await mouseTapAt(tester, p1);
      await mouseTapAt(tester, p2);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(canvasProvider.isCreatingPolygon, isFalse);
      expect(canvasProvider.currentPolygonPoints, isEmpty);
    });

    testWidgets('cancel clears two-click anchor on escape', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.blue,
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
      await settingsProvider.setBoxDrawMode(BoxDrawMode.twoClick);
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

      final first = globalFromNormalized(tester, const Offset(0.2, 0.2));
      await mouseTapAt(tester, first);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(canvasProvider.drawStart, isNull);
    });

    testWidgets('supports two-click create with non-primary button',
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
      await settingsProvider.setBoxDrawMode(BoxDrawMode.twoClick);
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );
      await keyBindingsProvider.setBinding(
        BindableAction.mouseCreate,
        const KeyBinding.mouse(MouseButton.middle),
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

      expect(
        keyBindingsProvider.getPointerButton(BindableAction.mouseCreate),
        kMiddleMouseButton,
      );

      final viewerRect = tester.getRect(find.byType(InteractiveViewer));
      final start = viewerRect.center + const Offset(-40, -40);
      final end = viewerRect.center + const Offset(40, 40);
      await mouseTapAt(tester, start, buttons: kMiddleMouseButton);
      await mouseTapAt(tester, end, buttons: kMiddleMouseButton);
      await tester.pump();

      expect(projectProvider.labels, hasLength(1));
    });

    testWidgets('cancels manual create drag on pointer cancel', (tester) async {
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

      final start = globalFromNormalized(tester, const Offset(0.2, 0.2));
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(canvasProvider.isDrawing, isFalse);
    });
  });
}
