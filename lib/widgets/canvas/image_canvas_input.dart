part of 'image_canvas.dart';

/// 输入事件与点击/拖拽处理逻辑。
mixin _ImageCanvasInput on _ImageCanvasAccessors {
  // ==================== 指针事件处理 ====================

  /// 获取当前指针的全局坐标（优先使用追踪器）。
  Offset? _getCurrentPointerGlobalPosition() {
    if (_pointerTracker.lastGlobalPosition != null) {
      return _pointerTracker.lastGlobalPosition;
    }
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final screenPos = _screenMousePosition.value;
    if (viewportBox == null || screenPos == null) return null;
    return viewportBox.localToGlobal(screenPos);
  }

  /// 更新指针追踪器的当前位置。
  void _updateMouseMoved(Offset globalPosition) {
    _pointerTracker.update(globalPosition);
  }

  /// 同步指针追踪与屏幕坐标缓存。
  void _updatePointerTrackerAndScreen(Offset globalPosition) {
    _pointerTracker.update(globalPosition);
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox != null) {
      _screenMousePosition.value = viewportBox.globalToLocal(globalPosition);
    }
  }

  /// 将全局坐标转换为图像归一化坐标。
  Offset _normalizedFromGlobal(
    Offset globalPosition,
    CanvasProvider canvasProvider, {
    bool? clamp,
  }) {
    return _normalizePosition(
      _globalToImageLocal(globalPosition),
      clamp: clamp ?? canvasProvider.isLabelingMode,
    );
  }

  /// 根据全局坐标更新本地归一化鼠标位置。
  void _updateLocalMouseFromGlobal(
    Offset globalPosition,
    CanvasProvider canvasProvider, {
    bool? clamp,
  }) {
    _localMousePosition.value =
        _normalizedFromGlobal(globalPosition, canvasProvider, clamp: clamp);
  }
  // ==================== 点击事件处理 ====================

  /// 处理删除点击（点/标签/多边形闭合）。
  void _onDeleteClick(
    TapUpDetails details,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    if (_image == null) return;

    final rawNormalized =
        _normalizePosition(details.localPosition, clamp: false);
    if (canvasProvider.isLabelingMode && !_isNormalizedInImage(rawNormalized)) {
      return;
    }

    if (canvasProvider.isLabelingMode &&
        canvasProvider.isCreatingPolygon &&
        canvasProvider.currentPolygonPoints.length > 2) {
      _finalizePolygon(canvasProvider, projectProvider);
      return;
    }

    final normalized = _normalizePosition(
      details.localPosition,
      clamp: canvasProvider.isLabelingMode,
    );

    // 优先检查点
    final hitPoint = _findKeypointAt(normalized, projectProvider.labels);
    if (hitPoint != null) {
      _deleteKeypoint(hitPoint, canvasProvider, projectProvider);
      return;
    }

    // 检查标签主体
    final labelIndex = _findLabelAt(normalized, projectProvider.labels);
    if (labelIndex != null) {
      projectProvider.removeLabel(labelIndex);
      canvasProvider.selectLabel(null);
    }
  }

  /// 删除关键点（必要时移除多边形标签）。
  void _deleteKeypoint(HitKeypoint hitPoint, CanvasProvider canvasProvider,
      ProjectProvider projectProvider) {
    final label = projectProvider.labels[hitPoint.labelIndex];
    if (hitPoint.pointIndex < label.points.length) {
      final newPoints = List<LabelPoint>.from(label.points);
      newPoints.removeAt(hitPoint.pointIndex);

      final definitions = projectProvider.labelDefinitions;
      final isPolygon = label.id < definitions.length &&
          definitions[label.id].type == LabelType.polygon;

      if (isPolygon && newPoints.length < 3) {
        projectProvider.removeLabel(hitPoint.labelIndex);
        canvasProvider.selectLabel(null);
      } else {
        final newLabel = label.copyWith(points: newPoints);
        if (isPolygon) {
          newLabel.updateBboxFromPoints();
        }
        projectProvider.updateLabel(hitPoint.labelIndex, newLabel);
      }
    }
  }

  /// 处理创建点击（标注模式新增、非标注模式选择）。
  void _onCreateClick(TapUpDetails details, CanvasProvider canvasProvider,
      ProjectProvider projectProvider, SettingsProvider settingsProvider) {
    if (_image == null) return;
    final rawNormalized =
        _normalizePosition(details.localPosition, clamp: false);
    if (canvasProvider.isLabelingMode && !_isNormalizedInImage(rawNormalized)) {
      return;
    }
    final normalized = _normalizePosition(
      details.localPosition,
      clamp: canvasProvider.isLabelingMode,
    );

    if (canvasProvider.isLabelingMode) {
      final labelType = _getCurrentLabelType(projectProvider, canvasProvider);

      // 两次点击模式处理
      if (settingsProvider.isTwoClickMode &&
          (labelType == LabelType.box || labelType == LabelType.boxWithPoint)) {
        _handleTwoClickBoxCreation(normalized, canvasProvider, projectProvider);
        return;
      }

      if (labelType == LabelType.boxWithPoint) {
        if (!settingsProvider.isTwoClickMode) {
          _addKeypointToBox(normalized, canvasProvider, projectProvider);
        }
        return;
      } else if (labelType == LabelType.polygon) {
        _handlePolygonPointAdd(
          normalized,
          details.globalPosition,
          canvasProvider,
          projectProvider,
          settingsProvider,
        );
        return;
      }
    } else {
      // 普通模式：选择
      final labels = projectProvider.labels;
      final imageSize =
          Size(_image!.width.toDouble(), _image!.height.toDouble());
      final hoverResult = CanvasHoverResolver(
        labels: labels,
        imageSize: imageSize,
        selectedLabelIndex: canvasProvider.selectedLabelIndex,
        getLabelDefinition: projectProvider.getLabelDefinition,
        findKeypointAt: (pos) => _findKeypointAt(pos, labels),
        findHandleAt: (pos, label) => _findHandleAt(pos, label, imageSize),
        findLabelAt: (pos) => _findLabelAt(pos, labels),
      ).resolve(normalized);

      applyEditModeSelection(
        canvasProvider: canvasProvider,
        hoverResult: hoverResult,
      );
    }
  }

  /// 处理两次点击框创建（首点记录 + 第二点完成）。
  void _handleTwoClickBoxCreation(Offset normalized,
      CanvasProvider canvasProvider, ProjectProvider projectProvider) {
    if (_twoClickFirstPoint == null) {
      _twoClickFirstPoint = normalized;
      canvasProvider.clearSelection();
      canvasProvider.tryStartDrawing(normalized);
    } else {
      final firstPoint = _twoClickFirstPoint!;
      _twoClickFirstPoint = null;

      final rect = Rect.fromPoints(firstPoint, normalized);
      if (rect.width > 0.01 && rect.height > 0.01) {
        final label = projectProvider.createLabelFromRect(
          canvasProvider.currentClassId,
          rect,
        );
        projectProvider.addLabel(label);
        canvasProvider.selectLabel(projectProvider.labels.length - 1);
      }
      canvasProvider.cancelInteraction();
    }
  }

  /// 处理多边形点添加（靠近起点时闭合）。
  void _handlePolygonPointAdd(
    Offset normalized,
    Offset globalPosition,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
  ) {
    // 检查是否接近起点以闭合
    if (canvasProvider.currentPolygonPoints.length > 2) {
      final image = _image;
      if (image == null) return;
      final start = canvasProvider.currentPolygonPoints.first;
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final threshold = settingsProvider.pointHitRadius;

      final viewportBox =
          _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (viewportBox != null) {
        final startPx =
            Offset(start.dx * imageSize.width, start.dy * imageSize.height);
        final currentViewport = viewportBox.globalToLocal(globalPosition);
        final startViewport = _imageLocalToViewport(startPx);
        final dist = (currentViewport - startViewport).distance;
        if (dist < threshold) {
          _finalizePolygon(canvasProvider, projectProvider);
          return;
        }
      }

      final scale = _transformationController.value.entry(0, 0);
      if (scale > 0) {
        final normalizedThreshold =
            threshold / (imageSize.shortestSide * scale);
        if ((normalized - start).distance < normalizedThreshold) {
          _finalizePolygon(canvasProvider, projectProvider);
          return;
        }
      }
    }

    // 检查点距离
    for (final p in canvasProvider.currentPolygonPoints) {
      if ((p - normalized).distance < 0.005) return;
    }

    canvasProvider.addPolygonPoint(normalized);
  }

  // ==================== 拖拽事件处理 ====================

  /// 编辑模式拖拽开始
  void _handleEditModePanStart(Offset normalized, CanvasProvider canvasProvider,
      ProjectProvider projectProvider) {
    _resetResizeState();
    final labels = projectProvider.labels;
    final definitions = projectProvider.labelDefinitions;
    final imageSize = Size(_image!.width.toDouble(), _image!.height.toDouble());
    final localPos = Offset(
        normalized.dx * imageSize.width, normalized.dy * imageSize.height);
    EditModeDragStartHandler(
      canvasProvider: canvasProvider,
      projectProvider: projectProvider,
      labels: labels,
      definitions: definitions,
      imageSize: imageSize,
      normalized: normalized,
      localPos: localPos,
      findKeypointAt: (pos) => _findKeypointAt(pos, labels),
      findHandleAt: (pos, label) => _findHandleAt(pos, label, imageSize),
      findEdgeAt: (pos, label) => _findEdgeAt(pos, label, imageSize),
      findLabelAt: (pos) => _findLabelAt(pos, labels),
      setResizeStartRect: (rect) => _resizeStartRect = rect,
    ).run();
  }
}
