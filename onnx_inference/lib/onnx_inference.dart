/// ONNX 推理插件。
///
/// 使用 ONNX Runtime 和 YOLOv8 模型提供目标检测能力，覆盖检测与姿态估计。
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ============================================================================
// 模型类型枚举
// ============================================================================

/// YOLO 模型类型。
enum ModelType {
  /// 标准 YOLOv8 检测。
  yolo,

  /// YOLOv8-Pose 关键点检测。
  yoloPose,
}

// ============================================================================
// 数据类
// ============================================================================

/// 关键点数据（归一化坐标）。
class Keypoint {
  /// 归一化 x 坐标 (0-1)。
  final double x;

  /// 归一化 y 坐标 (0-1)。
  final double y;

  /// 可见性/置信度 (0-1)。
  final double visibility;

  Keypoint({
    required this.x,
    required this.y,
    required this.visibility,
  });

  @override
  String toString() =>
      'Keypoint(x=${x.toStringAsFixed(3)}, y=${y.toStringAsFixed(3)}, '
      'v=${visibility.toStringAsFixed(2)})';
}

/// 检测结果（归一化坐标）。
class Detection {
  /// 类别 ID。
  final int classId;

  /// 置信度。
  final double confidence;

  /// 中心 x 坐标（归一化 0-1）。
  final double x;

  /// 中心 y 坐标（归一化 0-1）。
  final double y;

  /// 宽度（归一化 0-1）。
  final double width;

  /// 高度（归一化 0-1）。
  final double height;

  /// 关键点列表（姿态模型可选）。
  final List<Keypoint>? keypoints;

  /// 掩码数据（分割模型预留）。
  final List<double>? mask;

  /// 掩码宽度。
  final int? maskWidth;

  /// 掩码高度。
  final int? maskHeight;

  Detection({
    required this.classId,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.keypoints,
    this.mask,
    this.maskWidth,
    this.maskHeight,
  });

  @override
  String toString() =>
      'Detection(class=$classId, conf=${confidence.toStringAsFixed(2)}, '
      'x=${x.toStringAsFixed(3)}, y=${y.toStringAsFixed(3)}, '
      'w=${width.toStringAsFixed(3)}, h=${height.toStringAsFixed(3)}'
      '${keypoints != null ? ", kpts=${keypoints!.length}" : ""})';
}

/// GPU 信息。
class GpuInfo {
  /// CUDA 是否可用。
  final bool cudaAvailable;

  /// TensorRT 是否可用。
  final bool tensorrtAvailable;

  /// CoreML 是否可用。
  final bool coremlAvailable;

  /// DirectML 是否可用。
  final bool directmlAvailable;

  /// 设备名称。
  final String deviceName;

  /// CUDA 设备数量。
  final int cudaDeviceCount;

  GpuInfo({
    required this.cudaAvailable,
    required this.tensorrtAvailable,
    required this.coremlAvailable,
    required this.directmlAvailable,
    required this.deviceName,
    required this.cudaDeviceCount,
  });

  /// 是否有任何 GPU 加速可用。
  bool get isGpuAvailable =>
      cudaAvailable || tensorrtAvailable || coremlAvailable || directmlAvailable;

  @override
  String toString() =>
      'GpuInfo(cuda=$cudaAvailable, tensorrt=$tensorrtAvailable, '
      'coreml=$coremlAvailable, directml=$directmlAvailable, '
      'device=$deviceName, cudaDevices=$cudaDeviceCount)';
}

// ============================================================================
// Native 结构定义
// ============================================================================

/// 原生检测结果结构体。
base class NativeDetection extends Struct {
  @Int32()
  external int classId;

  @Float()
  external double confidence;

  @Float()
  external double x;

  @Float()
  external double y;

  @Float()
  external double width;

  @Float()
  external double height;

  /// 关键点数组（x, y, visibility）指针。
  external Pointer<Float> keypoints;

  @Int32()
  external int numKeypoints;
}

/// 原生检测结果数组结构体。
base class NativeDetectionResult extends Struct {
  external Pointer<NativeDetection> detections;

  @Int32()
  external int count;

  @Int32()
  external int capacity;
}

/// 原生批量检测结果结构体。
base class NativeBatchDetectionResult extends Struct {
  external Pointer<NativeDetectionResult> results;

  @Int32()
  external int numImages;
}

/// 原生 GPU 信息结构体。
base class NativeGpuInfo extends Struct {
  @Bool()
  external bool cudaAvailable;

  @Bool()
  external bool tensorrtAvailable;

  @Bool()
  external bool coremlAvailable;

  @Bool()
  external bool directmlAvailable;

  @Array(256)
  external Array<Int8> deviceName;

  @Int32()
  external int cudaDeviceCount;
}

// ============================================================================
// Native 函数签名
// ============================================================================

typedef OnnxInitNative = Bool Function();
typedef OnnxInitDart = bool Function();

typedef OnnxCleanupNative = Void Function();
typedef OnnxCleanupDart = void Function();

typedef OnnxLoadModelNative = Pointer<Void> Function(Pointer<Utf8> modelPath, Bool useGpu);
typedef OnnxLoadModelDart = Pointer<Void> Function(Pointer<Utf8> modelPath, bool useGpu);

typedef OnnxUnloadModelNative = Void Function(Pointer<Void> handle);
typedef OnnxUnloadModelDart = void Function(Pointer<Void> handle);

typedef OnnxGetInputSizeNative = Bool Function(Pointer<Void> handle, Pointer<Int32> width, Pointer<Int32> height);
typedef OnnxGetInputSizeDart = bool Function(Pointer<Void> handle, Pointer<Int32> width, Pointer<Int32> height);

typedef OnnxDetectNative = Pointer<NativeDetectionResult> Function(
  Pointer<Void> handle,
  Pointer<Uint8> imageData,
  Int32 imageWidth,
  Int32 imageHeight,
  Float confThreshold,
  Float nmsThreshold,
  Int32 modelType,
  Int32 numKeypoints,
);
typedef OnnxDetectDart = Pointer<NativeDetectionResult> Function(
  Pointer<Void> handle,
  Pointer<Uint8> imageData,
  int imageWidth,
  int imageHeight,
  double confThreshold,
  double nmsThreshold,
  int modelType,
  int numKeypoints,
);

typedef OnnxDetectBatchNative = Pointer<NativeBatchDetectionResult> Function(
  Pointer<Void> handle,
  Pointer<Pointer<Uint8>> imageDataList,
  Int32 numImages,
  Pointer<Int32> imageWidths,
  Pointer<Int32> imageHeights,
  Float confThreshold,
  Float nmsThreshold,
  Int32 modelType,
  Int32 numKeypoints,
);
typedef OnnxDetectBatchDart = Pointer<NativeBatchDetectionResult> Function(
  Pointer<Void> handle,
  Pointer<Pointer<Uint8>> imageDataList,
  int numImages,
  Pointer<Int32> imageWidths,
  Pointer<Int32> imageHeights,
  double confThreshold,
  double nmsThreshold,
  int modelType,
  int numKeypoints,
);

typedef OnnxFreeResultNative = Void Function(Pointer<NativeDetectionResult> result);
typedef OnnxFreeResultDart = void Function(Pointer<NativeDetectionResult> result);

typedef OnnxFreeBatchResultNative = Void Function(Pointer<NativeBatchDetectionResult> result);
typedef OnnxFreeBatchResultDart = void Function(Pointer<NativeBatchDetectionResult> result);

typedef OnnxGetVersionNative = Pointer<Utf8> Function();
typedef OnnxGetVersionDart = Pointer<Utf8> Function();

typedef OnnxIsGpuAvailableNative = Bool Function();
typedef OnnxIsGpuAvailableDart = bool Function();

typedef OnnxGetGpuInfoNative = NativeGpuInfo Function();
typedef OnnxGetGpuInfoDart = NativeGpuInfo Function();

typedef OnnxGetAvailableProvidersNative = Pointer<Utf8> Function();
typedef OnnxGetAvailableProvidersDart = Pointer<Utf8> Function();
typedef OnnxGetLastErrorNative = Pointer<Utf8> Function();
typedef OnnxGetLastErrorDart = Pointer<Utf8> Function();
typedef OnnxGetLastErrorCodeNative = Int32 Function();
typedef OnnxGetLastErrorCodeDart = int Function();

typedef OnnxLookup = T Function<S extends Function, T extends Function>(
  String symbolName,
);

/// FFI 绑定集合，用于隔离动态库加载与逻辑调用。
class OnnxBindings {
  const OnnxBindings({
    required this.init,
    required this.cleanup,
    required this.loadModel,
    required this.unloadModel,
    required this.getInputSize,
    required this.detect,
    required this.detectBatch,
    required this.freeResult,
    required this.freeBatchResult,
    required this.getVersion,
    required this.isGpuAvailable,
    required this.getGpuInfo,
    required this.getAvailableProviders,
    required this.getLastError,
    required this.getLastErrorCode,
  });

  /// 从动态库解析全部函数指针。
  factory OnnxBindings.fromLibrary(DynamicLibrary lib) {
    return OnnxBindings.fromLookup(lib.lookupFunction);
  }

  /// 从符号查找函数创建绑定。
  factory OnnxBindings.fromLookup(OnnxLookup lookup) {
    return OnnxBindings(
      init: lookup<OnnxInitNative, OnnxInitDart>('onnx_init'),
      cleanup: lookup<OnnxCleanupNative, OnnxCleanupDart>('onnx_cleanup'),
      loadModel: lookup<OnnxLoadModelNative, OnnxLoadModelDart>(
        'onnx_load_model',
      ),
      unloadModel: lookup<OnnxUnloadModelNative, OnnxUnloadModelDart>(
        'onnx_unload_model',
      ),
      getInputSize: lookup<OnnxGetInputSizeNative, OnnxGetInputSizeDart>(
        'onnx_get_input_size',
      ),
      detect: lookup<OnnxDetectNative, OnnxDetectDart>('onnx_detect'),
      detectBatch: lookup<OnnxDetectBatchNative, OnnxDetectBatchDart>(
        'onnx_detect_batch',
      ),
      freeResult: lookup<OnnxFreeResultNative, OnnxFreeResultDart>(
        'onnx_free_result',
      ),
      freeBatchResult: lookup<OnnxFreeBatchResultNative,
          OnnxFreeBatchResultDart>('onnx_free_batch_result'),
      getVersion: lookup<OnnxGetVersionNative, OnnxGetVersionDart>(
        'onnx_get_version',
      ),
      isGpuAvailable: lookup<OnnxIsGpuAvailableNative, OnnxIsGpuAvailableDart>(
        'onnx_is_gpu_available',
      ),
      getGpuInfo: lookup<OnnxGetGpuInfoNative, OnnxGetGpuInfoDart>(
        'onnx_get_gpu_info',
      ),
      getAvailableProviders: lookup<OnnxGetAvailableProvidersNative,
          OnnxGetAvailableProvidersDart>('onnx_get_available_providers'),
      getLastError: lookup<OnnxGetLastErrorNative, OnnxGetLastErrorDart>(
        'onnx_get_last_error',
      ),
      getLastErrorCode: lookup<OnnxGetLastErrorCodeNative,
          OnnxGetLastErrorCodeDart>('onnx_get_last_error_code'),
    );
  }

  final OnnxInitDart init;
  final OnnxCleanupDart cleanup;
  final OnnxLoadModelDart loadModel;
  final OnnxUnloadModelDart unloadModel;
  final OnnxGetInputSizeDart getInputSize;
  final OnnxDetectDart detect;
  final OnnxDetectBatchDart detectBatch;
  final OnnxFreeResultDart freeResult;
  final OnnxFreeBatchResultDart freeBatchResult;
  final OnnxGetVersionDart getVersion;
  final OnnxIsGpuAvailableDart isGpuAvailable;
  final OnnxGetGpuInfoDart getGpuInfo;
  final OnnxGetAvailableProvidersDart getAvailableProviders;
  final OnnxGetLastErrorDart getLastError;
  final OnnxGetLastErrorCodeDart getLastErrorCode;
}

// ============================================================================
// OnnxInference 主类
// ============================================================================

/// ONNX 推理引擎。
///
/// 使用 ONNX Runtime 和 YOLOv8 模型提供目标检测功能。
class OnnxInference {
  /// 单例实例（缓存动态库与绑定）。
  static OnnxInference? _instance;
  /// 共享动态库句柄（避免重复加载）。
  static DynamicLibrary? _lib;

  final OnnxBindings _bindings;
  /// 是否已初始化底层运行时。
  bool _initialized = false;
  /// 当前模型句柄（由原生层返回）。
  Pointer<Void>? _modelHandle;

  OnnxInference._(this._bindings);

  /// 获取单例实例（自动加载动态库）。
  static OnnxInference get instance {
    _instance ??=
        OnnxInference._(OnnxBindings.fromLibrary(_resolveLibrary()));
    return _instance!;
  }

  /// 测试构造函数：注入自定义 FFI 绑定。
  factory OnnxInference.forTesting(OnnxBindings bindings) {
    return OnnxInference._(bindings);
  }

  /// 加载动态库并缓存。
  static DynamicLibrary _resolveLibrary() {
    if (_lib != null) {
      return _lib!;
    }

    const libName = 'onnx_inference';

    if (Platform.isMacOS || Platform.isIOS) {
      _lib = DynamicLibrary.open('$libName.framework/$libName');
    } else if (Platform.isAndroid || Platform.isLinux) {
      _lib = DynamicLibrary.open('lib$libName.so');
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('$libName.dll');
    } else {
      throw UnsupportedError('不支持的平台: ${Platform.operatingSystem}');
    }

    return _lib!;
  }

  /// 初始化 ONNX Runtime。
  bool initialize() {
    if (_initialized) return true;
    _initialized = _bindings.init();
    return _initialized;
  }

  /// 当前模型句柄是否有效。
  bool get _hasValidModel =>
      _modelHandle != null && _modelHandle!.address != 0;

  /// 将 RGBA 数据拷贝到原生堆内存（调用方负责释放）。
  Pointer<Uint8> _copyImageToNative(Uint8List imageData) {
    final ptr = calloc<Uint8>(imageData.length);
    ptr.asTypedList(imageData.length).setAll(0, imageData);
    return ptr;
  }

  /// 清理 ONNX Runtime。
  void dispose() {
    unloadModel();
    if (_initialized) {
      _bindings.cleanup();
      _initialized = false;
    }
  }

  /// 加载 ONNX 模型。
  ///
  /// [modelPath] - .onnx 模型文件路径。
  /// [useGpu] - 是否尝试使用 GPU 加速。
  bool loadModel(String modelPath, {bool useGpu = false}) {
    if (!_initialized && !initialize()) {
      return false;
    }

    unloadModel();

    final pathPtr = modelPath.toNativeUtf8();
    try {
      _modelHandle = _bindings.loadModel(pathPtr, useGpu);
    } finally {
      calloc.free(pathPtr);
    }

    return _modelHandle != null && _modelHandle!.address != 0;
  }

  /// 卸载当前模型。
  void unloadModel() {
    if (_hasValidModel) {
      _bindings.unloadModel(_modelHandle!);
      _modelHandle = null;
    }
  }

  /// 获取模型期望的输入尺寸。
  ///
  /// 未加载模型时返回 null。
  (int width, int height)? getInputSize() {
    if (!_hasValidModel) {
      return null;
    }

    final widthPtr = calloc<Int32>();
    final heightPtr = calloc<Int32>();

    try {
      final success = _bindings.getInputSize(_modelHandle!, widthPtr, heightPtr);
      return success ? (widthPtr.value, heightPtr.value) : null;
    } finally {
      calloc.free(widthPtr);
      calloc.free(heightPtr);
    }
  }

  /// 运行目标检测（内部会释放原生结果缓冲区）。
  ///
  /// [imageData] - RGBA 像素数据。
  /// [width], [height] - 图像尺寸。
  /// [confThreshold] - 置信度阈值 (0.0-1.0)。
  /// [nmsThreshold] - NMS IoU 阈值 (0.0-1.0)。
  /// [modelType] - YOLO 模型类型。
  /// [numKeypoints] - 姿态模型关键点数量（如 COCO 为 17）。
  List<Detection> detect(
    Uint8List imageData,
    int width,
    int height, {
    double confThreshold = 0.25,
    double nmsThreshold = 0.45,
    ModelType modelType = ModelType.yolo,
    int numKeypoints = 17,
  }) {
    if (!_hasValidModel) {
      return [];
    }

    Pointer<Uint8>? imagePtr;
    Pointer<NativeDetectionResult> resultPtr = Pointer.fromAddress(0);

    try {
      imagePtr = _copyImageToNative(imageData);

      resultPtr = _bindings.detect(
        _modelHandle!,
        imagePtr,
        width,
        height,
        confThreshold,
        nmsThreshold,
        modelType.index,
        numKeypoints,
      );

      if (resultPtr.address == 0) {
        return [];
      }

      final result = resultPtr.ref;
      final detections = <Detection>[];

      for (int i = 0; i < result.count; i++) {
        final det = result.detections[i];

        // 解析关键点。
        List<Keypoint>? keypoints;
        if (det.numKeypoints > 0 && det.keypoints.address != 0) {
          keypoints = [];
          for (int k = 0; k < det.numKeypoints; k++) {
            keypoints.add(Keypoint(
              x: det.keypoints[k * 3 + 0],
              y: det.keypoints[k * 3 + 1],
              visibility: det.keypoints[k * 3 + 2],
            ));
          }
        }

        detections.add(Detection(
          classId: det.classId,
          confidence: det.confidence,
          x: det.x,
          y: det.y,
          width: det.width,
          height: det.height,
          keypoints: keypoints,
        ));
      }

      return detections;
    } finally {
      if (imagePtr != null) {
        calloc.free(imagePtr);
      }
      if (resultPtr.address != 0) {
        _bindings.freeResult(resultPtr);
      }
    }
  }

  /// 运行批量目标检测（内部会释放原生结果缓冲区）。
  ///
  /// [imageList] - RGBA 像素数据列表。
  /// [sizes] - 图像尺寸列表 (width, height)。
  /// [confThreshold] - 置信度阈值 (0.0-1.0)。
  /// [nmsThreshold] - NMS IoU 阈值 (0.0-1.0)。
  /// [modelType] - YOLO 模型类型。
  /// [numKeypoints] - 姿态模型关键点数量（如 COCO 为 17）。
  List<List<Detection>> detectBatch(
    List<Uint8List> imageList,
    List<(int, int)> sizes, {
    double confThreshold = 0.25,
    double nmsThreshold = 0.45,
    ModelType modelType = ModelType.yolo,
    int numKeypoints = 17,
  }) {
    if (!_hasValidModel || imageList.isEmpty) {
      return List.filled(imageList.length, []);
    }
    
    if (imageList.length != sizes.length) {
      throw ArgumentError('图像列表和尺寸列表长度必须一致');
    }

    // 分配指针数组。
    final numImages = imageList.length;
    final imageListPtr = calloc<Pointer<Uint8>>(numImages);
    final widthListPtr = calloc<Int32>(numImages);
    final heightListPtr = calloc<Int32>(numImages);
    final imagePtrs = <Pointer<Uint8>>[];
    Pointer<NativeBatchDetectionResult> resultPtr = Pointer.fromAddress(0);

    try {
      // 填充图像数据和尺寸。
      for (int i = 0; i < numImages; i++) {
        final imageData = imageList[i];
        final imagePtr = _copyImageToNative(imageData);
        imagePtrs.add(imagePtr);
        imageListPtr[i] = imagePtr;
        
        widthListPtr[i] = sizes[i].$1;
        heightListPtr[i] = sizes[i].$2;
      }

      resultPtr = _bindings.detectBatch(
        _modelHandle!,
        imageListPtr,
        numImages,
        widthListPtr,
        heightListPtr,
        confThreshold,
        nmsThreshold,
        modelType.index,
        numKeypoints,
      );
      
      if (resultPtr.address == 0) {
        return List.filled(numImages, []);
      }
      
      final batchResult = resultPtr.ref;
      final allDetections = <List<Detection>>[];
      
      for (int i = 0; i < batchResult.numImages; i++) {
        final result = batchResult.results[i]; // 指针算术自动处理。
        final detections = <Detection>[];

        for (int k = 0; k < result.count; k++) {
          final det = result.detections[k];

          // 解析关键点。
          List<Keypoint>? keypoints;
          if (det.numKeypoints > 0 && det.keypoints.address != 0) {
            keypoints = [];
            for (int m = 0; m < det.numKeypoints; m++) {
              keypoints.add(Keypoint(
                x: det.keypoints[m * 3 + 0],
                y: det.keypoints[m * 3 + 1],
                visibility: det.keypoints[m * 3 + 2],
              ));
            }
          }

          detections.add(Detection(
            classId: det.classId,
            confidence: det.confidence,
            x: det.x,
            y: det.y,
            width: det.width,
            height: det.height,
            keypoints: keypoints,
          ));
        }
        allDetections.add(detections);
      }
      
      return allDetections;

    } finally {
      if (resultPtr.address != 0) {
        _bindings.freeBatchResult(resultPtr);
      }
      // 释放临时内存。
      for (final ptr in imagePtrs) {
        calloc.free(ptr);
      }
      calloc.free(imageListPtr);
      calloc.free(widthListPtr);
      calloc.free(heightListPtr);
    }
  }

  /// 获取插件版本。
  String get version {
    final ptr = _bindings.getVersion();
    return ptr.toDartString();
  }

  /// 获取最近一次错误信息。
  String get lastError {
    final ptr = _bindings.getLastError();
    return ptr.toDartString();
  }

  /// 获取最近一次错误码。
  int get lastErrorCode => _bindings.getLastErrorCode();

  /// 是否已加载模型（模型句柄有效）。
  bool get hasModel => _modelHandle != null && _modelHandle!.address != 0;
  
  /// 是否已初始化。
  bool get isInitialized => _initialized;

  // ============================================================================
  // GPU 检测 API
  // ============================================================================

  /// 检查 GPU 加速是否可用。
  bool isGpuAvailable() {
    try {
      return _bindings.isGpuAvailable();
    } catch (e) {
      return false;
    }
  }

  /// 获取详细 GPU 信息。
  GpuInfo getGpuInfo() {
    try {
      final nativeInfo = _bindings.getGpuInfo();
      
      // 转换设备名称。
      final deviceNameBytes = <int>[];
      for (int i = 0; i < 256; i++) {
        final byte = nativeInfo.deviceName[i];
        if (byte == 0) break;
        deviceNameBytes.add(byte);
      }
      final deviceName = String.fromCharCodes(deviceNameBytes);

      return GpuInfo(
        cudaAvailable: nativeInfo.cudaAvailable,
        tensorrtAvailable: nativeInfo.tensorrtAvailable,
        coremlAvailable: nativeInfo.coremlAvailable,
        directmlAvailable: nativeInfo.directmlAvailable,
        deviceName: deviceName,
        cudaDeviceCount: nativeInfo.cudaDeviceCount,
      );
    } catch (e) {
      return GpuInfo(
        cudaAvailable: false,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: '检测 GPU 时出错',
        cudaDeviceCount: 0,
      );
    }
  }

  /// 获取可用的执行提供程序列表。
  String getAvailableProviders() {
    try {
      final ptr = _bindings.getAvailableProviders();
      return ptr.toDartString();
    } catch (e) {
      return 'CPUExecutionProvider';
    }
  }
}
