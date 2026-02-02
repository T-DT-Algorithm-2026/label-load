import 'dart:io';
import 'package:flutter/widgets.dart';

/// Creates lightweight [ImageProvider]s for preview usage.
abstract class ImagePreviewProvider {
  /// Builds an [ImageProvider] for the image at [path].
  ImageProvider<Object> create(String path);
}

/// File-system backed [ImagePreviewProvider].
class FileImagePreviewProvider implements ImagePreviewProvider {
  const FileImagePreviewProvider();

  @override
  ImageProvider<Object> create(String path) {
    return FileImage(File(path));
  }
}
