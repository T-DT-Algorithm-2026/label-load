/**
 * ONNX 推理插件头文件
 *
 * 为 Flutter 提供基于 ONNX Runtime 的 YOLOv8 目标检测功能。
 */

#ifndef ONNX_INFERENCE_H
#define ONNX_INFERENCE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

// ============================================================================
// 数据结构
// ============================================================================

/// 错误码
typedef enum {
  ONNX_OK = 0,
  ONNX_ERROR_UNKNOWN = 1,
  ONNX_ERROR_NOT_INITIALIZED = 2,
  ONNX_ERROR_INVALID_ARGUMENT = 3,
  ONNX_ERROR_ALLOCATION_FAILED = 4,
  ONNX_ERROR_RUNTIME_FAILURE = 5,
  ONNX_ERROR_RUNTIME_NOT_FOUND = 6
} OnnxErrorCode;

/// 检测结果结构体
///
/// 坐标为归一化中心点 (x, y) 与宽高 (width, height)。
typedef struct {
  int class_id;      // 类别 ID
  float confidence;  // 置信度
  float x;           // 中心 x 坐标（归一化 0-1）
  float y;           // 中心 y 坐标（归一化 0-1）
  float width;       // 宽度（归一化 0-1）
  float height;      // 高度（归一化 0-1）
  float *keypoints;  // 关键点数组 (x, y, visibility) * num_keypoints
  int num_keypoints; // 关键点数量（非姿态模型为 0）
} Detection;

/// 检测结果数组
typedef struct {
  Detection *detections;
  int count;
  int capacity;
} DetectionResult;

/// 模型类型枚举
typedef enum {
  MODEL_TYPE_YOLO = 0,     // 标准 YOLO 检测
  MODEL_TYPE_YOLO_POSE = 1 // YOLO-Pose（关键点检测）
} ModelType;

/// 模型句柄（不透明指针）
/// 注意：同一 ModelHandle 不保证线程安全，请在单线程内使用。
typedef void *ModelHandle;

// ============================================================================
// 初始化/清理
// ============================================================================

/// 初始化 ONNX Runtime
FFI_PLUGIN_EXPORT bool onnx_init(void);

/// 清理 ONNX Runtime
FFI_PLUGIN_EXPORT void onnx_cleanup(void);

// ============================================================================
// 模型操作
// ============================================================================

/// 加载 ONNX 模型
/// @param model_path 模型文件路径
/// @param use_gpu 是否使用 GPU 加速
/// @return 成功返回模型句柄，失败返回 NULL
FFI_PLUGIN_EXPORT ModelHandle onnx_load_model(const char *model_path,
                                              bool use_gpu);

/// 卸载模型
/// 允许传入 NULL（无操作）。
FFI_PLUGIN_EXPORT void onnx_unload_model(ModelHandle handle);

/// 获取模型输入尺寸
/// @param handle 模型句柄
/// @param width 输出参数：宽度
/// @param height 输出参数：高度
/// @return 成功返回 true
FFI_PLUGIN_EXPORT bool onnx_get_input_size(ModelHandle handle, int *width,
                                           int *height);

// ============================================================================
// 推理
// ============================================================================

/// 运行推理
/// @param handle 模型句柄
/// @param image_data RGBA 像素数据（width * height * 4 字节）
/// @param image_width 原始图像宽度
/// @param image_height 原始图像高度
/// @param conf_threshold 置信度阈值 (0.0-1.0)
/// @param nms_threshold NMS IoU 阈值 (0.0-1.0)
/// @param model_type 模型类型
/// @param num_keypoints 姿态模型关键点数量（如 COCO 为 17）
/// @return 堆分配的 DetectionResult，调用方需使用 onnx_free_result 释放
FFI_PLUGIN_EXPORT DetectionResult *
onnx_detect(ModelHandle handle, const uint8_t *image_data, int image_width,
            int image_height, float conf_threshold, float nms_threshold,
            int model_type, int num_keypoints);

/// 释放检测结果
/// 释放 DetectionResult 及其内部关键点缓冲区。
FFI_PLUGIN_EXPORT void onnx_free_result(DetectionResult *result);

/// 获取版本字符串
FFI_PLUGIN_EXPORT const char *onnx_get_version(void);

/// 获取最近一次错误信息（线程局部）
/// 返回静态缓冲区，调用方无需释放
FFI_PLUGIN_EXPORT const char *onnx_get_last_error(void);

/// 获取最近一次错误码（线程局部）
FFI_PLUGIN_EXPORT int onnx_get_last_error_code(void);

// ============================================================================
// GPU/设备检测
// ============================================================================

/// GPU 信息结构体
typedef struct {
  bool cuda_available;     // CUDA (NVIDIA) 是否可用
  bool tensorrt_available; // TensorRT 是否可用
  bool coreml_available;   // CoreML (Apple) 是否可用
  bool directml_available; // DirectML (Windows) 是否可用
  char device_name[256];   // GPU 设备名称
  int cuda_device_count;   // CUDA 设备数量
} GpuInfo;

/// 检查 GPU 是否可用
FFI_PLUGIN_EXPORT bool onnx_is_gpu_available(void);

/// 获取详细 GPU 信息
FFI_PLUGIN_EXPORT GpuInfo onnx_get_gpu_info(void);

/// 获取可用执行提供程序（逗号分隔字符串）
/// 返回静态缓冲区，调用方无需释放
FFI_PLUGIN_EXPORT const char *onnx_get_available_providers(void);

/// 批量检测结果
typedef struct {
  DetectionResult *results; // 结果数组，长度为 num_images
  int num_images;           // 图片数量
} BatchDetectionResult;

/// 运行批量推理
/// @param handle 模型句柄
/// @param image_data_list RGBA 像素数据指针数组
/// @param num_images 图片数量
/// @param image_widths 原始图像宽度数组
/// @param image_heights 原始图像高度数组
/// @param conf_threshold 置信度阈值 (0.0-1.0)
/// @param nms_threshold NMS IoU 阈值 (0.0-1.0)
/// @param model_type 模型类型
/// @param num_keypoints 姿态模型关键点数量
/// @return 堆分配的 BatchDetectionResult，需使用 onnx_free_batch_result 释放
FFI_PLUGIN_EXPORT BatchDetectionResult *
onnx_detect_batch(ModelHandle handle, const uint8_t **image_data_list,
                  int num_images, int *image_widths, int *image_heights,
                  float conf_threshold, float nms_threshold, int model_type,
                  int num_keypoints);

/// 释放批量检测结果
/// 释放 BatchDetectionResult 及其内部检测缓冲区。
FFI_PLUGIN_EXPORT void onnx_free_batch_result(BatchDetectionResult *result);

#ifdef __cplusplus
}
#endif

#endif // ONNX_INFERENCE_H
