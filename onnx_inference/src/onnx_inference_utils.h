/**
 * ONNX 推理插件内部工具
 *
 * 提供可测试的纯计算逻辑（不依赖 ONNX Runtime）。
 */
#ifndef ONNX_INFERENCE_UTILS_H
#define ONNX_INFERENCE_UTILS_H

#include "onnx_inference.h"

#include <vector>

/// 计算两个检测框的 IoU（使用中心点与宽高）。
///
/// Detection 中的坐标为归一化中心点 (x, y) 与宽高 (w, h)。
float onnx_iou(const Detection &a, const Detection &b);

/// 执行按类别的非极大值抑制（NMS）。
///
/// 同类别框之间 IoU 大于阈值会被抑制。
/// 返回结果按置信度从高到低排序。
std::vector<Detection> onnx_nms(std::vector<Detection> detections,
                                float threshold);

#endif // ONNX_INFERENCE_UTILS_H
