import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/gpu/gpu_info.dart';

void main() {
  test('GpuInfo isGpuAvailable reflects any available backend', () {
    const none = GpuInfo(
      cudaAvailable: false,
      tensorrtAvailable: false,
      coremlAvailable: false,
      directmlAvailable: false,
      deviceName: '',
      cudaDeviceCount: 0,
    );
    expect(none.isGpuAvailable, isFalse);

    const cuda = GpuInfo(
      cudaAvailable: true,
      tensorrtAvailable: false,
      coremlAvailable: false,
      directmlAvailable: false,
      deviceName: 'GPU',
      cudaDeviceCount: 1,
    );
    expect(cuda.isGpuAvailable, isTrue);

    const coreml = GpuInfo(
      cudaAvailable: false,
      tensorrtAvailable: false,
      coremlAvailable: true,
      directmlAvailable: false,
      deviceName: 'Apple',
      cudaDeviceCount: 0,
    );
    expect(coreml.isGpuAvailable, isTrue);
  });

  test('GpuInfo toString includes key fields', () {
    const info = GpuInfo(
      cudaAvailable: true,
      tensorrtAvailable: true,
      coremlAvailable: false,
      directmlAvailable: false,
      deviceName: 'RTX',
      cudaDeviceCount: 2,
    );

    final text = info.toString();
    expect(text, contains('cuda=true'));
    expect(text, contains('tensorrt=true'));
    expect(text, contains('device=RTX'));
    expect(text, contains('cudaDevices=2'));
  });
}
