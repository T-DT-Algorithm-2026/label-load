import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/services/inference/project_inference_controller.dart';
import 'package:label_load/widgets/canvas/canvas_helpers.dart';
import 'package:label_load/widgets/canvas/edit_mode_drag_start_handler.dart';

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
  TestProjectProvider({
    List<Label>? labels,
    List<LabelDefinition>? definitions,
  })  : _labels = labels ?? <Label>[],
        _definitions = definitions ?? <LabelDefinition>[],
        super(
          inferenceController:
              ProjectInferenceController(runner: FakeInferenceRunner()),
        );

  final List<Label> _labels;
  final List<LabelDefinition> _definitions;
  int historyCalls = 0;

  @override
  void addToHistory() {
    historyCalls += 1;
  }

  @override
  List<Label> get labels => _labels;

  @override
  List<LabelDefinition> get labelDefinitions => _definitions;

  @override
  LabelDefinition? getLabelDefinition(int classId) {
    return _definitions.findByClassId(classId);
  }

  @override
  void updateLabel(int index, Label label,
      {bool addToHistory = true, bool notify = true}) {
    _labels[index] = label;
  }
}

void main() {
  group('EditModeDragStartHandler', () {
    test('starts resize when handle is hit', () {
      final canvasProvider = CanvasProvider()..selectLabel(0);
      final projectProvider = TestProjectProvider(
        definitions: [
          LabelDefinition(classId: 0, name: 'box', color: Colors.red),
        ],
        labels: [
          Label(id: 0, x: 0.5, y: 0.5, width: 0.2, height: 0.2),
        ],
      );
      Rect? resizeRect;

      final handler = EditModeDragStartHandler(
        canvasProvider: canvasProvider,
        projectProvider: projectProvider,
        labels: projectProvider.labels,
        definitions: projectProvider.labelDefinitions,
        imageSize: const Size(100, 100),
        normalized: const Offset(0.5, 0.5),
        localPos: const Offset(50, 50),
        findKeypointAt: (_) => null,
        findHandleAt: (_, __) => 0,
        findEdgeAt: (_, __) => null,
        findLabelAt: (_) => null,
        setResizeStartRect: (rect) => resizeRect = rect,
      );

      handler.run();

      expect(canvasProvider.interactionMode, InteractionMode.resizing);
      expect(canvasProvider.activeHandle, 0);
      expect(projectProvider.historyCalls, 1);
      expect(resizeRect, isNotNull);
    });

    test('starts keypoint move when keypoint is hit', () {
      final canvasProvider = CanvasProvider();
      final projectProvider = TestProjectProvider(
        definitions: [
          LabelDefinition(classId: 0, name: 'pose', color: Colors.blue),
        ],
        labels: [
          Label(
            id: 0,
            x: 0.5,
            y: 0.5,
            width: 0.2,
            height: 0.2,
            points: [
              LabelPoint(x: 0.4, y: 0.4),
              LabelPoint(x: 0.6, y: 0.6),
            ],
          ),
        ],
      );

      final handler = EditModeDragStartHandler(
        canvasProvider: canvasProvider,
        projectProvider: projectProvider,
        labels: projectProvider.labels,
        definitions: projectProvider.labelDefinitions,
        imageSize: const Size(100, 100),
        normalized: const Offset(0.6, 0.6),
        localPos: const Offset(60, 60),
        findKeypointAt: (_) => HitKeypoint(0, 1),
        findHandleAt: (_, __) => null,
        findEdgeAt: (_, __) => null,
        findLabelAt: (_) => null,
        setResizeStartRect: (_) {},
      );

      handler.run();

      expect(canvasProvider.interactionMode, InteractionMode.movingKeypoint);
      expect(canvasProvider.selectedLabelIndex, 0);
      expect(canvasProvider.activeKeypointIndex, 1);
      expect(projectProvider.historyCalls, 1);
    });

    test('starts moving when label body is hit', () {
      final canvasProvider = CanvasProvider();
      final projectProvider = TestProjectProvider(
        definitions: [
          LabelDefinition(classId: 0, name: 'box', color: Colors.green),
        ],
        labels: [
          Label(id: 0, x: 0.5, y: 0.5, width: 0.2, height: 0.2),
        ],
      );

      final handler = EditModeDragStartHandler(
        canvasProvider: canvasProvider,
        projectProvider: projectProvider,
        labels: projectProvider.labels,
        definitions: projectProvider.labelDefinitions,
        imageSize: const Size(100, 100),
        normalized: const Offset(0.5, 0.5),
        localPos: const Offset(50, 50),
        findKeypointAt: (_) => null,
        findHandleAt: (_, __) => null,
        findEdgeAt: (_, __) => null,
        findLabelAt: (_) => 0,
        setResizeStartRect: (_) {},
      );

      handler.run();

      expect(canvasProvider.interactionMode, InteractionMode.moving);
      expect(canvasProvider.selectedLabelIndex, 0);
      expect(projectProvider.historyCalls, 1);
    });

    test('inserts polygon vertex when edge is hit', () {
      final canvasProvider = CanvasProvider()..selectLabel(0);
      final polygon = Label(
        id: 0,
        points: [
          LabelPoint(x: 0.2, y: 0.2),
          LabelPoint(x: 0.8, y: 0.2),
          LabelPoint(x: 0.8, y: 0.8),
        ],
      )..updateBboxFromPoints();
      final projectProvider = TestProjectProvider(
        definitions: [
          LabelDefinition(
            classId: 0,
            name: 'poly',
            color: Colors.purple,
            type: LabelType.polygon,
          ),
        ],
        labels: [polygon],
      );

      final handler = EditModeDragStartHandler(
        canvasProvider: canvasProvider,
        projectProvider: projectProvider,
        labels: projectProvider.labels,
        definitions: projectProvider.labelDefinitions,
        imageSize: const Size(100, 100),
        normalized: const Offset(0.5, 0.2),
        localPos: const Offset(50, 20),
        findKeypointAt: (_) => null,
        findHandleAt: (_, __) => null,
        findEdgeAt: (_, __) => 0,
        findLabelAt: (_) => null,
        setResizeStartRect: (_) {},
      );

      handler.run();

      expect(projectProvider.labels.first.points.length, 4);
      expect(canvasProvider.activeKeypointIndex, 1);
      expect(canvasProvider.interactionMode, InteractionMode.movingKeypoint);
      expect(projectProvider.historyCalls, 1);
    });

    test('clears selection when nothing is hit', () {
      final canvasProvider = CanvasProvider()..selectLabel(0);
      final projectProvider = TestProjectProvider(
        definitions: [
          LabelDefinition(classId: 0, name: 'box', color: Colors.teal),
        ],
        labels: [
          Label(id: 0, x: 0.5, y: 0.5, width: 0.2, height: 0.2),
        ],
      );

      final handler = EditModeDragStartHandler(
        canvasProvider: canvasProvider,
        projectProvider: projectProvider,
        labels: projectProvider.labels,
        definitions: projectProvider.labelDefinitions,
        imageSize: const Size(100, 100),
        normalized: const Offset(0.9, 0.9),
        localPos: const Offset(90, 90),
        findKeypointAt: (_) => null,
        findHandleAt: (_, __) => null,
        findEdgeAt: (_, __) => null,
        findLabelAt: (_) => null,
        setResizeStartRect: (_) {},
      );

      handler.run();

      expect(canvasProvider.selectedLabelIndex, isNull);
      expect(canvasProvider.interactionMode, InteractionMode.none);
    });
  });
}
