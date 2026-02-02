/**
 * ONNX 推理插件内部工具实现
 */
#include "onnx_inference_utils.h"

#include <algorithm>

// IoU 计算基于中心点与宽高坐标。
float onnx_iou(const Detection &a, const Detection &b) {
  float a_x1 = a.x - a.width / 2;
  float a_y1 = a.y - a.height / 2;
  float a_x2 = a.x + a.width / 2;
  float a_y2 = a.y + a.height / 2;

  float b_x1 = b.x - b.width / 2;
  float b_y1 = b.y - b.height / 2;
  float b_x2 = b.x + b.width / 2;
  float b_y2 = b.y + b.height / 2;

  float inter_x1 = std::max(a_x1, b_x1);
  float inter_y1 = std::max(a_y1, b_y1);
  float inter_x2 = std::min(a_x2, b_x2);
  float inter_y2 = std::min(a_y2, b_y2);

  float inter_w = std::max(0.0f, inter_x2 - inter_x1);
  float inter_h = std::max(0.0f, inter_y2 - inter_y1);
  float inter_area = inter_w * inter_h;

  float a_area = a.width * a.height;
  float b_area = b.width * b.height;
  float union_area = a_area + b_area - inter_area;

  return union_area > 0 ? inter_area / union_area : 0;
}

std::vector<Detection> onnx_nms(std::vector<Detection> detections,
                                float threshold) {
  // 按置信度降序排序（确保稳定的筛选优先级）。
  std::sort(detections.begin(), detections.end(),
            [](const Detection &a, const Detection &b) {
              return a.confidence > b.confidence;
            });

  std::vector<bool> suppressed(detections.size(), false);
  std::vector<Detection> result;

  for (size_t i = 0; i < detections.size(); i++) {
    if (suppressed[i])
      continue;

    result.push_back(detections[i]);

    // 抑制同类别中 IoU 大于阈值的检测框
    for (size_t j = i + 1; j < detections.size(); j++) {
      if (!suppressed[j] && detections[i].class_id == detections[j].class_id) {
        if (onnx_iou(detections[i], detections[j]) > threshold) {
          suppressed[j] = true;
        }
      }
    }
  }

  return result;
}
