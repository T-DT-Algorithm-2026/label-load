import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/settings_provider.dart';
import 'package:label_load/services/gpu/gpu_detector.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/settings/settings_store.dart';

import 'test_helpers.dart';

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([Map<String, Object?>? initial])
      : _values = {...?initial};

  final Map<String, Object?> _values;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double value) async {
    _values[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }
}

class FakeGpuDetector implements GpuDetector {
  FakeGpuDetector(this.result);

  final GpuDetectionResult result;

  @override
  Future<GpuDetectionResult> detect() async => result;
}

class SequenceGpuDetector implements GpuDetector {
  SequenceGpuDetector(this.results);

  final List<GpuDetectionResult> results;
  int _index = 0;

  @override
  Future<GpuDetectionResult> detect() async {
    final result = results[_index.clamp(0, results.length - 1)];
    _index += 1;
    return result;
  }
}

class FailingSettingsStore extends MemorySettingsStore {
  FailingSettingsStore([super.initial]);

  @override
  Future<void> setInt(String key, int value) async {
    throw Exception('write failed');
  }
}

class ThrowingSettingsStore implements SettingsStore {
  @override
  Future<int?> getInt(String key) async {
    throw Exception('read failed');
  }

  @override
  Future<double?> getDouble(String key) async {
    throw Exception('read failed');
  }

  @override
  Future<bool?> getBool(String key) async {
    throw Exception('read failed');
  }

  @override
  Future<void> setInt(String key, int value) async {}

  @override
  Future<void> setDouble(String key, double value) async {}

  @override
  Future<void> setBool(String key, bool value) async {}
}

class ThrowingGpuDetector implements GpuDetector {
  @override
  Future<GpuDetectionResult> detect() async {
    throw Exception('gpu detection failed');
  }
}

void main() {
  group('SettingsProvider', () {
    test('loads settings, clamps ranges, and falls back when GPU unavailable',
        () async {
      final store = MemorySettingsStore({
        'box_draw_mode': 1,
        'min_scale': 0.4,
        'max_scale': 0.3,
        'point_size': 20.0,
        'point_hit_radius': 500.0,
        'fill_shape': false,
        'show_unlabeled_points': false,
        'image_interpolation': false,
        'auto_save': false,
        'inference_device': 1,
      });

      final gpuDetector = FakeGpuDetector(const GpuDetectionResult(
        available: false,
        info: null,
        providers: 'CPUExecutionProvider',
      ));

      final provider = SettingsProvider(
        store: store,
        gpuDetector: gpuDetector,
        autoLoad: false,
      );

      await provider.loadSettingsForTest();

      expect(provider.isInitialized, isTrue);
      expect(provider.minScale, 0.4);
      expect(provider.maxScale, 1.0);
      expect(provider.pointSize, 15.0);
      expect(provider.pointHitRadius, 200.0);
      expect(provider.inferenceDevice, InferenceDevice.cpu);
      expect(provider.autoSaveOnNavigate, isFalse);
    });

    test('keeps GPU when available', () async {
      final store = MemorySettingsStore({
        'inference_device': 1,
      });

      final gpuDetector = FakeGpuDetector(const GpuDetectionResult(
        available: true,
        info: null,
        providers: 'CUDAExecutionProvider',
      ));

      final provider = SettingsProvider(
        store: store,
        gpuDetector: gpuDetector,
        autoLoad: false,
      );

      await provider.loadSettingsForTest();

      expect(provider.inferenceDevice, InferenceDevice.gpu);
      expect(provider.availableProviders, 'CUDAExecutionProvider');
    });

    test('exposes getters and derived flags', () async {
      const gpuInfo = GpuInfo(
        cudaAvailable: true,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: 'GPU0',
        cudaDeviceCount: 1,
      );
      final store = MemorySettingsStore({
        'box_draw_mode': 1,
        'inference_device': 1,
      });
      final gpuDetector = FakeGpuDetector(const GpuDetectionResult(
        available: true,
        info: gpuInfo,
        providers: 'CUDAExecutionProvider',
      ));

      final provider = SettingsProvider(
        store: store,
        gpuDetector: gpuDetector,
        autoLoad: false,
      );

      await provider.loadSettingsForTest();

      expect(provider.boxDrawMode, BoxDrawMode.twoClick);
      expect(provider.isTwoClickMode, isTrue);
      expect(provider.minScale, SettingsProvider.defaultMinScale);
      expect(provider.maxScale, SettingsProvider.defaultMaxScale);
      expect(provider.pointSize, SettingsProvider.defaultPointSize);
      expect(provider.pointHitRadius, SettingsProvider.defaultPointHitRadius);
      expect(provider.fillShape, SettingsProvider.defaultFillShape);
      expect(provider.showUnlabeledPoints,
          SettingsProvider.defaultShowUnlabeledPoints);
      expect(provider.imageInterpolation,
          SettingsProvider.defaultImageInterpolation);
      expect(provider.autoSaveOnNavigate, SettingsProvider.defaultAutoSave);
      expect(provider.gpuAvailable, isTrue);
      expect(provider.gpuInfo, gpuInfo);
      expect(provider.availableProviders, 'CUDAExecutionProvider');
      expect(provider.useGpu, isTrue);
    });

    test('setters update values and persist', () async {
      final store = MemorySettingsStore();
      final gpuDetector = FakeGpuDetector(const GpuDetectionResult(
        available: true,
        info: null,
        providers: 'CUDAExecutionProvider',
      ));

      final provider = SettingsProvider(
        store: store,
        gpuDetector: gpuDetector,
        autoLoad: false,
      );

      await provider.loadSettingsForTest();

      await provider.setBoxDrawMode(BoxDrawMode.twoClick);
      expect(provider.boxDrawMode, BoxDrawMode.twoClick);

      await provider.setScaleRange(0.1, 2.0);
      expect(provider.minScale, 0.1);
      expect(provider.maxScale, 2.0);

      await provider.setPointSize(8.0);
      expect(provider.pointSize, 8.0);

      await provider.setPointHitRadius(80.0);
      expect(provider.pointHitRadius, 80.0);

      await provider.setFillShape(false);
      expect(provider.fillShape, isFalse);

      await provider.setShowUnlabeledPoints(false);
      expect(provider.showUnlabeledPoints, isFalse);

      await provider.setImageInterpolation(false);
      expect(provider.imageInterpolation, isFalse);

      await provider.setAutoSaveOnNavigate(false);
      expect(provider.autoSaveOnNavigate, isFalse);

      await provider.setInferenceDevice(InferenceDevice.gpu);
      expect(provider.inferenceDevice, InferenceDevice.gpu);
    });

    test('clamps scale updates and ignores invalid single bounds', () async {
      final provider = SettingsProvider(
        store: MemorySettingsStore(),
        gpuDetector: FakeGpuDetector(const GpuDetectionResult(
          available: true,
          info: null,
          providers: 'CUDAExecutionProvider',
        )),
        autoLoad: false,
      );

      await provider.loadSettingsForTest();

      await provider.setScaleRange(2.0, 0.1);
      expect(provider.minScale, 0.5);
      expect(provider.maxScale, 1.0);

      await provider.setMinScale(provider.maxScale);
      expect(provider.minScale, 0.5);

      await provider.setMaxScale(provider.minScale);
      expect(provider.maxScale, 1.0);
    });

    test('setInferenceDevice ignores GPU when unavailable', () async {
      final store = MemorySettingsStore({
        'inference_device': 0,
      });
      final gpuDetector = FakeGpuDetector(const GpuDetectionResult(
        available: false,
        info: null,
        providers: 'CPUExecutionProvider',
      ));

      final provider = SettingsProvider(
        store: store,
        gpuDetector: gpuDetector,
        autoLoad: false,
      );

      await provider.loadSettingsForTest();
      await provider.setInferenceDevice(InferenceDevice.gpu);

      expect(provider.inferenceDevice, InferenceDevice.cpu);
    });

    test('refreshGpuDetection falls back to CPU when GPU disappears', () async {
      final store = MemorySettingsStore({
        'inference_device': 1,
      });
      final gpuDetector = SequenceGpuDetector(const [
        GpuDetectionResult(
          available: true,
          info: null,
          providers: 'CUDAExecutionProvider',
        ),
        GpuDetectionResult(
          available: false,
          info: null,
          providers: 'CPUExecutionProvider',
        ),
      ]);

      final provider = SettingsProvider(
        store: store,
        gpuDetector: gpuDetector,
        autoLoad: false,
      );

      await provider.loadSettingsForTest();
      expect(provider.inferenceDevice, InferenceDevice.gpu);

      await provider.refreshGpuDetection();
      expect(provider.inferenceDevice, InferenceDevice.cpu);
    });

    test('loadSettings resets to defaults on read failure', () async {
      await runWithFlutterErrorsSuppressed(() async {
        final provider = SettingsProvider(
          store: ThrowingSettingsStore(),
          gpuDetector: FakeGpuDetector(const GpuDetectionResult(
            available: false,
            info: null,
            providers: 'CPUExecutionProvider',
          )),
          autoLoad: false,
        );

        await provider.loadSettingsForTest();

        expect(provider.boxDrawMode, BoxDrawMode.drag);
        expect(provider.minScale, SettingsProvider.defaultMinScale);
        expect(provider.maxScale, SettingsProvider.defaultMaxScale);
        expect(provider.inferenceDevice, InferenceDevice.cpu);
        expect(provider.gpuAvailable, isFalse);
        expect(provider.error, isNotNull);
      });
    });

    test('gpu detection errors fall back to CPU', () async {
      await runWithFlutterErrorsSuppressed(() async {
        final provider = SettingsProvider(
          store: MemorySettingsStore({'inference_device': 1}),
          gpuDetector: ThrowingGpuDetector(),
          autoLoad: false,
        );

        await provider.loadSettingsForTest();

        expect(provider.gpuAvailable, isFalse);
        expect(provider.gpuInfo, isNull);
        expect(provider.availableProviders, 'CPUExecutionProvider');
        expect(provider.inferenceDevice, InferenceDevice.cpu);
        expect(provider.error, isNotNull);
      });
    });

    test('save failures report error', () async {
      await runWithFlutterErrorsSuppressed(() async {
        final store = FailingSettingsStore();
        final provider = SettingsProvider(
          store: store,
          gpuDetector: FakeGpuDetector(const GpuDetectionResult(
            available: false,
            info: null,
            providers: 'CPUExecutionProvider',
          )),
          autoLoad: false,
        );

        await provider.loadSettingsForTest();
        await provider.setBoxDrawMode(BoxDrawMode.twoClick);

        expect(provider.error, isNotNull);
      });
    });
  });
}
