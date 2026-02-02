part of 'image_canvas.dart';

/// 变换、约束与自动平移相关逻辑。
mixin _ImageCanvasTransform on _ImageCanvasAccessors {
  // ==================== 变换和坐标 ====================

  /// 变换改变监听（非自动修正时触发边界约束）。
  void _onTransformationChange() {
    if (_isCorrecting) return;
    _enforceConstraints();
  }

  /// 强制约束变换，避免图像移出视口过远。
  void _enforceConstraints() {
    if (_image == null) return;

    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return;
    final viewportSize = viewportBox.size;

    final transform = _transformationController.value;
    final scale = transform.entry(0, 0);
    final tx = transform.entry(0, 3);
    final ty = transform.entry(1, 3);

    final scaledW = _image!.width * scale;
    final scaledH = _image!.height * scale;

    var newTx = tx;
    var newTy = ty;

    final marginX = viewportSize.width / 2;
    final minTx = marginX - scaledW;
    final maxTx = marginX;
    newTx = tx.clamp(minTx, maxTx);

    final marginY = viewportSize.height / 2;
    final minTy = marginY - scaledH;
    final maxTy = marginY;
    newTy = ty.clamp(minTy, maxTy);

    if ((newTx - tx).abs() > 0.001 || (newTy - ty).abs() > 0.001) {
      _isCorrecting = true;
      transform.setEntry(0, 3, newTx);
      transform.setEntry(1, 3, newTy);
      _transformationController.value = transform;
      _isCorrecting = false;
    }
  }

  /// 应用约束平移并返回是否实际移动。
  bool _applyClampedTranslation(double dx, double dy) {
    if (_image == null) return false;

    final transform = _transformationController.value;
    final scale = transform.entry(0, 0);
    final tx = transform.entry(0, 3);
    final ty = transform.entry(1, 3);

    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return false;
    final viewportSize = viewportBox.size;

    final scaledW = _image!.width * scale;
    final scaledH = _image!.height * scale;

    var newTx = tx + dx;
    final marginX = viewportSize.width / 2;
    final minTx = marginX - scaledW;
    final maxTx = marginX;
    newTx = newTx.clamp(minTx, maxTx);

    var newTy = ty + dy;
    final marginY = viewportSize.height / 2;
    final minTy = marginY - scaledH;
    final maxTy = marginY;
    newTy = newTy.clamp(minTy, maxTy);

    if ((newTx - tx).abs() > 0.001 || (newTy - ty).abs() > 0.001) {
      transform.setEntry(0, 3, newTx);
      transform.setEntry(1, 3, newTy);
      _transformationController.value = transform;
      if (mounted) setState(() {});
      return true;
    }
    return false;
  }

  /// 检查是否需要自动平移（指针接近边缘时触发）。
  void _checkForAutoPan(Offset globalPosition) {
    final renderBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportSize = renderBox.size;
    final local = renderBox.globalToLocal(globalPosition);

    final transform = _transformationController.value;
    final scale = transform.entry(0, 0);
    if (_image == null) return;

    final scaledW = _image!.width * scale;
    final scaledH = _image!.height * scale;

    const double margin = 100.0;
    double dx = 0;
    double dy = 0;

    double calculateSpeed(double dist) {
      final factor = (1.0 - (dist / margin)).clamp(0.0, 1.0);
      return 5.0 + (factor * 20.0);
    }

    if (scaledW > viewportSize.width) {
      if (local.dx < margin) {
        dx = calculateSpeed(local.dx);
      } else if (local.dx > viewportSize.width - margin) {
        dx = -calculateSpeed(viewportSize.width - local.dx);
      }
    }

    if (scaledH > viewportSize.height) {
      if (local.dy < margin) {
        dy = calculateSpeed(local.dy);
      } else if (local.dy > viewportSize.height - margin) {
        dy = -calculateSpeed(viewportSize.height - local.dy);
      }
    }

    if (dx != 0 || dy != 0) {
      if (_autoPanTimer == null || !_autoPanTimer!.isActive) {
        _autoPanTimer =
            Timer.periodic(const Duration(milliseconds: 16), (timer) {
          _performAutoPan(dx, dy);
        });
      }
      _autoPanVelocity = Offset(dx, dy);
    } else {
      _autoPanTimer?.cancel();
      _autoPanTimer = null;
      _autoPanVelocity = Offset.zero;
    }
  }

  /// 执行自动平移，并在交互中同步标签更新。
  void _performAutoPan(double dx, double dy) {
    if (_autoPanVelocity == Offset.zero) return;
    if (_image == null) return;

    final currentV = _autoPanVelocity;
    if (currentV == Offset.zero) return;

    final moved = _applyClampedTranslation(currentV.dx, currentV.dy);

    if (moved && _lastGlobalPosition != null) {
      final canvasProvider = context.read<CanvasProvider>();
      final mode = canvasProvider.interactionMode;
      final imageLocal = _globalToImageLocal(_lastGlobalPosition!);
      final normalized = _normalizePosition(
        imageLocal,
        clamp: canvasProvider.isLabelingMode,
      );

      _localMousePosition.value = normalized;

      if (mode == InteractionMode.moving ||
          mode == InteractionMode.resizing ||
          mode == InteractionMode.movingKeypoint) {
        final projectProvider = context.read<ProjectProvider>();
        if (mode == InteractionMode.moving) {
          _handleMove(normalized, canvasProvider, projectProvider,
              parentOnly: !_isCtrlPressed);
        } else if (mode == InteractionMode.resizing) {
          _handleResize(normalized, canvasProvider, projectProvider);
        } else if (mode == InteractionMode.movingKeypoint) {
          _handleMoveKeypoint(normalized, canvasProvider, projectProvider);
        }
      } else if (canvasProvider.isCreatingPolygon) {
        _localMousePosition.value = normalized;
      } else if (canvasProvider.drawStart != null) {
        canvasProvider.updateDrag(normalized);
      }
    }
  }

  /// 全局坐标转图像本地坐标
  @override
  Offset _globalToImageLocal(Offset global) {
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return Offset.zero;
    final viewportLocal = viewportBox.globalToLocal(global);

    final transform = _transformationController.value;
    final inverted = Matrix4.tryInvert(transform);
    if (inverted == null) return Offset.zero;

    final point =
        inverted.transform3(Vector3(viewportLocal.dx, viewportLocal.dy, 0));
    return Offset(point.x, point.y);
  }

  @override
  Offset _imageLocalToViewport(Offset imageLocal) {
    final transform = _transformationController.value;
    final point =
        transform.transform3(Vector3(imageLocal.dx, imageLocal.dy, 0));
    return Offset(point.x, point.y);
  }

  /// 归一化位置
  @override
  Offset _normalizePosition(Offset localPosition, {bool clamp = true}) {
    if (_image == null) return Offset.zero;
    final dx = localPosition.dx / _image!.width;
    final dy = localPosition.dy / _image!.height;
    if (!clamp) return Offset(dx, dy);
    return Offset(dx.clamp(0.0, 1.0), dy.clamp(0.0, 1.0));
  }

  bool _isPointerInImage(Offset globalPosition) {
    if (_image == null) return false;
    final local = _globalToImageLocal(globalPosition);
    return local.dx >= 0 &&
        local.dx <= _image!.width &&
        local.dy >= 0 &&
        local.dy <= _image!.height;
  }

  @override
  bool _isNormalizedInImage(Offset normalized) {
    return normalized.dx >= 0 &&
        normalized.dx <= 1 &&
        normalized.dy >= 0 &&
        normalized.dy <= 1;
  }
}
