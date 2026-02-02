/**
 * ONNX 推理插件工具测试
 */
#include "onnx_inference_utils.h"

#include <cassert>
#include <cmath>
#include <iostream>

static bool nearly_equal(float a, float b, float eps = 1e-4f) {
  // 简单的浮点比较辅助。
  return std::fabs(a - b) <= eps;
}

static Detection make_det(int class_id, float conf, float x, float y, float w,
                          float h) {
  // 构建一个不包含关键点的检测结果。
  Detection det{};
  det.class_id = class_id;
  det.confidence = conf;
  det.x = x;
  det.y = y;
  det.width = w;
  det.height = h;
  det.keypoints = nullptr;
  det.num_keypoints = 0;
  return det;
}

static void test_iou_identical() {
  Detection a = make_det(0, 0.9f, 0.5f, 0.5f, 0.4f, 0.4f);
  Detection b = make_det(0, 0.8f, 0.5f, 0.5f, 0.4f, 0.4f);
  float v = onnx_iou(a, b);
  assert(nearly_equal(v, 1.0f));
}

static void test_iou_no_overlap() {
  Detection a = make_det(0, 0.9f, 0.1f, 0.1f, 0.1f, 0.1f);
  Detection b = make_det(0, 0.8f, 0.9f, 0.9f, 0.1f, 0.1f);
  float v = onnx_iou(a, b);
  assert(nearly_equal(v, 0.0f));
}

static void test_iou_partial_overlap() {
  Detection a = make_det(0, 0.9f, 0.5f, 0.5f, 0.4f, 0.4f);
  Detection b = make_det(0, 0.8f, 0.6f, 0.6f, 0.4f, 0.4f);
  float v = onnx_iou(a, b);
  assert(v > 0.0f);
  assert(v < 1.0f);
}

static void test_iou_zero_area() {
  Detection a = make_det(0, 0.9f, 0.5f, 0.5f, 0.0f, 0.4f);
  Detection b = make_det(0, 0.8f, 0.5f, 0.5f, 0.4f, 0.4f);
  float v = onnx_iou(a, b);
  assert(nearly_equal(v, 0.0f));
}

static void test_nms_same_class() {
  std::vector<Detection> dets;
  dets.push_back(make_det(1, 0.9f, 0.5f, 0.5f, 0.4f, 0.4f));
  dets.push_back(make_det(1, 0.8f, 0.52f, 0.52f, 0.4f, 0.4f));
  auto filtered = onnx_nms(dets, 0.3f);
  assert(filtered.size() == 1);
  assert(nearly_equal(filtered[0].confidence, 0.9f));
}

static void test_nms_empty() {
  std::vector<Detection> dets;
  auto filtered = onnx_nms(dets, 0.3f);
  assert(filtered.empty());
}

static void test_nms_sorting() {
  std::vector<Detection> dets;
  dets.push_back(make_det(1, 0.2f, 0.5f, 0.5f, 0.2f, 0.2f));
  dets.push_back(make_det(1, 0.8f, 0.5f, 0.5f, 0.2f, 0.2f));
  dets.push_back(make_det(1, 0.5f, 0.5f, 0.5f, 0.2f, 0.2f));
  auto filtered = onnx_nms(dets, 0.0f);
  assert(filtered.size() == 1);
  assert(nearly_equal(filtered[0].confidence, 0.8f));
}

static void test_nms_diff_class() {
  std::vector<Detection> dets;
  dets.push_back(make_det(1, 0.9f, 0.5f, 0.5f, 0.4f, 0.4f));
  dets.push_back(make_det(2, 0.8f, 0.5f, 0.5f, 0.4f, 0.4f));
  auto filtered = onnx_nms(dets, 0.3f);
  assert(filtered.size() == 2);
}

int main() {
  test_iou_identical();
  test_iou_no_overlap();
  test_iou_partial_overlap();
  test_iou_zero_area();
  test_nms_same_class();
  test_nms_empty();
  test_nms_sorting();
  test_nms_diff_class();
  std::cout << "onnx_inference_utils_test passed\n";
  return 0;
}
