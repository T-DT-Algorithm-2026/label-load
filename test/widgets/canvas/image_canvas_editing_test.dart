import '../../helpers/canvas_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCanvas editing', () {
    testWidgets('supports edit mode move, resize, keypoint delete',
        (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.purple,
          type: LabelType.box,
        ),
      ];
      final movableLabel = Label(
        id: 0,
        x: 0.3,
        y: 0.3,
        width: 0.2,
        height: 0.2,
      );
      final keypointLabel = Label(
        id: 0,
        x: 0.7,
        y: 0.7,
        width: 0.2,
        height: 0.2,
        points: [LabelPoint(x: 0.7, y: 0.7)],
      );
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [movableLabel, keypointLabel],
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
      final center = globalFromNormalized(tester, const Offset(0.3, 0.3));

      await mouseTapAt(tester, center);
      canvasProvider.selectLabel(0);

      await mouseDrag(tester, center, center + const Offset(80, 0));
      expect(projectProvider.labels[0].x, greaterThan(0.3));

      final updated = projectProvider.labels[0];
      final bbox = updated.bbox;
      final handle = globalFromNormalized(tester, Offset(bbox[0], bbox[1]));
      await mouseDrag(
        tester,
        handle,
        handle + const Offset(-40, -40),
      );

      expect(projectProvider.labels[0].width, greaterThan(0.2));

      final movedPoint = projectProvider.labels[1].points.first;
      final keypoint = globalFromNormalized(
        tester,
        Offset(movedPoint.x, movedPoint.y),
      );
      await mouseTapAt(tester, keypoint, buttons: kSecondaryMouseButton);

      expect(projectProvider.labels[1].points.length, 0);
    });

    testWidgets('deletes label on right click in edit mode', (tester) async {
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
      final center = globalFromNormalized(tester, const Offset(0.4, 0.4));

      await mouseTapAt(tester, center, buttons: kSecondaryMouseButton);

      expect(projectProvider.labels, isEmpty);
      expect(canvasProvider.selectedLabelIndex, isNull);
    });

    testWidgets('removes polygon when vertex deletion drops below 3',
        (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.green,
          type: LabelType.polygon,
        ),
      ];
      final polygon = Label(
        id: 0,
        points: [
          LabelPoint(x: 0.2, y: 0.2),
          LabelPoint(x: 0.8, y: 0.2),
          LabelPoint(x: 0.8, y: 0.8),
        ],
      )..updateBboxFromPoints();
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [polygon],
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
      final vertex = globalFromNormalized(tester, const Offset(0.2, 0.2));

      await mouseTapAt(tester, vertex, buttons: kSecondaryMouseButton);

      expect(projectProvider.labels, isEmpty);
    });

    testWidgets('adds keypoint to nearest candidate and avoids duplicate',
        (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'pose',
          color: Colors.orange,
          type: LabelType.boxWithPoint,
        ),
      ];
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [
          Label(id: 0, x: 0.3, y: 0.3, width: 0.2, height: 0.2),
          Label(id: 0, x: 0.8, y: 0.8, width: 0.1, height: 0.1),
        ],
      );
      final canvasProvider = CanvasProvider()
        ..setLabelingMode(true)
        ..setCurrentClassId(0);
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
      final inside = globalFromNormalized(tester, const Offset(0.3, 0.3));

      await mouseTapAt(tester, inside);

      expect(projectProvider.labels[0].points.length, 1);
      expect(projectProvider.labels[1].points, isEmpty);
      expect(canvasProvider.isBindingKeypoint, isTrue);
      expect(canvasProvider.currentBindingCandidate, 0);
      expect(canvasProvider.activeKeypointIndex, 0);

      await mouseTapAt(tester, inside);
      expect(projectProvider.labels[0].points.length, 1);
    });

    testWidgets('cancel clears selection in edit mode', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.redAccent,
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
      final center = globalFromNormalized(tester, const Offset(0.4, 0.4));

      await mouseTapAt(tester, center);
      expect(canvasProvider.selectedLabelIndex, 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(canvasProvider.selectedLabelIndex, isNull);
    });

    testWidgets('keeps polygon points when ctrl not pressed', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.deepOrange,
          type: LabelType.polygon,
        ),
      ];
      final polygon = Label(
        id: 0,
        points: [
          LabelPoint(x: 0.2, y: 0.2),
          LabelPoint(x: 0.6, y: 0.2),
          LabelPoint(x: 0.6, y: 0.6),
        ],
      )..updateBboxFromPoints();
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [polygon],
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
      final services = buildServices(
        sideButtonService: sideButtonService,
        inputActionGate: inputActionGate,
        keyboardStateReader: FakeKeyboardStateReader(),
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
          keyboardStateReader: FakeKeyboardStateReader(),
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await waitForCanvasReady(tester);

      final center = globalFromNormalized(tester, const Offset(0.4, 0.3));
      await mouseTapAt(tester, center);

      final before = projectProvider.labels.first.points.first.x;
      await mouseDrag(tester, center, center + const Offset(50, 0));

      expect(projectProvider.labels.first.points.first.x, before);
    });

    testWidgets('moves polygon keypoint in edit mode', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.lightBlue,
          type: LabelType.polygon,
        ),
      ];
      final polygon = Label(
        id: 0,
        points: [
          LabelPoint(x: 0.2, y: 0.3),
          LabelPoint(x: 0.7, y: 0.2),
          LabelPoint(x: 0.6, y: 0.7),
        ],
      )..updateBboxFromPoints();
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [polygon],
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(false);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      await settingsProvider.setPointHitRadius(60);
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
      final beforePoint = projectProvider.labels.first.points.first;
      final beforeX = beforePoint.x;
      final beforeY = beforePoint.y;
      final beforeBbox = List<double>.from(projectProvider.labels.first.bbox);

      canvasProvider.selectLabel(0);
      canvasProvider.setActiveKeypoint(0);
      final state = tester.state(find.byType(ImageCanvas));
      (state as dynamic).debugMoveKeypoint(
        const Offset(0.1, 0.1),
        canvasProvider,
        projectProvider,
      );
      await tester.pump();

      final movedLabel = projectProvider.labels.first;
      expect(movedLabel.points.first.x, lessThan(beforeX));
      expect(movedLabel.points.first.y, lessThan(beforeY));
      expect(movedLabel.bbox[0], lessThan(beforeBbox[0]));
      expect(movedLabel.bbox[1], lessThan(beforeBbox[1]));
    });

    testWidgets('moves box and keypoints when ctrl pressed', (tester) async {
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
        width: 0.2,
        height: 0.2,
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
      final keyboardStateReader = ConfigurableKeyboardStateReader(
        controlPressed: true,
      );
      final keyBindingsProvider = KeyBindingsProvider(
        store: FakeKeyBindingsStore(),
        keyboardStateReader: keyboardStateReader,
      );

      final sideButtonService = FakeSideButtonService();
      addTearDown(sideButtonService.dispose);
      final inputActionGate = FakeInputActionGate();
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
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final start = globalFromNormalized(tester, const Offset(0.4, 0.4));
      final end = globalFromNormalized(tester, const Offset(0.6, 0.4));
      canvasProvider.selectLabel(0);
      canvasProvider.startInteraction(
        InteractionMode.moving,
        const Offset(0.4, 0.4),
      );
      await mouseDrag(tester, start, end);

      expect(projectProvider.labels[0].x, greaterThan(0.4));
      expect(projectProvider.labels[0].points.first.x, greaterThan(0.4));
    });

    testWidgets('parent-only polygon move keeps points', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.deepOrange,
          type: LabelType.polygon,
        ),
      ];
      final polygon = Label(
        id: 0,
        points: [
          LabelPoint(x: 0.2, y: 0.2),
          LabelPoint(x: 0.6, y: 0.2),
          LabelPoint(x: 0.6, y: 0.6),
        ],
      )..updateBboxFromPoints();
      final projectProvider = TestProjectProvider(
        imagePath: '/tmp/image.png',
        definitions: definitions,
        labels: [polygon],
      );
      final canvasProvider = CanvasProvider()..setLabelingMode(false);
      final settingsProvider = SettingsProvider(
        store: FakeSettingsStore(),
        gpuDetector: FakeGpuDetector(),
        autoLoad: false,
      );
      await settingsProvider.setPointHitRadius(4);
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
      final center = globalFromNormalized(tester, const Offset(0.4, 0.3));
      canvasProvider.selectLabel(0);
      canvasProvider.startInteraction(
        InteractionMode.moving,
        const Offset(0.4, 0.3),
      );

      final before = projectProvider.labels.first.points.first.x;
      await mouseDrag(tester, center, center + const Offset(50, 0));

      expect(projectProvider.labels.first.points.first.x, before);
    });

    testWidgets('manual resize uses start rect when missing', (tester) async {
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: Colors.blueGrey,
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
      canvasProvider.selectLabel(0);
      canvasProvider.setActiveHandle(0);
      canvasProvider.startInteraction(
        InteractionMode.resizing,
        const Offset(0.4, 0.4),
      );

      final handle = globalFromNormalized(tester, const Offset(0.4, 0.4));
      await mouseDrag(
        tester,
        handle,
        handle + const Offset(-40, -40),
      );

      expect(projectProvider.labels.first.width, greaterThan(0.2));
    });
  });
}
