/**
 * ONNX 推理插件实现
 *
 * 使用 ONNX Runtime 实现 YOLOv8 目标检测和姿态估计。
 *
 * 支持的模型:
 * - YOLOv8 Detection (yolov8n.onnx, yolov8s.onnx 等)
 * - YOLOv8-Pose (yolov8n-pose.onnx 等)
 */

#include "onnx_inference.h"
#include "onnx_inference_utils.h"

#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <mutex>
#ifndef ONNX_RUNTIME_NOT_FOUND
#include <onnxruntime_c_api.h>
#endif
#include <vector>

// ============================================================================
// 全局变量
// ============================================================================

#ifndef ONNX_RUNTIME_NOT_FOUND
static const OrtApi *g_ort = nullptr;
static OrtEnv *g_env = nullptr;
static bool g_initialized = false;
static std::mutex g_init_mutex;
#endif
// 线程局部错误缓存（FFI 调用方可读取）。
static thread_local char g_last_error[512] = {0};
static thread_local int g_last_error_code = ONNX_OK;

// ============================================================================
// 模型会话结构体
// ============================================================================

#ifndef ONNX_RUNTIME_NOT_FOUND
struct OnnxModel {
  OrtSession *session;
  OrtAllocator *allocator;
  OrtMemoryInfo *memory_info;
  // 模型输入尺寸（由模型元数据推断，回退到默认值）。
  int input_width;
  int input_height;
  // 输入/输出名称（由 ONNX Runtime 分配，需释放）。
  char *input_name;
  char *output_name;
  size_t num_outputs;
};
#endif

// ============================================================================
// 辅助宏
// ============================================================================

// 清空线程局部错误状态。
static void clear_last_error() {
  g_last_error[0] = '\0';
  g_last_error_code = ONNX_OK;
}

// 设置线程局部错误信息与错误码。
static void set_last_error(int code, const char *fmt, ...) {
  g_last_error_code = code;
  va_list args;
  va_start(args, fmt);
  vsnprintf(g_last_error, sizeof(g_last_error), fmt, args);
  va_end(args);
}

#ifndef ONNX_RUNTIME_NOT_FOUND
// 统一处理 OrtStatus，记录错误并释放资源。
static bool handle_status(OrtStatus *status, const char *context) {
  if (status == nullptr) {
    return true;
  }
  const char *msg =
      g_ort != nullptr ? g_ort->GetErrorMessage(status) : "unknown";
  set_last_error(ONNX_ERROR_RUNTIME_FAILURE, "%s: %s", context, msg);
  if (g_ort != nullptr) {
    g_ort->ReleaseStatus(status);
  }
  return false;
}

struct OrtSessionOptionsDeleter {
  void operator()(OrtSessionOptions *ptr) const {
    if (ptr && g_ort) {
      g_ort->ReleaseSessionOptions(ptr);
    }
  }
};

struct OrtValueDeleter {
  void operator()(OrtValue *ptr) const {
    if (ptr && g_ort) {
      g_ort->ReleaseValue(ptr);
    }
  }
};

struct OrtTensorInfoDeleter {
  void operator()(OrtTensorTypeAndShapeInfo *ptr) const {
    if (ptr && g_ort) {
      g_ort->ReleaseTensorTypeAndShapeInfo(ptr);
    }
  }
};

using OrtSessionOptionsPtr =
    std::unique_ptr<OrtSessionOptions, OrtSessionOptionsDeleter>;
using OrtValuePtr = std::unique_ptr<OrtValue, OrtValueDeleter>;
using OrtTensorInfoPtr =
    std::unique_ptr<OrtTensorTypeAndShapeInfo, OrtTensorInfoDeleter>;
#endif

#ifndef ONNX_RUNTIME_NOT_FOUND
static bool validate_image_dimensions(int width, int height,
                                      const char *context) {
  if (width <= 1 || height <= 1) {
    set_last_error(ONNX_ERROR_INVALID_ARGUMENT,
                   "%s: invalid image size (%d x %d)", context, width, height);
    return false;
  }
  return true;
}
#endif

// ============================================================================
// 初始化/清理
// ============================================================================

#ifdef ONNX_RUNTIME_NOT_FOUND

FFI_PLUGIN_EXPORT bool onnx_init(void) {
  clear_last_error();
  set_last_error(ONNX_ERROR_RUNTIME_NOT_FOUND, "ONNX Runtime 未找到");
  return false;
}

FFI_PLUGIN_EXPORT void onnx_cleanup(void) {
  clear_last_error();
}

FFI_PLUGIN_EXPORT ModelHandle onnx_load_model(const char *model_path,
                                              bool use_gpu) {
  (void)model_path;
  (void)use_gpu;
  clear_last_error();
  set_last_error(ONNX_ERROR_RUNTIME_NOT_FOUND, "ONNX Runtime 未找到");
  return nullptr;
}

FFI_PLUGIN_EXPORT void onnx_unload_model(ModelHandle handle) {
  (void)handle;
  clear_last_error();
}

FFI_PLUGIN_EXPORT bool onnx_get_input_size(ModelHandle handle, int *width,
                                           int *height) {
  (void)handle;
  if (!width || !height) {
    set_last_error(ONNX_ERROR_INVALID_ARGUMENT, "输出指针为空");
    return false;
  }
  *width = 0;
  *height = 0;
  set_last_error(ONNX_ERROR_RUNTIME_NOT_FOUND, "ONNX Runtime 未找到");
  return false;
}

FFI_PLUGIN_EXPORT BatchDetectionResult *
onnx_detect_batch(ModelHandle handle, const uint8_t **image_data_list,
                  int num_images, int *image_widths, int *image_heights,
                  float conf_threshold, float nms_threshold, int model_type,
                  int num_keypoints) {
  (void)handle;
  (void)image_data_list;
  (void)num_images;
  (void)image_widths;
  (void)image_heights;
  (void)conf_threshold;
  (void)nms_threshold;
  (void)model_type;
  (void)num_keypoints;
  clear_last_error();
  set_last_error(ONNX_ERROR_RUNTIME_NOT_FOUND, "ONNX Runtime 未找到");
  return nullptr;
}

FFI_PLUGIN_EXPORT DetectionResult *
onnx_detect(ModelHandle handle, const uint8_t *image_data, int image_width,
            int image_height, float conf_threshold, float nms_threshold,
            int model_type, int num_keypoints) {
  (void)handle;
  (void)image_data;
  (void)image_width;
  (void)image_height;
  (void)conf_threshold;
  (void)nms_threshold;
  (void)model_type;
  (void)num_keypoints;
  clear_last_error();
  set_last_error(ONNX_ERROR_RUNTIME_NOT_FOUND, "ONNX Runtime 未找到");
  return nullptr;
}

FFI_PLUGIN_EXPORT void onnx_free_batch_result(BatchDetectionResult *result) {
  (void)result;
  clear_last_error();
}

FFI_PLUGIN_EXPORT void onnx_free_result(DetectionResult *result) {
  (void)result;
  clear_last_error();
}

FFI_PLUGIN_EXPORT const char *onnx_get_version(void) {
  clear_last_error();
  return "unavailable";
}

FFI_PLUGIN_EXPORT bool onnx_is_gpu_available(void) {
  clear_last_error();
  return false;
}

FFI_PLUGIN_EXPORT GpuInfo onnx_get_gpu_info(void) {
  clear_last_error();
  GpuInfo info;
  memset(&info, 0, sizeof(info));
  strcpy(info.device_name, "ONNX Runtime 未找到");
  return info;
}

FFI_PLUGIN_EXPORT const char *onnx_get_available_providers(void) {
  clear_last_error();
  static thread_local char providers_str[64] = {0};
  strcpy(providers_str, "CPUExecutionProvider");
  return providers_str;
}

FFI_PLUGIN_EXPORT const char *onnx_get_last_error(void) {
  return g_last_error;
}

FFI_PLUGIN_EXPORT int onnx_get_last_error_code(void) {
  return g_last_error_code;
}

#else

FFI_PLUGIN_EXPORT bool onnx_init(void) {
  // 初始化全局环境（线程安全）。
  std::lock_guard<std::mutex> lock(g_init_mutex);
  if (g_initialized)
    return true;

  clear_last_error();

  g_ort = OrtGetApiBase()->GetApi(ORT_API_VERSION);
  if (!g_ort) {
    fprintf(stderr, "获取 ONNX Runtime API 失败\n");
    set_last_error(ONNX_ERROR_RUNTIME_NOT_FOUND, "获取 ONNX Runtime API 失败");
    return false;
  }

  OrtStatus *status =
      g_ort->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "OnnxInference", &g_env);
  if (status != nullptr) {
    const char *msg = g_ort->GetErrorMessage(status);
    fprintf(stderr, "创建 ONNX 环境失败: %s\n", msg);
    set_last_error(ONNX_ERROR_RUNTIME_FAILURE, "创建 ONNX 环境失败: %s", msg);
    g_ort->ReleaseStatus(status);
    return false;
  }

  g_initialized = true;
  return true;
}

FFI_PLUGIN_EXPORT void onnx_cleanup(void) {
  std::lock_guard<std::mutex> lock(g_init_mutex);
  if (g_env) {
    g_ort->ReleaseEnv(g_env);
    g_env = nullptr;
  }
  g_initialized = false;
}

// ============================================================================
// 模型加载
// ============================================================================

FFI_PLUGIN_EXPORT ModelHandle onnx_load_model(const char *model_path,
                                              bool use_gpu) {
  // 加载模型并创建会话，失败时返回空句柄并设置线程局部错误。
  clear_last_error();
  if (!g_initialized && !onnx_init()) {
    return nullptr;
  }
  if (!model_path || model_path[0] == '\0') {
    set_last_error(ONNX_ERROR_INVALID_ARGUMENT, "model_path 为空");
    return nullptr;
  }

  OnnxModel *model = new OnnxModel();
  memset(model, 0, sizeof(OnnxModel));

  // 创建会话选项
  OrtSessionOptions *session_options_raw = nullptr;
  if (!handle_status(g_ort->CreateSessionOptions(&session_options_raw),
                     "CreateSessionOptions")) {
    delete model;
    return nullptr;
  }
  OrtSessionOptionsPtr session_options(session_options_raw);

  // 设置优化选项
  handle_status(g_ort->SetIntraOpNumThreads(session_options.get(), 4),
                "SetIntraOpNumThreads");

  handle_status(g_ort->SetSessionGraphOptimizationLevel(session_options.get(),
                                                        ORT_ENABLE_ALL),
                "SetSessionGraphOptimizationLevel");

  // 如果请求且可用，添加 CUDA 提供程序
  if (use_gpu) {
    OrtCUDAProviderOptions cuda_options;
    memset(&cuda_options, 0, sizeof(cuda_options));
    cuda_options.device_id = 0;

    if (!handle_status(g_ort->SessionOptionsAppendExecutionProvider_CUDA(
                           session_options.get(), &cuda_options),
                       "SessionOptionsAppendExecutionProvider_CUDA")) {
      fprintf(stderr, "CUDA 不可用，回退到 CPU\n");
    }
  }

  // 创建会话
  OrtStatus *status =
      g_ort->CreateSession(g_env, model_path, session_options.get(),
                           &model->session);

  if (status != nullptr) {
    const char *msg = g_ort->GetErrorMessage(status);
    fprintf(stderr, "加载模型失败: %s\n", msg);
    set_last_error(ONNX_ERROR_RUNTIME_FAILURE, "加载模型失败: %s", msg);
    g_ort->ReleaseStatus(status);
    delete model;
    return nullptr;
  }

  // 获取分配器
  status = g_ort->GetAllocatorWithDefaultOptions(&model->allocator);
  if (!handle_status(status, "GetAllocatorWithDefaultOptions")) {
    g_ort->ReleaseSession(model->session);
    delete model;
    return nullptr;
  }

  // 创建内存信息
  status = g_ort->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault,
                                      &model->memory_info);
  if (!handle_status(status, "CreateCpuMemoryInfo")) {
    g_ort->ReleaseSession(model->session);
    delete model;
    return nullptr;
  }

  // 获取输入信息
  status = g_ort->SessionGetInputName(model->session, 0, model->allocator,
                                      &model->input_name);
  if (!handle_status(status, "SessionGetInputName")) {
    g_ort->ReleaseMemoryInfo(model->memory_info);
    g_ort->ReleaseSession(model->session);
    delete model;
    return nullptr;
  }

  // 获取输入维度
  OrtTypeInfo *input_type_info;
  status = g_ort->SessionGetInputTypeInfo(model->session, 0, &input_type_info);
  if (status == nullptr) {
    const OrtTensorTypeAndShapeInfo *tensor_info;
    if (!handle_status(g_ort->CastTypeInfoToTensorInfo(input_type_info,
                                                       &tensor_info),
                       "CastTypeInfoToTensorInfo")) {
      g_ort->ReleaseTypeInfo(input_type_info);
    }

    size_t dim_count;
    status = g_ort->GetDimensionsCount(tensor_info, &dim_count);
    if (!handle_status(status, "GetDimensionsCount")) {
      dim_count = 0;
    }

    std::vector<int64_t> dims(dim_count);
    if (dim_count > 0) {
      handle_status(g_ort->GetDimensions(tensor_info, dims.data(), dim_count),
                    "GetDimensions");
    }

    // NCHW 格式: [batch, channels, height, width]
    if (dim_count >= 4) {
      model->input_height = (int)dims[2];
      model->input_width = (int)dims[3];
    }

    g_ort->ReleaseTypeInfo(input_type_info);
  } else {
    handle_status(status, "SessionGetInputTypeInfo");
  }

  // 如果未确定，默认为 640x640
  if (model->input_width <= 0)
    model->input_width = 640;
  if (model->input_height <= 0)
    model->input_height = 640;

  // 获取输出数量
  status = g_ort->SessionGetOutputCount(model->session, &model->num_outputs);
  if (!handle_status(status, "SessionGetOutputCount")) {
    model->num_outputs = 1;
  }

  // 获取第一个输出名称
  handle_status(g_ort->SessionGetOutputName(model->session, 0, model->allocator,
                                            &model->output_name),
                "SessionGetOutputName");

  fprintf(stderr, "[信息] 模型已加载: 输入=%dx%d, 输出数=%zu\n",
          model->input_width, model->input_height, model->num_outputs);

  return model;
}

FFI_PLUGIN_EXPORT void onnx_unload_model(ModelHandle handle) {
  // 释放会话与关联的输入/输出名称。
  if (!handle)
    return;

  OnnxModel *model = (OnnxModel *)handle;

  if (model->input_name) {
    model->allocator->Free(model->allocator, model->input_name);
  }
  if (model->output_name) {
    model->allocator->Free(model->allocator, model->output_name);
  }
  if (model->memory_info) {
    g_ort->ReleaseMemoryInfo(model->memory_info);
  }
  if (model->session) {
    g_ort->ReleaseSession(model->session);
  }

  delete model;
}

FFI_PLUGIN_EXPORT bool onnx_get_input_size(ModelHandle handle, int *width,
                                           int *height) {
  clear_last_error();
  if (!handle)
    return false;
  if (!width || !height) {
    set_last_error(ONNX_ERROR_INVALID_ARGUMENT, "输出指针为空");
    return false;
  }

  OnnxModel *model = (OnnxModel *)handle;
  *width = model->input_width;
  *height = model->input_height;
  return true;
}

// ============================================================================
// 图像预处理 (letterbox)
// ============================================================================

/// 预处理图像，执行 letterbox 缩放并写入指定缓冲区
/// @param image_data 输入 RGBA 图像数据
/// @param image_width 原始图像宽度
/// @param image_height 原始图像高度
/// @param target_width 目标宽度
/// @param target_height 目标高度
/// @param buffer 目标缓冲区 (大小必须为 3 * target_width * target_height)
/// @param scale_x 输出：x 方向缩放比例
/// @param scale_y 输出：y 方向缩放比例
/// @param pad_left 输出：左侧填充像素数
/// @param pad_top 输出：顶部填充像素数
static void preprocess_image_to_buffer(const uint8_t *image_data,
                                       int image_width, int image_height,
                                       int target_width, int target_height,
                                       float *buffer, float *scale_x,
                                       float *scale_y, int *pad_left,
                                       int *pad_top) {
  if (!image_data || !buffer || target_width <= 0 || target_height <= 0 ||
      image_width <= 1 || image_height <= 1) {
    if (scale_x)
      *scale_x = 0.0f;
    if (scale_y)
      *scale_y = 0.0f;
    if (pad_left)
      *pad_left = 0;
    if (pad_top)
      *pad_top = 0;
    return;
  }
  // 计算 letterbox 缩放比例（保持宽高比）
  float ratio = std::min((float)target_width / image_width,
                         (float)target_height / image_height);

  int new_width = (int)(image_width * ratio);
  int new_height = (int)(image_height * ratio);

  *pad_left = (target_width - new_width) / 2;
  *pad_top = (target_height - new_height) / 2;
  *scale_x = ratio;
  *scale_y = ratio;

  // 填充灰色 (114/255) - YOLO 标准填充值
  const float pad_value = 114.0f / 255.0f;
  int total_pixels = target_width * target_height;
  for (int i = 0; i < 3 * total_pixels; i++) {
    buffer[i] = pad_value;
  }

  // 使用双线性插值复制和缩放图像（RGBA -> CHW RGB）。
  for (int y = 0; y < new_height; y++) {
    float src_y_f = y / ratio;
    int src_y = (int)src_y_f;
    float y_lerp = src_y_f - src_y;
    if (src_y >= image_height - 1) {
      src_y = image_height - 2;
      y_lerp = 1.0f;
    }

    for (int x = 0; x < new_width; x++) {
      float src_x_f = x / ratio;
      int src_x = (int)src_x_f;
      float x_lerp = src_x_f - src_x;
      if (src_x >= image_width - 1) {
        src_x = image_width - 2;
        x_lerp = 1.0f;
      }

      int dst_x = x + *pad_left;
      int dst_y = y + *pad_top;
      int c_stride = target_width * target_height;
      int dst_idx = dst_y * target_width + dst_x;

      // 对每个通道进行双线性插值
      for (int c = 0; c < 3; c++) {
        int idx00 = (src_y * image_width + src_x) * 4 + c;
        int idx01 = (src_y * image_width + src_x + 1) * 4 + c;
        int idx10 = ((src_y + 1) * image_width + src_x) * 4 + c;
        int idx11 = ((src_y + 1) * image_width + src_x + 1) * 4 + c;

        float v00 = image_data[idx00] / 255.0f;
        float v01 = image_data[idx01] / 255.0f;
        float v10 = image_data[idx10] / 255.0f;
        float v11 = image_data[idx11] / 255.0f;

        float v0 = v00 * (1 - x_lerp) + v01 * x_lerp;
        float v1 = v10 * (1 - x_lerp) + v11 * x_lerp;
        float v = v0 * (1 - y_lerp) + v1 * y_lerp;

        buffer[c * c_stride + dst_idx] = v;
      }
    }
  }
}

// ============================================================================
// YOLOv8 输出解析
// ============================================================================

// YOLOv8 输出格式: [1, num_features, num_boxes]
// 检测: num_features = 4 + num_classes
// 姿态: num_features = 4 + num_classes + num_keypoints * 3
// 分割: num_features = 4 + num_classes + 32（掩码系数）

/// 解析 YOLOv8 模型输出
static std::vector<Detection>
parse_yolov8_output(float *output_data, int num_features, int num_boxes,
                    int model_type, int num_keypoints, float conf_threshold,
                    float scale_x, float scale_y, int pad_left, int pad_top,
                    int image_width, int image_height) {

  std::vector<Detection> detections;

  // 根据模型类型计算类别数
  int num_classes;
  int extra_features = 0;

  if (model_type == MODEL_TYPE_YOLO_POSE && num_keypoints > 0) {
    extra_features = num_keypoints * 3;
    num_classes = num_features - 4 - extra_features;
  } else {
    num_classes = num_features - 4;
  }

  if (num_classes < 1) {
    fprintf(stderr, "[警告] 无效的类别数=%d，设置为 1\n", num_classes);
    num_classes = 1;
  }

  for (int i = 0; i < num_boxes; i++) {
    // YOLOv8 转置格式: output[feature][box]
    float cx = output_data[0 * num_boxes + i];
    float cy = output_data[1 * num_boxes + i];
    float w = output_data[2 * num_boxes + i];
    float h = output_data[3 * num_boxes + i];

    // 找到最佳类别
    int best_class = 0;
    float best_score = 0;
    for (int c = 0; c < num_classes; c++) {
      float score = output_data[(4 + c) * num_boxes + i];
      if (score > best_score) {
        best_score = score;
        best_class = c;
      }
    }

    if (best_score < conf_threshold)
      continue;

    // 转换为原始图像坐标（归一化 0-1）。
    float x_norm = (cx - pad_left) / scale_x / image_width;
    float y_norm = (cy - pad_top) / scale_y / image_height;
    float w_norm = w / scale_x / image_width;
    float h_norm = h / scale_y / image_height;

    Detection det;
    det.class_id = best_class;
    det.confidence = best_score;
    det.x = x_norm;
    det.y = y_norm;
    det.width = w_norm;
    det.height = h_norm;
    det.keypoints = nullptr;
    det.num_keypoints = 0;

    // 提取姿态模型的关键点（归一化坐标）。
    if (model_type == MODEL_TYPE_YOLO_POSE && num_keypoints > 0) {
      det.num_keypoints = num_keypoints;
      det.keypoints = (float *)malloc(num_keypoints * 3 * sizeof(float));
      if (!det.keypoints) {
        set_last_error(ONNX_ERROR_ALLOCATION_FAILED, "分配关键点内存失败");
        det.num_keypoints = 0;
      }

      int kpt_start = 4 + num_classes;
      for (int k = 0; k < num_keypoints && det.keypoints; k++) {
        float kp_x = output_data[(kpt_start + k * 3 + 0) * num_boxes + i];
        float kp_y = output_data[(kpt_start + k * 3 + 1) * num_boxes + i];
        float kp_v = output_data[(kpt_start + k * 3 + 2) * num_boxes + i];

        // 转换关键点为归一化坐标
        det.keypoints[k * 3 + 0] = (kp_x - pad_left) / scale_x / image_width;
        det.keypoints[k * 3 + 1] = (kp_y - pad_top) / scale_y / image_height;
        det.keypoints[k * 3 + 2] = kp_v;
      }
    }

    detections.push_back(det);
  }

  return detections;
}

// ============================================================================
// 推理
// ============================================================================

FFI_PLUGIN_EXPORT BatchDetectionResult *
onnx_detect_batch(ModelHandle handle, const uint8_t **image_data_list,
                  int num_images, int *image_widths, int *image_heights,
                  float conf_threshold, float nms_threshold, int model_type,
                  int num_keypoints) {
  // 批量推理：分配输入缓冲区并在返回前释放。
  clear_last_error();
  if (!handle || !image_data_list || num_images <= 0)
    return nullptr;
  if (!image_widths || !image_heights) {
    set_last_error(ONNX_ERROR_INVALID_ARGUMENT, "尺寸数组为空");
    return nullptr;
  }

  OnnxModel *model = (OnnxModel *)handle;
  int w = model->input_width;
  int h = model->input_height;
  size_t image_size = 3 * w * h;
  size_t batch_buffer_size = num_images * image_size * sizeof(float);

  // 分配批量输入缓冲区
  float *input_data = (float *)malloc(batch_buffer_size);
  if (!input_data) {
    set_last_error(ONNX_ERROR_ALLOCATION_FAILED, "分配输入缓冲区失败");
    return nullptr;
  }

  // 存储每张图片的缩放参数，供后处理使用
  std::vector<float> scales_x(num_images);
  std::vector<float> scales_y(num_images);
  std::vector<int> pads_left(num_images);
  std::vector<int> pads_top(num_images);

  // 预处理每张图片
  // TODO: 可并行化
  for (int i = 0; i < num_images; i++) {
    if (!image_data_list[i]) {
      free(input_data);
      set_last_error(ONNX_ERROR_INVALID_ARGUMENT, "image_data_list[%d] 为空",
                     i);
      return nullptr;
    }
    if (!validate_image_dimensions(image_widths[i], image_heights[i],
                                   "detect_batch")) {
      free(input_data);
      return nullptr;
    }

    float *img_buffer = input_data + i * image_size;
    preprocess_image_to_buffer(image_data_list[i], image_widths[i],
                               image_heights[i], w, h, img_buffer, &scales_x[i],
                               &scales_y[i], &pads_left[i], &pads_top[i]);
  }

  // 创建输入张量 [batch, 3, height, width]
  int64_t input_shape[] = {num_images, 3, h, w};
  OrtValue *input_tensor_raw = nullptr;
  OrtStatus *status = g_ort->CreateTensorWithDataAsOrtValue(
      model->memory_info, input_data, batch_buffer_size, input_shape, 4,
      ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &input_tensor_raw);

  if (!handle_status(status, "CreateTensorWithDataAsOrtValue")) {
    free(input_data);
    return nullptr;
  }
  OrtValuePtr input_tensor(input_tensor_raw);

  // 运行推理
  const char *input_names[] = {model->input_name};
  const char *output_names[] = {model->output_name};
  OrtValue *output_tensor_raw = nullptr;

  const OrtValue *input_tensor_ptr = input_tensor.get();
  status = g_ort->Run(model->session, nullptr, input_names,
                      &input_tensor_ptr, 1, output_names, 1,
                      &output_tensor_raw);

  free(input_data);

  if (!handle_status(status, "Run")) {
    return nullptr;
  }
  OrtValuePtr output_tensor(output_tensor_raw);

  // 获取输出数据（由 OrtValue 生命周期管理）。
  float *output_data;
  status =
      g_ort->GetTensorMutableData(output_tensor.get(), (void **)&output_data);
  if (!handle_status(status, "GetTensorMutableData")) {
    return nullptr;
  }

  // 获取输出形状
  OrtTensorTypeAndShapeInfo *output_info_raw = nullptr;
  status = g_ort->GetTensorTypeAndShape(output_tensor.get(), &output_info_raw);
  if (!handle_status(status, "GetTensorTypeAndShape")) {
    return nullptr;
  }
  OrtTensorInfoPtr output_info(output_info_raw);

  size_t dim_count;
  status = g_ort->GetDimensionsCount(output_info.get(), &dim_count);
  if (!handle_status(status, "GetDimensionsCount")) {
    return nullptr;
  }

  std::vector<int64_t> output_dims(dim_count);
  handle_status(g_ort->GetDimensions(output_info.get(), output_dims.data(),
                                     dim_count),
                "GetDimensions");

  // 解析结果并生成返回结构体（调用方需释放）。
  BatchDetectionResult *batch_result =
      (BatchDetectionResult *)malloc(sizeof(BatchDetectionResult));
  if (!batch_result) {
    set_last_error(ONNX_ERROR_ALLOCATION_FAILED, "分配 BatchDetectionResult 失败");
    return nullptr;
  }
  batch_result->num_images = num_images;
  batch_result->results =
      (DetectionResult *)malloc(num_images * sizeof(DetectionResult));
  if (!batch_result->results) {
    free(batch_result);
    set_last_error(ONNX_ERROR_ALLOCATION_FAILED,
                   "分配 DetectionResult 数组失败");
    return nullptr;
  }
  memset(batch_result->results, 0, num_images * sizeof(DetectionResult));

  if (dim_count >= 3 && output_dims[1] > 0 && output_dims[2] > 0) {
    // YOLOv8 输出格式: [batch, num_features, num_boxes]
    int num_features = (int)output_dims[1];
    int num_boxes = (int)output_dims[2];
    size_t stride_per_image = num_features * num_boxes;

    for (int i = 0; i < num_images; i++) {
      float *current_output = output_data + i * stride_per_image;

      std::vector<Detection> detections = parse_yolov8_output(
          current_output, num_features, num_boxes, model_type, num_keypoints,
          conf_threshold, scales_x[i], scales_y[i], pads_left[i], pads_top[i],
          image_widths[i], image_heights[i]);

      // 应用 NMS
      detections = onnx_nms(detections, nms_threshold);

      // 保存结果
      batch_result->results[i].count = (int)detections.size();
      batch_result->results[i].capacity = batch_result->results[i].count;
      if (batch_result->results[i].count > 0) {
        batch_result->results[i].detections = (Detection *)malloc(
            batch_result->results[i].count * sizeof(Detection));
        if (!batch_result->results[i].detections) {
          set_last_error(ONNX_ERROR_ALLOCATION_FAILED, "分配 Detection 失败");
          batch_result->results[i].count = 0;
          batch_result->results[i].capacity = 0;
          continue;
        }
        for (int k = 0; k < batch_result->results[i].count; k++) {
          batch_result->results[i].detections[k] = detections[k];
        }
      } else {
        batch_result->results[i].detections = nullptr;
      }
    }
  }

  return batch_result;
}

FFI_PLUGIN_EXPORT DetectionResult *
onnx_detect(ModelHandle handle, const uint8_t *image_data, int image_width,
            int image_height, float conf_threshold, float nms_threshold,
            int model_type, int num_keypoints) {
  // 单张推理：包装批量接口并转移检测结果指针所有权。
  clear_last_error();
  if (!image_data) {
    set_last_error(ONNX_ERROR_INVALID_ARGUMENT, "image_data 为空");
    return nullptr;
  }
  if (!validate_image_dimensions(image_width, image_height, "detect")) {
    return nullptr;
  }
  // 简单的包装器，调用批量接口
  const uint8_t *image_list[] = {image_data};
  int widths[] = {image_width};
  int heights[] = {image_height};

  BatchDetectionResult *batch_res =
      onnx_detect_batch(handle, image_list, 1, widths, heights, conf_threshold,
                        nms_threshold, model_type, num_keypoints);

  if (!batch_res)
    return nullptr;

  // 提取单个结果并释放外壳
  DetectionResult *single_res =
      (DetectionResult *)malloc(sizeof(DetectionResult));
  if (batch_res->results && batch_res->num_images > 0) {
    *single_res = batch_res->results[0]; // 浅拷贝结构体（指针所有权转移）
    // 清除原指针防止双重释放
    batch_res->results[0].detections = nullptr;
    batch_res->results[0].count = 0;
  } else {
    memset(single_res, 0, sizeof(DetectionResult));
  }

  onnx_free_batch_result(batch_res);
  return single_res;
}

FFI_PLUGIN_EXPORT void onnx_free_batch_result(BatchDetectionResult *result) {
  // 释放批量结果以及内部检测与关键点缓冲区。
  if (!result)
    return;
  if (result->results) {
    for (int i = 0; i < result->num_images; i++) {
      if (result->results[i].detections) {
        for (int k = 0; k < result->results[i].count; k++) {
          if (result->results[i].detections[k].keypoints) {
            free(result->results[i].detections[k].keypoints);
          }
        }
        free(result->results[i].detections);
      }
    }
    free(result->results);
  }
  free(result);
}

// onnx_free_result 改为只释放单个结果结构体
FFI_PLUGIN_EXPORT void onnx_free_result(DetectionResult *result) {
  // 释放单张结果以及内部关键点缓冲区。
  if (!result)
    return;
  if (result->detections) {
    // 释放每个检测结果的关键点
    for (int i = 0; i < result->count; i++) {
      if (result->detections[i].keypoints) {
        free(result->detections[i].keypoints);
      }
    }
    free(result->detections);
  }
  free(result);
}

FFI_PLUGIN_EXPORT const char *onnx_get_version(void) {
  clear_last_error();
  return "2.0.0-yolov8";
}

// ============================================================================
// GPU/设备检测
// ============================================================================

FFI_PLUGIN_EXPORT bool onnx_is_gpu_available(void) {
  clear_last_error();
  if (!g_initialized && !onnx_init()) {
    return false;
  }

  char **providers = nullptr;
  int num_providers = 0;

  OrtStatus *status = g_ort->GetAvailableProviders(&providers, &num_providers);
  if (!handle_status(status, "GetAvailableProviders")) {
    return false;
  }

  bool cuda_found = false;
  for (int i = 0; i < num_providers; i++) {
    if (strcmp(providers[i], "CUDAExecutionProvider") == 0) {
      cuda_found = true;
      break;
    }
  }

  handle_status(g_ort->ReleaseAvailableProviders(providers, num_providers),
                "ReleaseAvailableProviders");

  if (cuda_found) {
    OrtSessionOptions *session_options;
    status = g_ort->CreateSessionOptions(&session_options);
    if (!handle_status(status, "CreateSessionOptions")) {
      return false;
    }

    OrtCUDAProviderOptions cuda_options;
    memset(&cuda_options, 0, sizeof(cuda_options));
    cuda_options.device_id = 0;

    status = g_ort->SessionOptionsAppendExecutionProvider_CUDA(session_options,
                                                               &cuda_options);
    g_ort->ReleaseSessionOptions(session_options);

    if (!handle_status(status,
                       "SessionOptionsAppendExecutionProvider_CUDA")) {
      return false;
    }
    return true;
  }

  return false;
}

FFI_PLUGIN_EXPORT GpuInfo onnx_get_gpu_info(void) {
  clear_last_error();
  GpuInfo info;
  memset(&info, 0, sizeof(info));
  strcpy(info.device_name, "未知");

  if (!g_initialized && !onnx_init()) {
    return info;
  }

  char **providers = nullptr;
  int num_providers = 0;

  OrtStatus *status = g_ort->GetAvailableProviders(&providers, &num_providers);
  if (!handle_status(status, "GetAvailableProviders")) {
    return info;
  }

  for (int i = 0; i < num_providers; i++) {
    if (strcmp(providers[i], "CUDAExecutionProvider") == 0) {
      info.cuda_available = true;
    } else if (strcmp(providers[i], "TensorrtExecutionProvider") == 0) {
      info.tensorrt_available = true;
    } else if (strcmp(providers[i], "CoreMLExecutionProvider") == 0) {
      info.coreml_available = true;
    } else if (strcmp(providers[i], "DmlExecutionProvider") == 0) {
      info.directml_available = true;
    }
  }

  handle_status(g_ort->ReleaseAvailableProviders(providers, num_providers),
                "ReleaseAvailableProviders");

  if (info.cuda_available) {
    OrtSessionOptions *session_options;
    status = g_ort->CreateSessionOptions(&session_options);
    if (status == nullptr) {
      OrtCUDAProviderOptions cuda_options;
      memset(&cuda_options, 0, sizeof(cuda_options));
      cuda_options.device_id = 0;

      status = g_ort->SessionOptionsAppendExecutionProvider_CUDA(
          session_options, &cuda_options);
      if (status != nullptr) {
        info.cuda_available = false;
        handle_status(status,
                      "SessionOptionsAppendExecutionProvider_CUDA");
      } else {
        info.cuda_device_count = 1;
        strcpy(info.device_name, "NVIDIA GPU (CUDA)");
      }
      g_ort->ReleaseSessionOptions(session_options);
    }
  }

  // 设置设备名称
  if (info.tensorrt_available) {
    strcpy(info.device_name, "NVIDIA GPU (TensorRT)");
  } else if (info.cuda_available) {
    strcpy(info.device_name, "NVIDIA GPU (CUDA)");
  } else if (info.coreml_available) {
    strcpy(info.device_name, "Apple Neural Engine (CoreML)");
  } else if (info.directml_available) {
    strcpy(info.device_name, "GPU (DirectML)");
  } else {
    strcpy(info.device_name, "仅 CPU");
  }

  return info;
}

FFI_PLUGIN_EXPORT const char *onnx_get_available_providers(void) {
  // 返回线程局部缓冲区（调用方无需释放）。
  clear_last_error();
  static thread_local char providers_str[1024] = {0};
  providers_str[0] = '\0';

  if (!g_initialized && !onnx_init()) {
    strcpy(providers_str, "CPUExecutionProvider");
    return providers_str;
  }

  char **providers = nullptr;
  int num_providers = 0;

  OrtStatus *status = g_ort->GetAvailableProviders(&providers, &num_providers);
  if (!handle_status(status, "GetAvailableProviders")) {
    strcpy(providers_str, "CPUExecutionProvider");
    return providers_str;
  }

  for (int i = 0; i < num_providers; i++) {
    if (i > 0) {
      strcat(providers_str, ",");
    }
    if (strlen(providers_str) + strlen(providers[i]) + 2 <
        sizeof(providers_str)) {
      strcat(providers_str, providers[i]);
    }
  }

  handle_status(g_ort->ReleaseAvailableProviders(providers, num_providers),
                "ReleaseAvailableProviders");

  return providers_str;
}

FFI_PLUGIN_EXPORT const char *onnx_get_last_error(void) {
  return g_last_error;
}

FFI_PLUGIN_EXPORT int onnx_get_last_error_code(void) {
  return g_last_error_code;
}
#endif
