import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:label_load/services/image/image_preview_provider.dart';

void main() {
  test('FileImagePreviewProvider returns FileImage with path', () {
    const path = '/tmp/sample.jpg';
    const provider = FileImagePreviewProvider();

    final imageProvider = provider.create(path);

    expect(imageProvider, isA<FileImage>());
    final fileImage = imageProvider as FileImage;
    expect(fileImage.file.path, path);
  });
}
