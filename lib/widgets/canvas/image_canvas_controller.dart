part of 'image_canvas.dart';

/// ImageCanvas 输入控制器。
///
/// 负责键盘、鼠标、手势与侧键事件的统一调度与分发。
class _ImageCanvasInputController {
  _ImageCanvasInputController(this._state);

  final _ImageCanvasState _state;

  /// 确保画布获得焦点（便于接收键盘事件）。
  void _ensureCanvasFocus() {
    if (!_state.mounted) return;
    final route = ModalRoute.of(_state.context);
    if (route != null && !route.isCurrent) return;
    if (_state._focusNode.hasFocus || !_state._focusNode.canRequestFocus) {
      return;
    }
    _state._focusNode.requestFocus();
  }

  /// 处理键盘事件并映射为画布动作。
  KeyEventResult handleKeyEvent(
    KeyEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    final keyBindings = _state.context.read<KeyBindingsProvider>();
    final sideAction = keyBindings.getActionForSideButtonKey(event.logicalKey);
    if (sideAction != null) {
      return _handleBindableAction(
        sideAction,
        canvasProvider,
        projectProvider,
        source: InputSource.keyboard,
      );
    }

    if (event is KeyDownEvent) {
      if (_handleKeyboardPointerStart(
        event,
        canvasProvider,
        projectProvider,
      )) {
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (_handleKeyboardPointerEnd(
        event,
        canvasProvider,
        projectProvider,
      )) {
        return KeyEventResult.handled;
      }
    } else {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent &&
        keyBindings.matchesKeyEvent(BindableAction.cancelOperation, event)) {
      return _handleBindableAction(
        BindableAction.cancelOperation,
        canvasProvider,
        projectProvider,
        source: InputSource.keyboard,
      );
    }

    if (event is KeyDownEvent &&
        keyBindings.matchesKeyEvent(BindableAction.redo, event)) {
      return _handleBindableAction(
        BindableAction.redo,
        canvasProvider,
        projectProvider,
        source: InputSource.keyboard,
      );
    }

    if (event is KeyDownEvent &&
        keyBindings.matchesKeyEvent(BindableAction.undo, event)) {
      return _handleBindableAction(
        BindableAction.undo,
        canvasProvider,
        projectProvider,
        source: InputSource.keyboard,
      );
    }

    if (event is KeyDownEvent &&
        keyBindings.matchesKeyEvent(BindableAction.cycleBinding, event)) {
      return _handleBindableAction(
        BindableAction.cycleBinding,
        canvasProvider,
        projectProvider,
        source: InputSource.keyboard,
      );
    }

    if (event is KeyDownEvent &&
        event.logicalKey.keyLabel.isNotEmpty &&
        int.tryParse(event.logicalKey.keyLabel) != null) {
      final label = event.logicalKey.keyLabel;
      if (RegExp(r'^[1-9]$').hasMatch(label)) {
        final index = int.parse(label) - 1;
        final definitions = projectProvider.labelDefinitions;
        if (definitions.isNotEmpty &&
            index >= 0 &&
            index < definitions.length) {
          canvasProvider.setCurrentClassId(definitions[index].classId);
          if (canvasProvider.isCreatingPolygon) {
            canvasProvider.resetPolygon();
          }
          return KeyEventResult.handled;
        }
        if (definitions.isEmpty &&
            index >= 0 &&
            index < projectProvider.config.classNames.length) {
          canvasProvider.setCurrentClassId(index);
          if (canvasProvider.isCreatingPolygon) {
            canvasProvider.resetPolygon();
          }
          return KeyEventResult.handled;
        }
      }
    }

    if (event is KeyDownEvent &&
        keyBindings.matchesKeyEvent(BindableAction.nextClass, event)) {
      return _handleBindableAction(
        BindableAction.nextClass,
        canvasProvider,
        projectProvider,
        source: InputSource.keyboard,
      );
    }

    return KeyEventResult.ignored;
  }

  /// 执行绑定动作（撤销、重做、切换模式等）。
  KeyEventResult _handleBindableAction(
    BindableAction action,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider, {
    InputSource? source,
  }) {
    final gate = _state._inputActionGate;
    switch (action) {
      case BindableAction.cancelOperation:
        if (source != null && !gate.shouldHandle(action, source)) {
          return KeyEventResult.ignored;
        }
        if (_state._twoClickFirstPoint != null) {
          _state._twoClickFirstPoint = null;
          canvasProvider.cancelInteraction();
          return KeyEventResult.handled;
        }
        if (canvasProvider.isCreatingPolygon) {
          canvasProvider.resetPolygon();
          return KeyEventResult.handled;
        }
        canvasProvider.clearSelection();
        return KeyEventResult.handled;
      case BindableAction.redo:
        if (source != null && !gate.shouldHandle(action, source)) {
          return KeyEventResult.ignored;
        }
        if (projectProvider.canRedo) {
          projectProvider.redo();
          canvasProvider.clearSelection();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case BindableAction.undo:
        if (source != null && !gate.shouldHandle(action, source)) {
          return KeyEventResult.ignored;
        }
        if (projectProvider.canUndo) {
          projectProvider.undo();
          canvasProvider.clearSelection();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case BindableAction.cycleBinding:
        if (source != null && !gate.shouldHandle(action, source)) {
          return KeyEventResult.ignored;
        }
        return _handleCycleBinding(canvasProvider, projectProvider);
      case BindableAction.nextClass:
        if (source != null && !gate.shouldHandle(action, source)) {
          return KeyEventResult.ignored;
        }
        final nextIndex = (canvasProvider.currentClassId + 1) %
            projectProvider.config.classNames.length;
        canvasProvider.setCurrentClassId(nextIndex);
        if (canvasProvider.isCreatingPolygon) {
          canvasProvider.resetPolygon();
        }
        return KeyEventResult.handled;
      case BindableAction.prevImage:
      case BindableAction.nextImage:
      case BindableAction.prevLabel:
      case BindableAction.nextLabel:
      case BindableAction.toggleMode:
      case BindableAction.deleteSelected:
      case BindableAction.save:
      case BindableAction.toggleDarkEnhance:
      case BindableAction.aiInference:
      case BindableAction.toggleVisibility:
      case BindableAction.mouseCreate:
      case BindableAction.mouseDelete:
      case BindableAction.mouseMove:
      case BindableAction.zoomIn:
      case BindableAction.zoomOut:
        return KeyEventResult.ignored;
    }
  }

  bool handleMouseButtonShortcut(
    PointerDownEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    // 将鼠标按键映射为快捷动作（如侧键绑定）。
    if (event.kind != PointerDeviceKind.mouse) return false;
    final route = ModalRoute.of(_state.context);
    if (route != null && !route.isCurrent) return false;
    final keyBindings = _state.context.read<KeyBindingsProvider>();
    final action = keyBindings.getActionForMouseButtons(event.buttons);
    if (action == null) return false;
    final result = _handleBindableAction(
      action,
      canvasProvider,
      projectProvider,
      source: InputSource.pointer,
    );
    return result == KeyEventResult.handled;
  }

  /// 处理侧键事件流（后退/前进键）。
  void handleSideButtonStream(SideButtonEvent event) {
    if (!_state.mounted) return;
    final route = ModalRoute.of(_state.context);
    if (route != null && !route.isCurrent) return;
    final keyBindings = _state.context.read<KeyBindingsProvider>();
    final action = keyBindings.getActionForMouseButtonType(event.button);
    if (action == null) return;
    if (event.isDown) {
      if (action == BindableAction.mouseCreate ||
          action == BindableAction.mouseDelete ||
          action == BindableAction.mouseMove) {
        _startPointerActionIfAllowed(
          action,
          InputSource.sideButton,
          _state.context.read<CanvasProvider>(),
          _state.context.read<ProjectProvider>(),
        );
        return;
      }
      _handleBindableAction(
        action,
        _state.context.read<CanvasProvider>(),
        _state.context.read<ProjectProvider>(),
        source: InputSource.sideButton,
      );
    } else {
      if (action == BindableAction.mouseCreate ||
          action == BindableAction.mouseDelete ||
          action == BindableAction.mouseMove) {
        _finishKeyboardPointerAction(
          action,
          _state.context.read<CanvasProvider>(),
          _state.context.read<ProjectProvider>(),
          _state.context.read<SettingsProvider>(),
        );
      }
    }
  }

  /// 处理画布内指针按下事件。
  void onPointerDown(
    PointerDownEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 指针按下：可能触发手动创建拖拽或进入其他交互。
    _ensureCanvasFocus();
    if (handleMouseButtonShortcut(event, canvasProvider, projectProvider)) {
      return;
    }
    if (canvasProvider.isLabelingMode &&
        !_state._isPointerInImage(event.position)) {
      return;
    }
    _state._pointerTracker.start(event.position, event.buttons);
    _state._manualCreateDragActive = false;
    final createButton =
        keyBindings.getPointerButton(BindableAction.mouseCreate);
    final createActive = createButton != null &&
        createButton != kPrimaryMouseButton &&
        (event.buttons & createButton) != 0;
    final allowCreate = _state._inputActionGate.shouldHandle(
      BindableAction.mouseCreate,
      InputSource.pointer,
    );
    final action = resolvePointerDownAction(
      isLabelingMode: canvasProvider.isLabelingMode,
      inImage: _state._isPointerInImage(event.position),
      createActive: createActive,
      allowCreate: allowCreate,
    );
    if (action == PointerDownAction.startCreateDrag) {
      _startCreateDragAt(
        event.position,
        canvasProvider,
        projectProvider,
        settingsProvider,
        keyBindings,
      );
      _state._manualCreateDragActive =
          canvasProvider.interactionMode != InteractionMode.none;
    }
  }

  /// 处理画布外覆盖层按下事件（用于平移）。
  void onOverlayPointerDown(
    PointerDownEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 覆盖层按下仅用于平移，需记录状态以复用拖拽逻辑。
    _ensureCanvasFocus();
    if (handleMouseButtonShortcut(event, canvasProvider, projectProvider)) {
      return;
    }
    if (_state._isPointerInImage(event.position)) return;
    _state._overlayPointerDown = true;
    _state._overlayPanActive = false;
    _state._pointerTracker.start(event.position, event.buttons);
  }

  /// 处理画布外覆盖层移动事件（驱动平移）。
  void onOverlayPointerMove(
    PointerMoveEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 覆盖层拖拽：由覆盖层手势驱动平移。
    if (!_state._overlayPointerDown) return;
    onPointerMove(
      event,
      canvasProvider,
      projectProvider,
      settingsProvider,
      keyBindings,
    );
    if (!_state._overlayPanActive && _state._pointerTracker.moved) {
      _state._overlayPanActive = true;
      onPanStart(
        DragStartDetails(
          globalPosition: event.position,
          localPosition: _state._globalToImageLocal(event.position),
        ),
        canvasProvider,
        projectProvider,
        settingsProvider,
        keyBindings,
      );
    }
    if (_state._overlayPanActive) {
      onPanUpdate(
        DragUpdateDetails(
          globalPosition: event.position,
          localPosition: _state._globalToImageLocal(event.position),
          delta: event.delta,
        ),
        canvasProvider,
        projectProvider,
      );
    }
  }

  /// 处理画布外覆盖层抬起事件。
  void onOverlayPointerUp(
    PointerUpEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 覆盖层抬起：结束平移并清理状态。
    if (!_state._overlayPointerDown) return;
    onPointerUp(
      event,
      canvasProvider,
      projectProvider,
      settingsProvider,
      keyBindings,
    );
    if (_state._overlayPanActive) {
      onPanEnd(DragEndDetails(), canvasProvider, projectProvider);
    }
    _state._overlayPointerDown = false;
    _state._overlayPanActive = false;
  }

  /// 处理画布外覆盖层取消事件。
  void onOverlayPointerCancel(
    PointerCancelEvent event,
    ProjectProvider projectProvider,
    CanvasProvider canvasProvider,
  ) {
    // 覆盖层取消：重置交互状态。
    if (!_state._overlayPointerDown) return;
    onPointerCancel(event, projectProvider, canvasProvider);
    _state._overlayPointerDown = false;
    _state._overlayPanActive = false;
  }

  /// 处理画布外覆盖层悬停事件。
  void onOverlayPointerHover(
    PointerHoverEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 覆盖层悬停：仅在不在图像内时更新悬停信息。
    if (_state._isPointerInImage(event.position)) return;
    onHover(
      event,
      canvasProvider,
      projectProvider,
      settingsProvider,
      keyBindings,
    );
  }

  bool _handleKeyboardPointerStart(
    KeyDownEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    // 键盘按下触发的“模拟鼠标”动作启动。
    final keyBindings = _state.context.read<KeyBindingsProvider>();
    if (keyBindings.matchesKeyEvent(BindableAction.mouseCreate, event)) {
      return _startPointerActionIfAllowed(
        BindableAction.mouseCreate,
        InputSource.keyboard,
        canvasProvider,
        projectProvider,
        consumeIfBlocked: true,
      );
    }
    if (keyBindings.matchesKeyEvent(BindableAction.mouseDelete, event)) {
      return _startPointerActionIfAllowed(
        BindableAction.mouseDelete,
        InputSource.keyboard,
        canvasProvider,
        projectProvider,
        consumeIfBlocked: true,
      );
    }
    if (keyBindings.matchesKeyEvent(BindableAction.mouseMove, event)) {
      return _startPointerActionIfAllowed(
        BindableAction.mouseMove,
        InputSource.keyboard,
        canvasProvider,
        projectProvider,
        consumeIfBlocked: true,
      );
    }
    return false;
  }

  bool _handleKeyboardPointerEnd(
    KeyUpEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    // 键盘抬起时结束模拟指针动作。
    final action = _state._keyboardPointerState.action;
    if (action == null) return false;
    final binding =
        _state.context.read<KeyBindingsProvider>().getBinding(action);
    if (!binding.isKeyboard || binding.key != event.logicalKey) return false;
    _finishKeyboardPointerAction(
      action,
      canvasProvider,
      projectProvider,
      _state.context.read<SettingsProvider>(),
    );
    return true;
  }

  bool _startPointerActionIfAllowed(
    BindableAction action,
    InputSource source,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider, {
    bool consumeIfBlocked = false,
  }) {
    // 输入门控：防止重复触发。
    if (!_state._inputActionGate.shouldHandle(action, source)) {
      return consumeIfBlocked;
    }
    _startKeyboardPointerAction(action, canvasProvider, projectProvider);
    return true;
  }

  void _startKeyboardPointerAction(
    BindableAction action,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    // 记录起点并交由 KeyboardPointerActionState 统一驱动。
    final position = _state._getCurrentPointerGlobalPosition();
    _state._keyboardPointerState
        .startAction(action, position, _state._pointerTracker);
  }

  void _finishKeyboardPointerAction(
    BindableAction action,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
  ) {
    // 结束模拟动作并触发点击/拖拽结束逻辑。
    _state._keyboardPointerState.finishAction(
      action: action,
      tracker: _state._pointerTracker,
      isInteractionActive:
          canvasProvider.interactionMode != InteractionMode.none,
      toLocal: _state._globalToImageLocal,
      onCreateClick: (details) => _state._onCreateClick(
        details,
        canvasProvider,
        projectProvider,
        settingsProvider,
      ),
      onDeleteClick: (details) =>
          _state._onDeleteClick(details, canvasProvider, projectProvider),
      onPanEnd: () => onPanEnd(
        DragEndDetails(),
        canvasProvider,
        projectProvider,
      ),
    );
  }

  /// 处理画布内指针移动事件。
  void onPointerMove(
    PointerMoveEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 指针移动：平移、创建拖拽与悬停更新统一处理。
    if (canvasProvider.isLabelingMode &&
        !_state._isPointerInImage(event.position) &&
        !_state._manualCreateDragActive &&
        _state._keyboardPointerState.action != BindableAction.mouseCreate) {
      return;
    }
    _state._updatePointerTrackerAndScreen(event.position);

    final moveButton = keyBindings.getPointerButton(BindableAction.mouseMove);
    final moveActive =
        (moveButton != null && (event.buttons & moveButton) != 0) ||
            keyBindings.matchesKeyboardState(BindableAction.mouseMove) ||
            _state._keyboardPointerState.action == BindableAction.mouseMove;
    if (moveActive) {
      _state._applyClampedTranslation(event.delta.dx, event.delta.dy);
    }

    if (_state._manualCreateDragActive) {
      _updateCreateDragAt(
        event.position,
        event.delta,
        canvasProvider,
        projectProvider,
      );
    } else if (_state._keyboardPointerState.action ==
        BindableAction.mouseCreate) {
      _handleKeyboardCreateDrag(
        event.position,
        event.delta,
        canvasProvider,
        projectProvider,
        settingsProvider,
        keyBindings,
      );
    }

    _state._updateLocalMouseFromGlobal(event.position, canvasProvider);
  }

  /// 处理画布内指针抬起事件。
  void onPointerUp(
    PointerUpEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 指针抬起：根据解析动作执行创建/删除/绑定。
    final wasClick = _state._pointerTracker.wasClick;
    final inImage = _state._isPointerInImage(event.position);

    final deleteButton =
        keyBindings.getPointerButton(BindableAction.mouseDelete);
    final isDeleteButtonUp = deleteButton != null &&
        (_state._pointerTracker.lastButtons & deleteButton) != 0;
    final isPolygonClose = isDeleteButtonUp &&
        canvasProvider.isLabelingMode &&
        canvasProvider.isCreatingPolygon &&
        canvasProvider.currentPolygonPoints.length > 2;

    final createButton =
        keyBindings.getPointerButton(BindableAction.mouseCreate);
    final moveButton = keyBindings.getPointerButton(BindableAction.mouseMove);
    final labelType =
        _state._getCurrentLabelType(projectProvider, canvasProvider);

    final action = resolvePointerUpAction(
      wasClick: wasClick,
      isPolygonClose: isPolygonClose,
      isLabelingMode: canvasProvider.isLabelingMode,
      inImage: inImage,
      lastButtons: _state._pointerTracker.lastButtons,
      createButton: createButton,
      deleteButton: deleteButton,
      moveButton: moveButton,
      isTwoClickMode: settingsProvider.isTwoClickMode,
      labelType: labelType,
    );

    switch (action) {
      case PointerUpAction.create:
        final details = TapUpDetails(
          kind: PointerDeviceKind.mouse,
          localPosition: _state._globalToImageLocal(event.position),
          globalPosition: event.position,
        );
        _state._onCreateClick(
          details,
          canvasProvider,
          projectProvider,
          settingsProvider,
        );
        break;
      case PointerUpAction.delete:
        final details = TapUpDetails(
          kind: PointerDeviceKind.mouse,
          localPosition: _state._globalToImageLocal(event.position),
          globalPosition: event.position,
        );
        _state._onDeleteClick(details, canvasProvider, projectProvider);
        break;
      case PointerUpAction.moveKeypoint:
        final normalized =
            _state._normalizedFromGlobal(event.position, canvasProvider);
        _state._addKeypointToBox(normalized, canvasProvider, projectProvider);
        break;
      case PointerUpAction.none:
        break;
    }

    _state._pointerTracker.reset();

    if (_state._manualCreateDragActive) {
      onPanEnd(DragEndDetails(), canvasProvider, projectProvider);
      _state._manualCreateDragActive = false;
    }
  }

  /// 处理画布内指针取消事件。
  void onPointerCancel(
    PointerCancelEvent event,
    ProjectProvider projectProvider,
    CanvasProvider canvasProvider,
  ) {
    // 指针取消：重置交互状态与临时标记。
    _ensureCanvasFocus();
    _state._resetResizeState();
    _state._keyboardPointerState.createPending = false;
    _state._keyboardPointerState.createAnchor = null;
    if (_state._manualCreateDragActive) {
      _state._autoPanTimer?.cancel();
      canvasProvider.cancelInteraction();
      _state._manualCreateDragActive = false;
    }
  }

  /// 处理手势拖拽开始事件。
  void onPanStart(
    DragStartDetails details,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 手势拖拽开始：根据模式进入绘制或编辑。
    _ensureCanvasFocus();
    if (_state._image == null) return;

    if (canvasProvider.isLabelingMode &&
        !_state._isPointerInImage(details.globalPosition)) {
      return;
    }
    final normalized =
        _state._normalizedFromGlobal(details.globalPosition, canvasProvider);
    _state._localMousePosition.value = normalized;

    final moveButton = keyBindings.getPointerButton(BindableAction.mouseMove);
    final moveActive =
        keyBindings.matchesKeyboardState(BindableAction.mouseMove) ||
            (moveButton != null &&
                (_state._pointerTracker.lastButtons & moveButton) != 0);

    final createButton =
        keyBindings.getPointerButton(BindableAction.mouseCreate);
    final isCreateButton =
        keyBindings.matchesKeyboardState(BindableAction.mouseCreate) ||
            _state._keyboardPointerState.action == BindableAction.mouseCreate ||
            (createButton != null &&
                (_state._pointerTracker.lastButtons & createButton) != 0);
    final labelType =
        _state._getCurrentLabelType(projectProvider, canvasProvider);
    final action = resolvePanStartAction(
      isLabelingMode: canvasProvider.isLabelingMode,
      inImage: _state._isPointerInImage(details.globalPosition),
      createActive: isCreateButton,
      moveActive: moveActive,
      isTwoClickMode: settingsProvider.isTwoClickMode,
      labelType: labelType,
    );

    switch (action) {
      case PanStartAction.none:
        return;
      case PanStartAction.draw:
        canvasProvider.clearSelection();
        canvasProvider.tryStartDrawing(normalized);
        return;
      case PanStartAction.edit:
        _state._handleEditModePanStart(
            normalized, canvasProvider, projectProvider);
        return;
    }
  }

  /// 处理手势拖拽更新事件。
  void onPanUpdate(
    DragUpdateDetails details,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    // 手势拖拽更新：应用平移/绘制/调整等交互更新。
    if (_state._image == null) return;
    _state._lastGlobalPosition = details.globalPosition;
    _state._checkForAutoPan(details.globalPosition);
    final normalized =
        _state._normalizedFromGlobal(details.globalPosition, canvasProvider);
    InteractionUpdateHandler(
      canvasProvider: canvasProvider,
      normalized: normalized,
      applyPan: _state._applyClampedTranslation,
      handleResize: () =>
          _state._handleResize(normalized, canvasProvider, projectProvider),
      handleMove: () => _state._handleMove(
        normalized,
        canvasProvider,
        projectProvider,
        parentOnly: !_state._isCtrlPressed,
      ),
      handleMoveKeypoint: () => _state._handleMoveKeypoint(
          normalized, canvasProvider, projectProvider),
      handlePolygonHover: () => _state._localMousePosition.value = normalized,
      updateDrawing: () => canvasProvider.updateDrag(normalized),
    ).run(details.delta);
  }

  /// 处理手势拖拽结束事件。
  void onPanEnd(
    DragEndDetails details,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    // 手势拖拽结束：完成交互并清理状态。
    _state._autoPanTimer?.cancel();
    InteractionEndHandler(
      canvasProvider: canvasProvider,
      projectProvider: projectProvider,
      onFinish: _state._resetResizeState,
    ).run();
  }

  /// 处理鼠标悬停事件（更新悬停命中与辅助线）。
  void onHover(
    PointerHoverEvent event,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 悬停更新：处理命中状态与辅助线绘制。
    if (_state._image == null) return;
    _state._pointerTracker.lastGlobalPosition = event.position;
    final hoverAction = resolveHoverAction(
      isLabelingMode: canvasProvider.isLabelingMode,
      inImage: _state._isPointerInImage(event.position),
    );
    if (hoverAction == HoverAction.clear) {
      canvasProvider.clearHoverState();
      canvasProvider.setActiveHandle(null);
      canvasProvider.hoverLabel(null);
      return;
    }

    if (canvasProvider.isCreatingPolygon ||
        canvasProvider.currentPolygonPoints.isNotEmpty ||
        _state._twoClickFirstPoint != null) {
      _state._lastGlobalPosition = event.position;
      _state._checkForAutoPan(event.position);
    }

    final normalized =
        _state._normalizedFromGlobal(event.position, canvasProvider);

    _state._localMousePosition.value = normalized;

    if (_state._keyboardPointerState.action == BindableAction.mouseMove) {
      _state._applyClampedTranslation(event.delta.dx, event.delta.dy);
    } else if (_state._keyboardPointerState.action ==
        BindableAction.mouseCreate) {
      if (_handleKeyboardCreateDrag(
        event.position,
        event.delta,
        canvasProvider,
        projectProvider,
        settingsProvider,
        keyBindings,
      )) {
        return;
      }
    }

    if (_state._twoClickFirstPoint != null && canvasProvider.isDrawing) {
      canvasProvider.updateDrag(normalized);
    }

    final imageSize =
        Size(_state._image!.width.toDouble(), _state._image!.height.toDouble());

    final labels = projectProvider.labels;
    final hoverResult = CanvasHoverResolver(
      labels: labels,
      imageSize: imageSize,
      selectedLabelIndex: canvasProvider.selectedLabelIndex,
      getLabelDefinition: projectProvider.getLabelDefinition,
      findKeypointAt: (pos) => _state._findKeypointAt(pos, labels),
      findHandleAt: (pos, label) => _state._findHandleAt(pos, label, imageSize),
      findLabelAt: (pos) => _state._findLabelAt(pos, labels),
    ).resolve(normalized);

    applyHoverState(
      canvasProvider: canvasProvider,
      isLabelingMode: canvasProvider.isLabelingMode,
      result: hoverResult,
    );
  }

  /// 键盘创建动作驱动的拖拽更新。
  bool _handleKeyboardCreateDrag(
    Offset globalPosition,
    Offset delta,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 键盘触发的创建拖拽更新。
    if (_state._keyboardPointerState.action != BindableAction.mouseCreate) {
      return false;
    }
    _ensureKeyboardCreateStarted(
      globalPosition,
      canvasProvider,
      projectProvider,
      settingsProvider,
      keyBindings,
    );
    _state._updateMouseMoved(globalPosition);
    _updateCreateDragAt(
      globalPosition,
      delta,
      canvasProvider,
      projectProvider,
    );
    return canvasProvider.interactionMode != InteractionMode.none;
  }

  /// 确保键盘创建拖拽已正确启动。
  void _ensureKeyboardCreateStarted(
    Offset currentPosition,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 键盘创建拖拽：确保已建立起点并进入交互模式。
    if (!_state._keyboardPointerState.createPending ||
        canvasProvider.interactionMode != InteractionMode.none) {
      return;
    }
    final start = _resolveKeyboardCreateStart(currentPosition, canvasProvider);
    _state._pointerTracker.downPosition ??= start;
    _state._keyboardPointerState.createPending = false;
    _startCreateDragAt(
      start,
      canvasProvider,
      projectProvider,
      settingsProvider,
      keyBindings,
    );
  }

  /// 解析键盘创建拖拽的起点。
  Offset _resolveKeyboardCreateStart(
    Offset currentPosition,
    CanvasProvider canvasProvider,
  ) {
    // 起点在图像外时，尝试使用当前指针位置修正。
    Offset start = _state._keyboardPointerState.createAnchor ?? currentPosition;
    if (canvasProvider.isLabelingMode &&
        !_state._isPointerInImage(start) &&
        _state._isPointerInImage(currentPosition)) {
      start = currentPosition;
    }
    return start;
  }

  /// 在指定位置启动拖拽创建。
  void _startCreateDragAt(
    Offset globalPosition,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    // 统一进入拖拽创建流程（复用手势入口）。
    onPanStart(
      DragStartDetails(
        globalPosition: globalPosition,
        localPosition: _state._globalToImageLocal(globalPosition),
      ),
      canvasProvider,
      projectProvider,
      settingsProvider,
      keyBindings,
    );
  }

  /// 更新拖拽创建过程。
  void _updateCreateDragAt(
    Offset globalPosition,
    Offset delta,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    // 更新拖拽创建过程（复用手势更新入口）。
    onPanUpdate(
      DragUpdateDetails(
        globalPosition: globalPosition,
        localPosition: _state._globalToImageLocal(globalPosition),
        delta: delta,
      ),
      canvasProvider,
      projectProvider,
    );
  }

  /// 循环切换关键点绑定候选框。
  KeyEventResult _handleCycleBinding(
      CanvasProvider canvasProvider, ProjectProvider projectProvider) {
    // 关键点绑定候选框循环切换。
    if (!canvasProvider.isBindingKeypoint &&
        canvasProvider.selectedLabelIndex != null &&
        canvasProvider.activeKeypointIndex != null) {
      final currentIdx = canvasProvider.selectedLabelIndex!;
      final activePtIdx = canvasProvider.activeKeypointIndex!;
      final labels = projectProvider.labels;

      if (currentIdx < labels.length &&
          activePtIdx < labels[currentIdx].points.length) {
        final currentLabel = labels[currentIdx];
        final point = currentLabel.points[activePtIdx];
        final normalized = Offset(point.x, point.y);
        final currentClass = currentLabel.id;

        final localCandidates = <int>[];
        final globalCandidates = <int>[];

        for (int i = labels.length - 1; i >= 0; i--) {
          final l = labels[i];
          if (l.id == currentClass) {
            if (isPointInBBox(normalized, l.bbox)) {
              localCandidates.add(i);
            } else {
              globalCandidates.add(i);
            }
          }
        }
        final candidates = [...localCandidates, ...globalCandidates];

        if (candidates.isNotEmpty) {
          canvasProvider.setBindingCandidates(candidates);

          int safeGuard = 0;
          while (canvasProvider.currentBindingCandidate != currentIdx &&
              safeGuard < candidates.length) {
            canvasProvider.cycleBindingCandidate();
            safeGuard++;
          }
        }
      }
    }

    if (canvasProvider.isBindingKeypoint) {
      final labels = projectProvider.labels;
      final currentCandidateIdx = canvasProvider.currentBindingCandidate;

      if (currentCandidateIdx != null && currentCandidateIdx < labels.length) {
        final currentLabel = labels[currentCandidateIdx];
        final activePtIdx = canvasProvider.activeKeypointIndex;

        if (activePtIdx != null && activePtIdx < currentLabel.points.length) {
          final point = currentLabel.points[activePtIdx];

          canvasProvider.cycleBindingCandidate();
          final nextCandidateIdx = canvasProvider.currentBindingCandidate;

          if (nextCandidateIdx != null &&
              nextCandidateIdx != currentCandidateIdx) {
            final nextLabel = labels[nextCandidateIdx];

            final newCurrentPoints = List<LabelPoint>.from(currentLabel.points);
            newCurrentPoints.removeAt(activePtIdx);

            final newTargetPoints = List<LabelPoint>.from(nextLabel.points);
            newTargetPoints.add(point);

            projectProvider.updateLabel(currentCandidateIdx,
                currentLabel.copyWith(points: newCurrentPoints));
            projectProvider.updateLabel(
                nextCandidateIdx, nextLabel.copyWith(points: newTargetPoints));

            canvasProvider.selectLabel(nextCandidateIdx);
            canvasProvider.setActiveKeypoint(newTargetPoints.length - 1);

            return KeyEventResult.handled;
          }
          if (nextCandidateIdx == currentCandidateIdx) {
            canvasProvider.clearBindingCandidates();
            return KeyEventResult.handled;
          }
        }
      }
    }
    return KeyEventResult.ignored;
  }
}
