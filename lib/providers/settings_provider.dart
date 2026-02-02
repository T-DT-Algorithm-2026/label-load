import 'package:flutter/foundation.dart';
import '../services/app/app_error.dart';
import '../services/gpu/gpu_info.dart';
import '../services/gpu/gpu_detector.dart';
import '../services/settings/settings_store.dart';
import '../services/settings/settings_validator.dart';
import 'app_error_state.dart';

/// 边界框绘制模式
enum BoxDrawMode {
  /// 拖动模式：按住鼠标拖动绘制
  drag,

  /// 两点模式：点击两个角点绘制
  twoClick,
}

/// 推理设备类型
enum InferenceDevice {
  /// CPU推理
  cpu,

  /// GPU推理（CUDA等）
  gpu,
}

/// 全局设置状态管理
///
/// 管理应用级别的设置，包括绘制模式、缩放范围、点大小和推理设备。
class SettingsProvider extends ChangeNotifier with AppErrorState {
  // 存储键
  static const String _boxDrawModeKey = 'box_draw_mode';
  static const String _minScaleKey = 'min_scale';
  static const String _maxScaleKey = 'max_scale';
  static const String _pointSizeKey = 'point_size';
  static const String _pointHitRadiusKey = 'point_hit_radius';
  static const String _fillShapeKey = 'fill_shape';
  static const String _inferenceDeviceKey = 'inference_device';
  static const String _showUnlabeledPointsKey = 'show_unlabeled_points';
  static const String _imageInterpolationKey = 'image_interpolation';
  static const String _autoSaveKey = 'auto_save';

  // 默认值
  static const double defaultMinScale = 0.05;
  static const double defaultMaxScale = 20.0;
  static const double defaultPointSize = 6.0;
  static const double defaultPointHitRadius = 60.0;
  static const bool defaultFillShape = true;
  static const bool defaultShowUnlabeledPoints = true;
  static const bool defaultImageInterpolation = true;
  static const bool defaultAutoSave = true;

  // 当前值
  BoxDrawMode _boxDrawMode = BoxDrawMode.drag;
  double _minScale = defaultMinScale;
  double _maxScale = defaultMaxScale;
  double _pointSize = defaultPointSize;
  double _pointHitRadius = defaultPointHitRadius;
  bool _fillShape = defaultFillShape;
  bool _showUnlabeledPoints = defaultShowUnlabeledPoints;
  bool _imageInterpolation = defaultImageInterpolation;
  bool _autoSaveOnNavigate = defaultAutoSave;
  bool _isInitialized = false;

  // 推理设备相关
  InferenceDevice _inferenceDevice = InferenceDevice.cpu;
  bool _gpuAvailable = false;
  GpuInfo? _gpuInfo;
  String _availableProviders = 'CPUExecutionProvider';

  // Getters
  /// 当前边界框绘制模式。
  BoxDrawMode get boxDrawMode => _boxDrawMode;

  /// 是否为“两点绘制”模式。
  bool get isTwoClickMode => _boxDrawMode == BoxDrawMode.twoClick;

  /// 最小缩放比例。
  double get minScale => _minScale;

  /// 最大缩放比例。
  double get maxScale => _maxScale;

  /// 关键点显示尺寸。
  double get pointSize => _pointSize;

  /// 关键点命中半径。
  double get pointHitRadius => _pointHitRadius;

  /// 是否填充形状。
  bool get fillShape => _fillShape;

  /// 是否显示未标注关键点。
  bool get showUnlabeledPoints => _showUnlabeledPoints;

  /// 是否启用图像插值。
  bool get imageInterpolation => _imageInterpolation;

  /// 导航时是否自动保存。
  bool get autoSaveOnNavigate => _autoSaveOnNavigate;

  /// 是否已完成初始化加载。
  bool get isInitialized => _isInitialized;

  /// 推理设备选择。
  InferenceDevice get inferenceDevice => _inferenceDevice;

  /// GPU 是否可用。
  bool get gpuAvailable => _gpuAvailable;

  /// GPU 详情信息。
  GpuInfo? get gpuInfo => _gpuInfo;

  /// 当前可用推理提供者字符串。
  String get availableProviders => _availableProviders;

  /// 是否实际使用 GPU（需要可用且已选中）。
  bool get useGpu => _inferenceDevice == InferenceDevice.gpu && _gpuAvailable;

  SettingsProvider({
    SettingsStore? store,
    GpuDetector? gpuDetector,
    bool autoLoad = true,
  })  : _store = store ?? SharedPreferencesStore(),
        _gpuDetector = gpuDetector ?? OnnxGpuDetector() {
    if (autoLoad) {
      _loadSettings();
    }
  }

  final SettingsStore _store;
  final GpuDetector _gpuDetector;

  /// 仅用于测试的手动加载入口。
  @visibleForTesting
  Future<void> loadSettingsForTest() => _loadSettings();

  /// 从本地存储加载设置
  Future<void> _loadSettings() async {
    try {
      // 绘制模式
      final modeIndex = await _store.getInt(_boxDrawModeKey) ?? 0;
      _boxDrawMode =
          BoxDrawMode.values[modeIndex.clamp(0, BoxDrawMode.values.length - 1)];

      // 缩放范围
      final rawMinScale =
          await _store.getDouble(_minScaleKey) ?? defaultMinScale;
      final rawMaxScale =
          await _store.getDouble(_maxScaleKey) ?? defaultMaxScale;
      final clampedMin = SettingsValidator.clampMinScale(rawMinScale);
      final clampedMax = SettingsValidator.clampMaxScale(rawMaxScale);
      final range = SettingsValidator.normalizeScaleRange(
        clampedMin,
        clampedMax,
        defaultMin: defaultMinScale,
        defaultMax: defaultMaxScale,
      );
      _minScale = range.$1;
      _maxScale = range.$2;

      // 点大小
      _pointSize = SettingsValidator.clampPointSize(
          await _store.getDouble(_pointSizeKey) ?? defaultPointSize);

      // 点点击半径
      _pointHitRadius = SettingsValidator.clampPointHitRadius(
          await _store.getDouble(_pointHitRadiusKey) ?? defaultPointHitRadius);

      // 填充形状
      _fillShape = await _store.getBool(_fillShapeKey) ?? defaultFillShape;

      // 显示未标注点
      _showUnlabeledPoints = await _store.getBool(_showUnlabeledPointsKey) ??
          defaultShowUnlabeledPoints;

      // 图像插值
      _imageInterpolation = await _store.getBool(_imageInterpolationKey) ??
          defaultImageInterpolation;

      // 自动保存
      _autoSaveOnNavigate =
          await _store.getBool(_autoSaveKey) ?? defaultAutoSave;

      // 推理设备
      final deviceIndex = await _store.getInt(_inferenceDeviceKey) ?? 0;
      _inferenceDevice = InferenceDevice
          .values[deviceIndex.clamp(0, InferenceDevice.values.length - 1)];

      // 检测GPU
      await _detectGpuAvailability();

      // GPU不可用时回退到CPU
      if (_inferenceDevice == InferenceDevice.gpu && !_gpuAvailable) {
        _inferenceDevice = InferenceDevice.cpu;
      }
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.unexpected,
        stackTrace: stack,
        details: 'load settings: $e',
        notify: false,
      );
      _resetToDefaults();
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// 重置为默认值
  void _resetToDefaults() {
    _boxDrawMode = BoxDrawMode.drag;
    _minScale = defaultMinScale;
    _maxScale = defaultMaxScale;
    _pointSize = defaultPointSize;
    _pointHitRadius = defaultPointHitRadius;
    _fillShape = defaultFillShape;
    _showUnlabeledPoints = defaultShowUnlabeledPoints;
    _imageInterpolation = defaultImageInterpolation;
    _autoSaveOnNavigate = defaultAutoSave;
    _inferenceDevice = InferenceDevice.cpu;
    _gpuAvailable = false;
  }

  /// 检测GPU可用性
  Future<void> _detectGpuAvailability() async {
    try {
      final result = await _gpuDetector.detect();
      _gpuAvailable = result.available;
      _gpuInfo = result.info;
      _availableProviders = result.providers;
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.unexpected,
        stackTrace: stack,
        details: 'gpu detection: $e',
        notify: false,
      );
      _gpuAvailable = false;
      _gpuInfo = null;
      _availableProviders = 'CPUExecutionProvider';
    }
  }

  /// 刷新GPU检测
  Future<void> refreshGpuDetection() async {
    await _detectGpuAvailability();

    if (_inferenceDevice == InferenceDevice.gpu && !_gpuAvailable) {
      _inferenceDevice = InferenceDevice.cpu;
      await _saveSettings();
    }
    notifyListeners();
  }

  /// 设置推理设备
  Future<void> setInferenceDevice(InferenceDevice device) async {
    if (device == InferenceDevice.gpu && !_gpuAvailable) return;

    if (_inferenceDevice != device) {
      _inferenceDevice = device;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置绘制模式
  Future<void> setBoxDrawMode(BoxDrawMode mode) async {
    if (_boxDrawMode != mode) {
      _boxDrawMode = mode;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置缩放范围
  Future<void> setScaleRange(double minScale, double maxScale) async {
    minScale = SettingsValidator.clampMinScale(minScale);
    maxScale = SettingsValidator.clampMaxScale(maxScale);
    if (minScale >= maxScale) return;

    if (_minScale != minScale || _maxScale != maxScale) {
      _minScale = minScale;
      _maxScale = maxScale;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置最小缩放
  Future<void> setMinScale(double value) async {
    value = SettingsValidator.clampMinScale(value);
    if (value >= _maxScale) return;
    if (_minScale != value) {
      _minScale = value;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置最大缩放
  Future<void> setMaxScale(double value) async {
    value = SettingsValidator.clampMaxScale(value);
    if (value <= _minScale) return;
    if (_maxScale != value) {
      _maxScale = value;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置点大小
  Future<void> setPointSize(double value) async {
    value = SettingsValidator.clampPointSize(value);
    if (_pointSize != value) {
      _pointSize = value;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置点点击半径
  Future<void> setPointHitRadius(double value) async {
    value = SettingsValidator.clampPointHitRadius(value);
    if (_pointHitRadius != value) {
      _pointHitRadius = value;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置是否填充形状
  Future<void> setFillShape(bool value) async {
    if (_fillShape != value) {
      _fillShape = value;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置是否显示未标注点
  Future<void> setShowUnlabeledPoints(bool value) async {
    if (_showUnlabeledPoints != value) {
      _showUnlabeledPoints = value;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置图像插值
  Future<void> setImageInterpolation(bool value) async {
    if (_imageInterpolation != value) {
      _imageInterpolation = value;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 设置导航时自动保存
  Future<void> setAutoSaveOnNavigate(bool value) async {
    if (_autoSaveOnNavigate != value) {
      _autoSaveOnNavigate = value;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 保存设置到本地存储
  Future<void> _saveSettings() async {
    try {
      await _store.setInt(_boxDrawModeKey, _boxDrawMode.index);
      await _store.setDouble(_minScaleKey, _minScale);
      await _store.setDouble(_maxScaleKey, _maxScale);
      await _store.setDouble(_pointSizeKey, _pointSize);
      await _store.setDouble(_pointHitRadiusKey, _pointHitRadius);
      await _store.setBool(_fillShapeKey, _fillShape);
      await _store.setBool(_showUnlabeledPointsKey, _showUnlabeledPoints);
      await _store.setBool(_imageInterpolationKey, _imageInterpolation);
      await _store.setBool(_autoSaveKey, _autoSaveOnNavigate);
      await _store.setInt(_inferenceDeviceKey, _inferenceDevice.index);
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.ioOperationFailed,
        stackTrace: stack,
        details: 'save settings: $e',
        notify: false,
      );
    }
  }
}
