/// GPU 能力描述
///
/// 由推理引擎提供，用于判断是否可启用硬件加速。
class GpuInfo {
  /// 是否检测到 CUDA 可用。
  final bool cudaAvailable;

  /// 是否检测到 TensorRT 可用。
  final bool tensorrtAvailable;

  /// 是否检测到 CoreML 可用。
  final bool coremlAvailable;

  /// 是否检测到 DirectML 可用。
  final bool directmlAvailable;

  /// GPU 设备名称（若可用）。
  final String deviceName;

  /// CUDA 设备数量（若可用）。
  final int cudaDeviceCount;

  const GpuInfo({
    required this.cudaAvailable,
    required this.tensorrtAvailable,
    required this.coremlAvailable,
    required this.directmlAvailable,
    required this.deviceName,
    required this.cudaDeviceCount,
  });

  /// 是否有任意 GPU 加速能力可用。
  bool get isGpuAvailable =>
      cudaAvailable ||
      tensorrtAvailable ||
      coremlAvailable ||
      directmlAvailable;

  @override
  String toString() =>
      'GpuInfo(cuda=$cudaAvailable, tensorrt=$tensorrtAvailable, '
      'coreml=$coremlAvailable, directml=$directmlAvailable, '
      'device=$deviceName, cudaDevices=$cudaDeviceCount)';
}
