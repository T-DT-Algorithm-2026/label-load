/**
 * ONNX 推理插件的无运行时分支测试。
 *
 * 验证 ONNX Runtime 不存在时的错误码与返回值。
 */
#include "onnx_inference.h"

#include <cassert>
#include <cstring>
#include <iostream>

static void test_init_error() {
  // 初始化失败时必须设置错误码与错误信息。
  bool ok = onnx_init();
  assert(!ok);
  assert(onnx_get_last_error_code() == ONNX_ERROR_RUNTIME_NOT_FOUND);
  const char *err = onnx_get_last_error();
  assert(err != nullptr);
  assert(std::strlen(err) > 0);
}

static void test_load_model_error() {
  // 在缺少运行时环境下，加载应失败并标记错误码。
  ModelHandle handle = onnx_load_model("fake.onnx", false);
  assert(handle == nullptr);
  assert(onnx_get_last_error_code() == ONNX_ERROR_RUNTIME_NOT_FOUND);
}

static void test_get_input_size_errors() {
  // 空指针与未初始化模型应返回失败。
  int w = -1;
  int h = -1;
  bool ok = onnx_get_input_size(nullptr, nullptr, nullptr);
  assert(!ok);
  assert(onnx_get_last_error_code() == ONNX_ERROR_INVALID_ARGUMENT);

  ok = onnx_get_input_size(nullptr, &w, &h);
  assert(!ok);
  assert(w == 0);
  assert(h == 0);
  assert(onnx_get_last_error_code() == ONNX_ERROR_RUNTIME_NOT_FOUND);
}

static void test_detect_errors() {
  // 推理接口应在缺少运行时时直接失败。
  DetectionResult *result =
      onnx_detect(nullptr, nullptr, 0, 0, 0.5f, 0.4f, 0, 0);
  assert(result == nullptr);
  assert(onnx_get_last_error_code() == ONNX_ERROR_RUNTIME_NOT_FOUND);

  BatchDetectionResult *batch =
      onnx_detect_batch(nullptr, nullptr, 0, nullptr, nullptr, 0.5f, 0.4f, 0, 0);
  assert(batch == nullptr);
  assert(onnx_get_last_error_code() == ONNX_ERROR_RUNTIME_NOT_FOUND);

  onnx_free_result(nullptr);
  onnx_free_batch_result(nullptr);
}

static void test_gpu_and_version() {
  // GPU 与版本查询在缺少运行时时返回安全默认值。
  const char *version = onnx_get_version();
  assert(version != nullptr);
  assert(std::strcmp(version, "unavailable") == 0);

  bool gpu = onnx_is_gpu_available();
  assert(!gpu);

  GpuInfo info = onnx_get_gpu_info();
  assert(info.cuda_available == false);
  assert(std::strlen(info.device_name) > 0);

  const char *providers = onnx_get_available_providers();
  assert(providers != nullptr);
  assert(std::strcmp(providers, "CPUExecutionProvider") == 0);
}

static void test_cleanup_resets_error() {
  // cleanup 应清空线程局部错误。
  (void)onnx_init();
  onnx_cleanup();
  assert(onnx_get_last_error_code() == ONNX_OK);
  const char *err = onnx_get_last_error();
  assert(err != nullptr);
  assert(std::strlen(err) == 0);
}

static void test_unload_model_noop() {
  // 允许空句柄卸载（无副作用）。
  onnx_unload_model(nullptr);
  assert(onnx_get_last_error_code() == ONNX_OK);
}

int main() {
  test_init_error();
  test_load_model_error();
  test_get_input_size_errors();
  test_detect_errors();
  test_gpu_and_version();
  test_cleanup_resets_error();
  test_unload_model_noop();
  std::cout << "onnx_inference_stub_test passed\n";
  return 0;
}
