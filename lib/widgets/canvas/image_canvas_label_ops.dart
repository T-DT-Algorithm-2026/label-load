part of 'image_canvas.dart';

/// 标签编辑与命中检测相关逻辑。
mixin _ImageCanvasLabelOps on _ImageCanvasAccessors {
  // ==================== 标签操作 ====================

  /// 完成多边形
  @override
  void _finalizePolygon(
      CanvasProvider canvasProvider, ProjectProvider projectProvider) {
    _autoPanTimer?.cancel();
    _autoPanTimer = null;

    final points = canvasProvider.currentPolygonPoints;
    if (points.length < 3) return;

    final label = Label(
      id: canvasProvider.currentClassId,
      name: projectProvider.labelNameForClass(canvasProvider.currentClassId),
    );

    final labelPoints =
        points.map((p) => LabelPoint(x: p.dx, y: p.dy)).toList();
    final newLabel = label.copyWith(points: labelPoints);
    newLabel.updateBboxFromPoints();

    projectProvider.addLabel(newLabel);
    canvasProvider.selectLabel(projectProvider.labels.length - 1);
    canvasProvider.resetPolygon();
  }

  /// 添加关键点到框
  @override
  void _addKeypointToBox(Offset normalized, CanvasProvider canvasProvider,
      ProjectProvider projectProvider) {
    final currentClass = canvasProvider.currentClassId;

    final localCandidates = <int>[];
    final globalCandidates = <int>[];

    for (int i = projectProvider.labels.length - 1; i >= 0; i--) {
      final label = projectProvider.labels[i];
      if (label.id == currentClass) {
        if (isPointInBBox(normalized, label.bbox)) {
          localCandidates.add(i);
        } else {
          globalCandidates.add(i);
        }
      }
    }

    final candidates = [...localCandidates, ...globalCandidates];

    if (candidates.isEmpty) return;

    canvasProvider.setBindingCandidates(candidates);
    _bindPointToCandidate(normalized, canvasProvider, projectProvider);
  }

  /// 绑定关键点到当前候选框。
  void _bindPointToCandidate(Offset normalized, CanvasProvider canvasProvider,
      ProjectProvider projectProvider) {
    final candidateIndex = canvasProvider.currentBindingCandidate;
    if (candidateIndex == null) return;

    final label = projectProvider.labels[candidateIndex];

    for (final p in label.points) {
      if ((Offset(p.x, p.y) - normalized).distance < 0.005) return;
    }

    final newPoints = List<LabelPoint>.from(label.points);
    newPoints.add(LabelPoint(x: normalized.dx, y: normalized.dy));

    final newLabel = label.copyWith(points: newPoints);
    projectProvider.updateLabel(candidateIndex, newLabel);
    canvasProvider.selectLabel(candidateIndex);
    canvasProvider.setActiveKeypoint(newPoints.length - 1);
  }

  /// 处理标签移动（可选只移动父框）。
  @override
  void _handleMove(Offset current, CanvasProvider canvasProvider,
      ProjectProvider projectProvider,
      {bool parentOnly = false}) {
    final idx = canvasProvider.selectedLabelIndex;
    if (idx == null) return;

    final label = projectProvider.labels[idx];
    final prev = canvasProvider.drawCurrent ?? current;
    final d = current - prev;

    if (d.dx.abs() < 0.0001 && d.dy.abs() < 0.0001) return;

    final definitions = projectProvider.labelDefinitions;
    final isPolygon = label.id < definitions.length &&
        definitions[label.id].type == LabelType.polygon;
    if (isPolygon && parentOnly) {
      canvasProvider.updateDrag(current, notify: false);
      return;
    }

    label.x += d.dx;
    label.y += d.dy;
    if (!parentOnly) {
      for (final p in label.points) {
        p.x += d.dx;
        p.y += d.dy;
      }
    }

    projectProvider.updateLabel(idx, label, addToHistory: false, notify: false);
    canvasProvider.updateDrag(current, notify: false);
  }

  /// 处理标签缩放。
  @override
  void _handleResize(Offset current, CanvasProvider canvasProvider,
      ProjectProvider projectProvider) {
    final idx = canvasProvider.selectedLabelIndex;
    if (idx == null) return;

    final label = projectProvider.labels[idx];
    final handle = canvasProvider.activeHandle!;

    _resizeStartRect ??= Rect.fromLTRB(
      label.bbox[0],
      label.bbox[1],
      label.bbox[2],
      label.bbox[3],
    );
    final base = _resizeStartRect!;
    final rect = resizeRectFromHandle(
      base: base,
      current: current,
      handle: handle,
    );

    label.x = (rect.left + rect.right) / 2;
    label.y = (rect.top + rect.bottom) / 2;
    label.width = (rect.right - rect.left).abs();
    label.height = (rect.bottom - rect.top).abs();
    projectProvider.updateLabel(idx, label, addToHistory: false, notify: false);
    canvasProvider.updateDrag(current, notify: false);
  }

  /// 清理缩放过程状态。
  @override
  void _resetResizeState() {
    _resizeStartRect = null;
  }

  /// 处理移动关键点
  @override
  void _handleMoveKeypoint(Offset current, CanvasProvider canvasProvider,
      ProjectProvider projectProvider) {
    final kpIndex = canvasProvider.activeKeypointIndex;
    final labelIndex = canvasProvider.selectedLabelIndex;

    if (kpIndex == null || labelIndex == null) return;
    if (labelIndex >= projectProvider.labels.length) return;

    final label = projectProvider.labels[labelIndex];
    if (kpIndex >= label.points.length) return;

    label.points[kpIndex].x = current.dx;
    label.points[kpIndex].y = current.dy;

    final definitions = projectProvider.labelDefinitions;
    if (label.id < definitions.length &&
        definitions[label.id].type == LabelType.polygon) {
      label.updateBboxFromPoints();
    }

    projectProvider.updateLabel(labelIndex, label,
        addToHistory: false, notify: false);
    canvasProvider.updateDrag(current, notify: false);
  }

  // ==================== 命中检测 ====================

  /// 查找手柄
  @override
  int? _findHandleAt(Offset localPos, Label label, Size imageSize) {
    final settingsProvider = context.read<SettingsProvider>();
    final currentScale = _transformationController.value.entry(0, 0);
    return CanvasHitTester.findHandleAt(
      localPos: localPos,
      label: label,
      imageSize: imageSize,
      pointHitRadius: settingsProvider.pointHitRadius,
      scale: currentScale,
    );
  }

  /// 查找关键点
  @override
  HitKeypoint? _findKeypointAt(Offset normalized, List<Label> labels) {
    if (_image == null) return null;
    final settingsProvider = context.read<SettingsProvider>();
    final imageSize = Size(_image!.width.toDouble(), _image!.height.toDouble());
    final currentScale = _transformationController.value.entry(0, 0);
    return CanvasHitTester.findKeypointAt(
      normalized: normalized,
      labels: labels,
      imageSize: imageSize,
      pointHitRadius: settingsProvider.pointHitRadius,
      scale: currentScale,
      showUnlabeledPoints: settingsProvider.showUnlabeledPoints,
    );
  }

  /// 查找边缘
  @override
  int? _findEdgeAt(Offset localPos, Label label, Size imageSize) {
    final settingsProvider = context.read<SettingsProvider>();
    final currentScale = _transformationController.value.entry(0, 0);
    return CanvasHitTester.findEdgeAt(
      localPos: localPos,
      label: label,
      imageSize: imageSize,
      pointHitRadius: settingsProvider.pointHitRadius,
      scale: currentScale,
    );
  }

  /// 查找标签
  @override
  int? _findLabelAt(Offset normalized, List<Label> labels) {
    final projectProvider = context.read<ProjectProvider>();
    return CanvasHitTester.findLabelAt(
      normalized: normalized,
      labels: labels,
      definitions: projectProvider.labelDefinitions,
    );
  }
}
