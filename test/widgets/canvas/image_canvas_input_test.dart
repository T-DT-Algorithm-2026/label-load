import '../../helpers/canvas_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCanvas input', () {
    testWidgets('keyboard pointer create/delete respects bindings',
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
      await settingsProvider.setBoxDrawMode(BoxDrawMode.twoClick);
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );
      await keyBindingsProvider.setBinding(
        BindableAction.mouseCreate,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyA),
      );
      await keyBindingsProvider.setBinding(
        BindableAction.mouseDelete,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyD),
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
      await mouseHoverAt(tester, first);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      final second = globalFromNormalized(tester, const Offset(0.6, 0.6));
      await mouseHoverAt(tester, second);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(projectProvider.labels.length, 1);

      await mouseHoverAt(tester, second);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.pump();

      expect(projectProvider.labels, isEmpty);
    });

    testWidgets('next class cycles and resets polygon', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.purple,
          type: LabelType.polygon,
        ),
        LabelDefinition(
          classId: 1,
          name: 'box',
          color: Colors.green,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        config: AppConfig(classNames: const ['poly', 'box']),
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
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
      await mouseTapAt(
          tester, globalFromNormalized(tester, const Offset(0.2, 0.2)));
      await mouseTapAt(
          tester, globalFromNormalized(tester, const Offset(0.6, 0.2)));
      expect(canvasProvider.currentPolygonPoints.length, 2);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(canvasProvider.currentClassId, 1);
      expect(canvasProvider.currentPolygonPoints, isEmpty);
    });

    testWidgets('next class falls back to config when no definitions',
        (tester) async {
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: const [],
        config: AppConfig(classNames: const ['a', 'b', 'c']),
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
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
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(canvasProvider.currentClassId, 1);
    });

    testWidgets('handles mouse undo shortcut', (tester) async {
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
        labels: [
          Label(id: 0, x: 0.4, y: 0.4, width: 0.2, height: 0.2),
        ],
      );
      projectProvider.setUndoRedo(canUndo: true, canRedo: false);
      final canvasProvider = CanvasProvider()..setLabelingMode(false);
      canvasProvider.selectLabel(0);
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
        BindableAction.undo,
        const KeyBinding.mouse(MouseButton.left),
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
      final center = globalFromNormalized(tester, const Offset(0.4, 0.4));

      await mouseTapAt(tester, center);

      expect(projectProvider.undoCalls, greaterThanOrEqualTo(1));
      expect(canvasProvider.selectedLabelIndex, isNull);
    });

    testWidgets('edit mode create selects label under pointer', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.amber,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [
          Label(id: 0, x: 0.5, y: 0.5, width: 0.2, height: 0.2),
        ],
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
      await mouseHoverAt(
          tester, globalFromNormalized(tester, const Offset(0.5, 0.5)));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(canvasProvider.selectedLabelIndex, 0);
    });

    testWidgets('deleting polygon keypoint updates bbox', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.pink,
          type: LabelType.polygon,
        ),
      ];
      final label = Label(
        id: 0,
        points: [
          LabelPoint(x: 0.1, y: 0.1),
          LabelPoint(x: 0.5, y: 0.1),
          LabelPoint(x: 0.5, y: 0.9),
          LabelPoint(x: 0.9, y: 0.5),
        ],
      )..updateBboxFromPoints();
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
      await keyBindingsProvider.setBinding(
        BindableAction.mouseDelete,
        const KeyBinding.mouse(MouseButton.right),
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
      final deleteTarget = globalFromNormalized(tester, const Offset(0.9, 0.5));

      await mouseTapAt(
        tester,
        deleteTarget,
        buttons: kSecondaryMouseButton,
      );

      final updated = projectProvider.labels.first;
      expect(updated.points.length, 3);
      final bbox = updated.bbox;
      expect(bbox[0], closeTo(0.1, 1e-3));
      expect(bbox[1], closeTo(0.1, 1e-3));
      expect(bbox[2], closeTo(0.5, 1e-3));
      expect(bbox[3], closeTo(0.9, 1e-3));
    });

    testWidgets('blocks keyboard create when gate denies', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.blue,
          type: LabelType.polygon,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
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
        BindableAction.mouseCreate,
        const KeyBinding.keyboard(LogicalKeyboardKey.keyA),
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = BlockingInputActionGate(
        {BindableAction.mouseCreate},
      );
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
      await mouseHoverAt(
          tester, globalFromNormalized(tester, const Offset(0.3, 0.3)));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(canvasProvider.currentPolygonPoints, isEmpty);
    });

    testWidgets('handles side button create for polygon', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.deepPurple,
          type: LabelType.polygon,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
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
        BindableAction.mouseCreate,
        const KeyBinding.mouse(MouseButton.back),
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
      await mouseHoverAt(
          tester, globalFromNormalized(tester, const Offset(0.3, 0.3)));

      sideButtonService.emit(const SideButtonEvent(MouseButton.back, true));
      await tester.pump();
      sideButtonService.emit(const SideButtonEvent(MouseButton.back, false));
      await tester.pump();

      expect(canvasProvider.currentPolygonPoints.length, 1);
    });

    testWidgets('polygon tap near start closes via viewport distance',
        (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.deepOrange,
          type: LabelType.polygon,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      // Give the close-to-start check enough pixel radius for deterministic taps.
      await settingsProvider.setPointHitRadius(8);
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: FakeKeyboardStateReader(),
      );
      await keyBindingsProvider.setBinding(
        BindableAction.mouseCreate,
        const KeyBinding.mouse(MouseButton.left),
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
      await mouseTapAt(tester, start);
      await mouseTapAt(
        tester,
        globalFromNormalized(tester, const Offset(0.7, 0.2)),
      );
      await mouseTapAt(
        tester,
        globalFromNormalized(tester, const Offset(0.6, 0.6)),
      );
      expect(canvasProvider.currentPolygonPoints.length, 3);

      // Use a small pixel delta so we stay within the hit radius.
      await mouseTapAt(tester, start + const Offset(2, 2));

      expect(canvasProvider.currentPolygonPoints, isEmpty);
      expect(projectProvider.labels.length, 1);
      expect(projectProvider.labels.first.points.length, 3);
    });

    testWidgets('polygon add far point keeps drawing', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.cyan,
          type: LabelType.polygon,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
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
        BindableAction.mouseCreate,
        const KeyBinding.mouse(MouseButton.left),
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
      await mouseTapAt(
        tester,
        globalFromNormalized(tester, const Offset(0.2, 0.2)),
      );
      await mouseTapAt(
        tester,
        globalFromNormalized(tester, const Offset(0.7, 0.2)),
      );
      await mouseTapAt(
        tester,
        globalFromNormalized(tester, const Offset(0.6, 0.6)),
      );

      await mouseTapAt(
        tester,
        globalFromNormalized(tester, const Offset(0.8, 0.8)),
      );

      expect(canvasProvider.currentPolygonPoints.length, 4);
      expect(projectProvider.labels, isEmpty);
    });

    testWidgets('numeric key selects class and resets polygon (definitions)',
        (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.orange,
          type: LabelType.polygon,
        ),
        LabelDefinition(
          classId: 2,
          name: 'box',
          color: Colors.blue,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
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
      final first = globalFromNormalized(tester, const Offset(0.2, 0.2));
      final second = globalFromNormalized(tester, const Offset(0.6, 0.2));
      await mouseTapAt(tester, first);
      await mouseTapAt(tester, second);

      expect(canvasProvider.isCreatingPolygon, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
      await tester.pump();

      expect(canvasProvider.currentClassId, 2);
      expect(canvasProvider.currentPolygonPoints, isEmpty);
    });

    testWidgets('numeric key selects class from config when no definitions',
        (tester) async {
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: const [],
        config: AppConfig(classNames: const ['a', 'b', 'c']),
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
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
      final center = globalFromNormalized(tester, const Offset(0.5, 0.5));
      await tester.sendEventToBinding(
        PointerDownEvent(
          position: center,
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton,
        ),
      );
      await tester.pump();
      canvasProvider.addPolygonPoint(const Offset(0.2, 0.2));
      canvasProvider.addPolygonPoint(const Offset(0.4, 0.2));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
      await tester.pump();

      expect(canvasProvider.currentClassId, 1);
      expect(canvasProvider.currentPolygonPoints, isEmpty);
    });

    testWidgets('ignores unsupported mouse binding action', (tester) async {
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
      await keyBindingsProvider.setBinding(
        BindableAction.toggleMode,
        const KeyBinding.mouse(MouseButton.back),
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
      final center = globalFromNormalized(tester, const Offset(0.5, 0.5));

      await tester.sendEventToBinding(
        PointerDownEvent(
          position: center,
          kind: PointerDeviceKind.mouse,
          buttons: kBackMouseButton,
        ),
      );
      await tester.sendEventToBinding(
        PointerUpEvent(
          position: center,
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump();

      expect(canvasProvider.isLabelingMode, isTrue);
    });

    testWidgets('handles side button delete action', (tester) async {
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
        labels: [
          Label(id: 0, x: 0.5, y: 0.5, width: 0.2, height: 0.2),
        ],
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
        BindableAction.mouseDelete,
        const KeyBinding.mouse(MouseButton.back),
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
      final center = globalFromNormalized(tester, const Offset(0.5, 0.5));
      await mouseHoverAt(tester, center);

      sideButtonService.emit(const SideButtonEvent(MouseButton.back, true));
      await tester.pump();
      sideButtonService.emit(const SideButtonEvent(MouseButton.back, false));
      await tester.pump();

      expect(projectProvider.labels, isEmpty);
    });

    testWidgets('handles side button move action', (tester) async {
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
        const KeyBinding.mouse(MouseButton.back),
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
      await mouseHoverAt(
          tester, globalFromNormalized(tester, const Offset(0.4, 0.4)));

      sideButtonService.emit(const SideButtonEvent(MouseButton.back, true));
      await tester.pump();
      sideButtonService.emit(const SideButtonEvent(MouseButton.back, false));
      await tester.pump();

      expect(canvasProvider.interactionMode, InteractionMode.none);
    });

    testWidgets('requests focus on pointer down', (tester) async {
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
      final focusWidget = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(ImageCanvas),
              matching: find.byType(Focus),
            )
            .first,
      );
      final focusNode = focusWidget.focusNode!;
      focusNode.unfocus();
      await tester.pump();

      final center = globalFromNormalized(tester, const Offset(0.5, 0.5));
      await tester.sendEventToBinding(
        PointerDownEvent(
          position: center,
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton,
        ),
      );
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('handles side button non-pointer action', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'a',
          color: Colors.red,
          type: LabelType.box,
        ),
        LabelDefinition(
          classId: 1,
          name: 'b',
          color: Colors.green,
          type: LabelType.box,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
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
        BindableAction.nextClass,
        const KeyBinding.mouse(MouseButton.forward),
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
      sideButtonService.emit(const SideButtonEvent(MouseButton.forward, true));
      await tester.pump();

      expect(canvasProvider.currentClassId, 1);
    });

    testWidgets('cycle binding iterates candidates', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'pose',
          color: Colors.orange,
          type: LabelType.boxWithPoint,
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
        x: 0.5,
        y: 0.5,
        width: 0.4,
        height: 0.4,
        points: [LabelPoint(x: 0.45, y: 0.45)],
      );
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [labelA, labelB],
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
      canvasProvider.selectLabel(0);
      canvasProvider.setActiveKeypoint(0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.backquote);
      await tester.pump();

      expect(canvasProvider.isBindingKeypoint, isTrue);
      expect(canvasProvider.currentBindingCandidate, isNotNull);
    });

    testWidgets('cycle binding clears when only one candidate', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'pose',
          color: Colors.orange,
          type: LabelType.boxWithPoint,
        ),
      ];
      final label = Label(
        id: 0,
        x: 0.4,
        y: 0.4,
        width: 0.3,
        height: 0.3,
        points: [LabelPoint(x: 0.4, y: 0.4)],
      );
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
      canvasProvider.selectLabel(0);
      canvasProvider.setActiveKeypoint(0);
      canvasProvider.setBindingCandidates([0]);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.backquote);
      await tester.pump();

      expect(canvasProvider.isBindingKeypoint, isFalse);
    });
  });
}
