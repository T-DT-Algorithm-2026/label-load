# onnx_inference

Lightweight ONNX Runtime FFI wrapper for YOLOv8-style models used by
`label_load`. The native layer is C++ and exposed to Dart via FFI.

## Features

- YOLOv8 detection / pose models
- Batch inference API
- GPU provider detection (CUDA/TensorRT/CoreML/DirectML)
- Error code + message surface for diagnostics
- Optional native unit tests (IoU / NMS)

## Usage (Dart)

```dart
final engine = OnnxInference.instance;
if (!engine.initialize()) {
  throw Exception(engine.lastError);
}

final ok = engine.loadModel('/path/to/model.onnx', useGpu: true);
if (!ok) {
  throw Exception('${engine.lastErrorCode}: ${engine.lastError}');
}

final detections = engine.detect(
  rgbaBytes,
  width,
  height,
  confThreshold: 0.25,
  nmsThreshold: 0.45,
  modelType: ModelType.yolo,
  numKeypoints: 17,
);
```

## Error Handling

Native side exposes:

- `onnx_get_last_error()` -> message
- `onnx_get_last_error_code()` -> code

Codes:

- `0` OK
- `1` UNKNOWN
- `2` NOT_INITIALIZED
- `3` INVALID_ARGUMENT
- `4` ALLOCATION_FAILED
- `5` RUNTIME_FAILURE
- `6` RUNTIME_NOT_FOUND

In Dart, use `OnnxInference.lastError` and `OnnxInference.lastErrorCode`.

## Thread Safety

- Global ORT environment is shared.
- `ModelHandle` is **not** thread-safe. Use one handle per thread or guard
  access with a mutex in the caller.

## Build Notes

This module expects ONNX Runtime headers + libs to be available. CMake tries:

- `/usr/local`, `/usr`, `/opt/onnxruntime`, `$HOME/onnxruntime`

If ONNX Runtime is not found, the build still succeeds but runtime calls return
`RUNTIME_NOT_FOUND` and no inference runs.

## Native Tests

Build and run C++ tests:

```
./build.sh test-native
```

Or directly:

```
cmake -S onnx_inference/src -B onnx_inference/build -DONNX_INFERENCE_BUILD_TESTS=ON
cmake --build onnx_inference/build --target onnx_inference_utils_test
ctest --test-dir onnx_inference/build --output-on-failure
```
