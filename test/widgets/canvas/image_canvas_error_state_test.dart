import '../../helpers/canvas_test_harness.dart';

class ThrowingImageRepository implements ImageRepository {
  @override
  Future<List<String>> listImagePaths(String directoryPath) async => [];

  @override
  Future<bool> exists(String path) async => true;

  @override
  Future<Uint8List> readBytes(String path) async {
    throw Exception('decode failed');
  }

  @override
  Future<void> deleteIfExists(String path) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ImageCanvas shows error state when image load fails',
      (tester) async {
    final projectProvider = TestProjectProvider(
      imagePath: '/tmp/fail.png',
      definitions: const [],
    );
    final canvasProvider = CanvasProvider();
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

    await runWithFlutterErrorsCaptured((errors) async {
      await tester.pumpWidget(
        buildTestApp(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          keyBindingsProvider: keyBindingsProvider,
          imageRepository: ThrowingImageRepository(),
          inputActionGate: inputActionGate,
          keyboardStateReader: keyboardStateReader,
          sideButtonService: sideButtonService,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byKey(const Key('imageCanvasError')), findsOneWidget);
      expect(errors, isNotEmpty);
    });
  });
}
