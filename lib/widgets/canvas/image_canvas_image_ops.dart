part of 'image_canvas.dart';

/// 图像加载与居中相关逻辑。
mixin _ImageCanvasImageOps on _ImageCanvasAccessors {
  // ==================== 图像操作 ====================

  /// 加载图像（使用 loadId 丢弃过期回调）。
  void _loadImage(String? path) async {
    final loadId = ++_imageLoadId;
    _twoClickFirstPoint = null;
    _imageLoadError = null;

    if (path == null) {
      if (!mounted) return;
      setState(() {
        _image = null;
        _imageLoading = false;
        _imageLoadError = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _imageLoading = true;
        _imageLoadError = null;
      });
    }

    try {
      final bytes = await _imageRepository.readBytes(path);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (!mounted || loadId != _imageLoadId || path != _currentImagePath) {
        return;
      }
      setState(() {
        _image = frame.image;
        _imageLoading = false;
        _imageLoadError = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || loadId != _imageLoadId || path != _currentImagePath) {
          return;
        }
        _centerImage();
      });
    } catch (e, stack) {
      final error = ErrorReporter.report(
        e,
        AppErrorCode.imageDecodeFailed,
        stackTrace: stack,
        details: 'load image: $path ($e)',
      );
      if (!mounted || loadId != _imageLoadId || path != _currentImagePath) {
        return;
      }
      setState(() {
        _image = null;
        _imageLoading = false;
        _imageLoadError = error;
      });
    }
  }

  /// 居中图像
  void _centerImage() {
    if (_image == null) return;

    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return;
    final viewportSize = viewportBox.size;

    final imageW = _image!.width.toDouble();
    final imageH = _image!.height.toDouble();

    final scaleX = viewportSize.width / imageW;
    final scaleY = viewportSize.height / imageH;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.95;

    final scaledW = imageW * scale;
    final scaledH = imageH * scale;

    final tx = (viewportSize.width - scaledW) / 2;
    final ty = (viewportSize.height - scaledH) / 2;

    final matrix = Matrix4.identity()
      ..scale(scale, scale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);

    _isCorrecting = true;
    _transformationController.value = matrix;
    _isCorrecting = false;
  }
}
