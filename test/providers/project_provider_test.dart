import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/services/inference/project_inference_controller.dart';
import 'package:label_load/services/projects/project_repository.dart';
import 'package:label_load/services/labels/label_history_store.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/services/inference/ai_post_processor.dart';

import 'test_helpers.dart';

class FakeProjectRepository extends ProjectRepository {
  FakeProjectRepository(this.images);

  final List<String> images;

  @override
  Future<List<String>> listImageFiles(String imagePath) async => images;
}

class FailingWriteProjectRepository extends FakeProjectRepository {
  FailingWriteProjectRepository(super.images);

  @override
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int) getName, {
    List<LabelDefinition>? labelDefinitions,
  }) async {
    return (<Label>[], <String>[]);
  }

  @override
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  }) {
    throw Exception('disk full');
  }
}

class MemoryProjectRepository extends FakeProjectRepository {
  MemoryProjectRepository(
    super.images, {
    Map<String, (List<Label>, List<String>)>? labelsByPath,
  }) : _labelsByPath = labelsByPath ?? {};

  final Map<String, (List<Label>, List<String>)> _labelsByPath;
  final Map<String, List<Label>> writtenLabels = {};
  bool throwOnRead = false;

  @override
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int) getName, {
    List<LabelDefinition>? labelDefinitions,
  }) async {
    if (throwOnRead) {
      throw Exception('read failed');
    }
    return _labelsByPath[labelPath] ?? (<Label>[], <String>[]);
  }

  @override
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  }) async {
    writtenLabels[labelPath] = List.from(labels);
  }
}

class ThrowingListProjectRepository extends ProjectRepository {
  @override
  Future<List<String>> listImageFiles(String imagePath) async {
    throw Exception('list failed');
  }
}

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

class StatefulInferenceRunner implements InferenceRunner {
  StatefulInferenceRunner({
    this.loadResult = true,
    this.throwOnLoad = false,
    List<Label>? labels,
  }) : labelsToReturn = labels ?? <Label>[];

  bool loadResult;
  bool throwOnLoad;
  List<Label> labelsToReturn;
  bool hasModelValue = false;
  String? loadedPath;

  @override
  bool get hasModel => hasModelValue;

  @override
  String? get loadedModelPath => loadedPath;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async {
    if (throwOnLoad) {
      throw Exception('load failed');
    }
    loadedPath = path;
    hasModelValue = loadResult;
    return loadResult;
  }

  @override
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    return labelsToReturn.map((l) => l.copyWith()).toList();
  }
}

class ThrowingInferenceRunner implements InferenceRunner {
  @override
  bool get hasModel => true;

  @override
  String? get loadedModelPath => 'model.onnx';

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async => true;

  @override
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    throw Exception('inference failed');
  }
}

class BadLabel extends Label {
  BadLabel({required super.id});

  @override
  String toYoloLineFull() {
    return '0';
  }
}

void main() {
  test('ProjectProvider uses injected repository', () async {
    final repository = FakeProjectRepository(['a.jpg', 'b.jpg']);
    final inferenceController =
        ProjectInferenceController(runner: FakeInferenceRunner());
    final provider = ProjectProvider(
      repository: repository,
      inferenceController: inferenceController,
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
    );

    await provider.loadProject(config);

    expect(provider.totalImages, 2);
    expect(provider.project?.imageFiles, const ['a.jpg', 'b.jpg']);
  });

  test('ProjectProvider exposes getters and helpers', () async {
    final runner = StatefulInferenceRunner()..hasModelValue = true;
    final provider = ProjectProvider(
      repository: FakeProjectRepository(['a.jpg']),
      inferenceController: ProjectInferenceController(runner: runner),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'cat',
          type: LabelType.box,
          color: const Color(0xFF123456),
        ),
      ],
      aiConfig: AiConfig(modelPath: 'model.onnx'),
    );

    await provider.loadProject(config);

    expect(provider.projectConfig, isNotNull);
    expect(provider.config.classNames, ['cat']);
    expect(provider.isLoading, isFalse);
    expect(provider.currentImagePath, 'a.jpg');
    expect(provider.getLabelColor(0), const Color(0xFF123456));
    expect(provider.getLabelDefinition(0)?.name, 'cat');
    expect(provider.isModelLoaded, isTrue);
    expect(provider.isProcessing, isFalse);
    expect(provider.lastDetectionCount, 0);

    final label = provider.createLabel(0, 0.5, 0.5, 2.0, 2.0);
    final bbox = label.bbox;
    expect(bbox[0], greaterThanOrEqualTo(0));
    expect(bbox[1], greaterThanOrEqualTo(0));
    expect(bbox[2], lessThanOrEqualTo(1));
    expect(bbox[3], lessThanOrEqualTo(1));
  });

  test('ProjectProvider label history and notifications', () async {
    final provider = ProjectProvider(
      repository: FakeProjectRepository(['a.jpg']),
      inferenceController:
          ProjectInferenceController(runner: FakeInferenceRunner()),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
    );

    await provider.loadProject(config);

    var notifications = 0;
    provider.addListener(() => notifications += 1);

    provider.addLabel(Label(id: 0));
    expect(provider.canUndo, isTrue);
    expect(provider.canRedo, isFalse);

    provider.updateLabel(0, Label(id: 1), notify: false);
    expect(provider.labels.first.id, 1);

    provider.updateLabel(0, Label(id: 2));
    expect(provider.labels.first.id, 2);

    expect(notifications, greaterThanOrEqualTo(1));
    provider.notifyLabelChange();

    provider.removeLabel(0);
    expect(provider.labels, isEmpty);

    provider.undo();
    expect(provider.labels, isNotEmpty);

    provider.redo();
    expect(provider.labels, isEmpty);
  });

  test('ProjectProvider updates config and locale', () async {
    final provider = ProjectProvider(
      repository: FakeProjectRepository(['a.jpg']),
      inferenceController:
          ProjectInferenceController(runner: FakeInferenceRunner()),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
    );

    await provider.loadProject(config);

    provider.updateConfig(provider.config.copyWith(locale: 'en'));
    expect(provider.config.locale, 'en');

    provider.setLocale('zh');
    expect(provider.config.locale, 'zh');
  });

  test('ProjectProvider reports load failure', () async {
    await runWithFlutterErrorsCaptured((errors) async {
      final provider = ProjectProvider(
        repository: ThrowingListProjectRepository(),
        inferenceController:
            ProjectInferenceController(runner: FakeInferenceRunner()),
      );

      final config = ProjectConfig(
        id: 'id',
        name: 'name',
        imagePath: '/images',
        labelPath: '/labels',
        labelDefinitions: const [],
      );

      await provider.loadProject(config);

      expect(provider.error?.code, AppErrorCode.projectLoadFailed);
      expect(provider.isLoading, isFalse);
      expect(errors, isNotEmpty);
    });
  });

  test('ProjectProvider reports parse failures during reloadConfig', () async {
    final repository = FakeProjectRepository(['a.jpg']);
    final inferenceController =
        ProjectInferenceController(runner: FakeInferenceRunner());
    final labelStore = LabelHistoryStore()..replaceLabels([BadLabel(id: 0)]);
    final provider = ProjectProvider(
      repository: repository,
      inferenceController: inferenceController,
      labelStore: labelStore,
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'cls',
          type: LabelType.box,
          color: const Color(0xFF000000),
        ),
      ],
    );

    await runWithFlutterErrorsCaptured((errors) async {
      await provider.reloadConfig(config);
      expect(errors, isNotEmpty);
    });
  });

  test('ProjectProvider saveLabels reports io failure', () async {
    final repository = FailingWriteProjectRepository(['a.jpg']);
    final inferenceController =
        ProjectInferenceController(runner: FakeInferenceRunner());
    final provider = ProjectProvider(
      repository: repository,
      inferenceController: inferenceController,
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
    );

    await provider.loadProject(config);
    provider.addLabel(Label(id: 0));

    final saved = await provider.saveLabels();
    expect(saved, isFalse);
    expect(provider.error?.code, AppErrorCode.ioOperationFailed);
  });

  test('ProjectProvider navigation aborts when save fails', () async {
    final repository = FailingWriteProjectRepository(['a.jpg', 'b.jpg']);
    final inferenceController =
        ProjectInferenceController(runner: FakeInferenceRunner());
    final provider = ProjectProvider(
      repository: repository,
      inferenceController: inferenceController,
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
    );

    await provider.loadProject(config);
    provider.addLabel(Label(id: 0));

    final moved = await provider.nextImage();
    expect(moved, isFalse);
    expect(provider.currentIndex, 0);
    expect(provider.error?.code, AppErrorCode.ioOperationFailed);
  });

  test('ProjectProvider blocks navigation when autoSave disabled', () async {
    final repository = FakeProjectRepository(['a.jpg', 'b.jpg']);
    final inferenceController =
        ProjectInferenceController(runner: FakeInferenceRunner());
    final provider = ProjectProvider(
      repository: repository,
      inferenceController: inferenceController,
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
    );

    await provider.loadProject(config);
    provider.addLabel(Label(id: 0));

    final moved = await provider.nextImage(autoSave: false);
    expect(moved, isFalse);
    expect(provider.currentIndex, 0);
    expect(provider.error?.code, AppErrorCode.unsavedChanges);
  });

  test('ProjectProvider loadProject fills missing definitions and updates bbox',
      () async {
    const imagePath = '/images/img1.jpg';
    const labelPath = '/labels/img1.txt';
    final polygonLabel = Label(
      id: 0,
      points: [
        LabelPoint(x: 0.1, y: 0.1),
        LabelPoint(x: 0.3, y: 0.1),
        LabelPoint(x: 0.2, y: 0.4),
      ],
    );
    final missingLabel = Label(id: 2);
    final repo = MemoryProjectRepository(
      [imagePath],
      labelsByPath: {
        labelPath: ([polygonLabel, missingLabel], <String>['bad']),
      },
    );
    final provider = ProjectProvider(
      repository: repo,
      inferenceController:
          ProjectInferenceController(runner: FakeInferenceRunner()),
      postProcessor: const AiPostProcessor(),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          type: LabelType.polygon,
          color: const Color(0xFF000000),
        ),
      ],
    );

    await provider.loadProject(config);

    expect(provider.labels.length, 2);
    expect(provider.labelDefinitions.any((d) => d.classId == 2), isTrue);
    expect(provider.pendingConfigUpdate, isNotNull);
    expect(provider.labels.first.width, greaterThan(0));
  });

  test('ProjectProvider handles load label read failure', () async {
    final repo = MemoryProjectRepository(['/images/img1.jpg']);
    repo.throwOnRead = true;
    final provider = ProjectProvider(
      repository: repo,
      inferenceController:
          ProjectInferenceController(runner: FakeInferenceRunner()),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
    );

    await provider.loadProject(config);
    expect(provider.labels, isEmpty);
    expect(provider.error, isNotNull);
  });

  test('ProjectProvider navigation succeeds when clean', () async {
    final repository = FakeProjectRepository(['a.jpg', 'b.jpg', 'c.jpg']);
    final provider = ProjectProvider(
      repository: repository,
      inferenceController:
          ProjectInferenceController(runner: FakeInferenceRunner()),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
    );

    await provider.loadProject(config);

    expect(await provider.nextImage(), isTrue);
    expect(provider.currentIndex, 1);
    expect(await provider.previousImage(), isTrue);
    expect(provider.currentIndex, 0);
    expect(await provider.goToImage(2), isTrue);
    expect(provider.currentIndex, 2);
  });

  test('ProjectProvider autoLabelCurrent guards missing config', () async {
    final provider = ProjectProvider(
      repository: FakeProjectRepository([]),
      inferenceController:
          ProjectInferenceController(runner: FakeInferenceRunner()),
    );

    await provider.autoLabelCurrent();
    expect(provider.error?.code, AppErrorCode.projectNotLoaded);
  });

  test('ProjectProvider autoLabelCurrent guards missing model', () async {
    final provider = ProjectProvider(
      repository: FakeProjectRepository(['a.jpg']),
      inferenceController:
          ProjectInferenceController(runner: FakeInferenceRunner()),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
      aiConfig: AiConfig(modelPath: ''),
    );

    await provider.loadProject(config);
    await provider.autoLabelCurrent();
    expect(provider.error?.code, AppErrorCode.aiModelNotConfigured);
  });

  test('ProjectProvider autoLabelCurrent handles load failure', () async {
    final runner = StatefulInferenceRunner(loadResult: false);
    final provider = ProjectProvider(
      repository: FakeProjectRepository(['a.jpg']),
      inferenceController: ProjectInferenceController(runner: runner),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
      aiConfig: AiConfig(modelPath: 'model.onnx'),
    );

    await provider.loadProject(config);
    await provider.autoLabelCurrent();
    expect(provider.error?.code, AppErrorCode.aiModelLoadFailed);
  });

  test('ProjectProvider autoLabelCurrent reports image not selected', () async {
    final runner = StatefulInferenceRunner(loadResult: true);
    final provider = ProjectProvider(
      repository: FakeProjectRepository([]),
      inferenceController: ProjectInferenceController(runner: runner),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
      aiConfig: AiConfig(modelPath: 'model.onnx'),
    );

    await provider.loadProject(config);
    await provider.autoLabelCurrent();

    expect(provider.error?.code, AppErrorCode.imageNotSelected);
  });

  test('ProjectProvider autoLabelCurrent reports inference failure', () async {
    await runWithFlutterErrorsSuppressed(() async {
      final provider = ProjectProvider(
        repository: FakeProjectRepository(['a.jpg']),
        inferenceController:
            ProjectInferenceController(runner: ThrowingInferenceRunner()),
      );

      final config = ProjectConfig(
        id: 'id',
        name: 'name',
        imagePath: '/images',
        labelPath: '/labels',
        labelDefinitions: const [],
        aiConfig: AiConfig(modelPath: 'model.onnx'),
      );

      await provider.loadProject(config);
      await provider.autoLabelCurrent(force: true);

      expect(provider.error?.code, AppErrorCode.aiInferenceFailed);
    });
  });

  test('ProjectProvider autoLabelCurrent appends labels and marks inferred',
      () async {
    final runner = StatefulInferenceRunner(labels: [Label(id: 1)]);
    final provider = ProjectProvider(
      repository: FakeProjectRepository(['a.jpg']),
      inferenceController: ProjectInferenceController(runner: runner),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
      aiConfig: AiConfig(modelPath: 'model.onnx'),
    );

    await provider.loadProject(config);
    provider.addLabel(Label(id: 0));

    await provider.autoLabelCurrent(force: true);

    expect(provider.labels.length, 2);
    expect(provider.isImageInferred('/images/a.jpg'), isTrue);
  });

  test('ProjectProvider autoLabelCurrent overwrites labels', () async {
    final runner = StatefulInferenceRunner(labels: [Label(id: 2)]);
    final provider = ProjectProvider(
      repository: FakeProjectRepository(['a.jpg']),
      inferenceController: ProjectInferenceController(runner: runner),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
      aiConfig: AiConfig(
        modelPath: 'model.onnx',
        labelSaveMode: LabelSaveMode.overwrite,
      ),
    );

    await provider.loadProject(config);
    provider.addLabel(Label(id: 0));

    await provider.autoLabelCurrent(force: true);

    expect(provider.labels.length, 1);
    expect(provider.labels.first.id, 2);
  });

  test('ProjectProvider autoLabelCurrent skips inferred images unless forced',
      () async {
    final runner = StatefulInferenceRunner(labels: [Label(id: 1)]);
    final provider = ProjectProvider(
      repository: FakeProjectRepository(['a.jpg']),
      inferenceController: ProjectInferenceController(runner: runner),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
      aiConfig: AiConfig(modelPath: 'model.onnx'),
      inferredImages: const ['a.jpg'],
    );

    await provider.loadProject(config);
    provider.addLabel(Label(id: 0));

    await provider.autoLabelCurrent();

    expect(provider.labels.length, 1);
  });

  test('ProjectProvider saveLabels succeeds and clears dirty flag', () async {
    final repo = MemoryProjectRepository(['a.jpg']);
    final provider = ProjectProvider(
      repository: repo,
      inferenceController:
          ProjectInferenceController(runner: FakeInferenceRunner()),
    );

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: const [],
    );

    await provider.loadProject(config);
    provider.addLabel(Label(id: 0));

    final saved = await provider.saveLabels();
    expect(saved, isTrue);
    expect(provider.isDirty, isFalse);
  });
}
