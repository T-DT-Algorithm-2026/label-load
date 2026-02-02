/// 设置数值的校验与归一化工具。
class SettingsValidator {
  /// 限制最小缩放比例范围。
  static double clampMinScale(double value) =>
      value.clamp(0.05, 0.5).toDouble();

  /// 限制最大缩放比例范围。
  static double clampMaxScale(double value) =>
      value.clamp(1.0, 20.0).toDouble();

  /// 限制点尺寸范围。
  static double clampPointSize(double value) =>
      value.clamp(3.0, 15.0).toDouble();

  /// 限制点命中半径范围。
  static double clampPointHitRadius(double value) =>
      value.clamp(5.0, 200.0).toDouble();

  /// 校验并规范化缩放区间。
  ///
  /// 当 [minScale] >= [maxScale] 时，返回默认值。
  static (double min, double max) normalizeScaleRange(
    double minScale,
    double maxScale, {
    required double defaultMin,
    required double defaultMax,
  }) {
    if (minScale >= maxScale) {
      return (defaultMin, defaultMax);
    }
    return (minScale, maxScale);
  }
}
