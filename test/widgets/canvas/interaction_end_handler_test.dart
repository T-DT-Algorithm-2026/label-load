import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/services/inference/project_inference_controller.dart';
import 'package:label_load/widgets/canvas/interaction_end_handler.dart';

class FakeInferenceRunner implements InferenceRunner {
  @override
  bool get hasModel => false;

  @override
  String? get loadedModelPath => null;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async => true;

  @override
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    return <Label>[];
  }
}

class TestProjectProvider extends ProjectProvider {
  int notifyCalls = 0;

  TestProjectProvider()
      : super(
          inferenceController:
              ProjectInferenceController(runner: FakeInferenceRunner()),
        );

  @override
  void notifyLabelChange() {
    notifyCalls += 1;
    super.notifyLabelChange();
  }
}

void main() {
  group('InteractionEndHandler', () {
    test('adds label and selects it when drawing ends with a valid rect', () {
      final canvasProvider = CanvasProvider()..setLabelingMode(true);
      final projectProvider = TestProjectProvider();
      projectProvider.config.classNames = ['cls0'];

      canvasProvider.startDrawing(const Offset(0.1, 0.1));
      canvasProvider.updateDrag(const Offset(0.4, 0.5));

      bool finished = false;
      InteractionEndHandler(
        canvasProvider: canvasProvider,
        projectProvider: projectProvider,
        onFinish: () => finished = true,
      ).run();

      expect(projectProvider.labels.length, 1);
      expect(projectProvider.labels.first.name, 'cls0');
      expect(canvasProvider.selectedLabelIndex, 0);
      expect(projectProvider.notifyCalls, 0);
      expect(finished, isTrue);
    });

    test('notifies label change when moving/resizing/keypoint interaction ends',
        () {
      for (final mode in [
        InteractionMode.moving,
        InteractionMode.resizing,
        InteractionMode.movingKeypoint,
      ]) {
        final canvasProvider = CanvasProvider()..setLabelingMode(false);
        final projectProvider = TestProjectProvider();
        canvasProvider.startInteraction(mode, const Offset(0.2, 0.2));

        InteractionEndHandler(
          canvasProvider: canvasProvider,
          projectProvider: projectProvider,
          onFinish: () {},
        ).run();

        expect(projectProvider.notifyCalls, 1);
        expect(projectProvider.labels, isEmpty);
      }
    });
  });
}
