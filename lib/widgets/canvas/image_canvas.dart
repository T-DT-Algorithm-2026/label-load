import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/keybindings_provider.dart';
import '../../services/input/side_button_service.dart';
import '../../services/input/input_action_gate.dart';
import '../../services/image/image_repository.dart';
import '../../services/input/keyboard_state_reader.dart';
import '../../services/app/app_error.dart';
import '../../services/app/error_reporter.dart';
import '../../services/app/app_services.dart';
import 'label_painter.dart';
import 'canvas_helpers.dart';
import 'pointer_drag_tracker.dart';
import 'canvas_hit_tester.dart';
import 'canvas_hover_handler.dart';
import 'canvas_geometry.dart';
import 'resize_utils.dart';
import 'edit_mode_drag_start_handler.dart';
import 'edit_mode_selection_handler.dart';
import 'interaction_update_handler.dart';
import 'interaction_end_handler.dart';
import 'pointer_up_resolver.dart';
import 'keyboard_pointer_action_state.dart';
import 'pan_start_resolver.dart';
import 'pointer_down_resolver.dart';
import 'pointer_hover_resolver.dart';

part 'image_canvas_image_ops.dart';
part 'image_canvas_transform.dart';
part 'image_canvas_controller.dart';
part 'image_canvas_input.dart';
part 'image_canvas_label_ops.dart';
part 'image_canvas_accessors.dart';

/// 图像画布组件
///
/// 主画布组件，支持缩放/平移和标签交互。
class ImageCanvas extends StatefulWidget {
  const ImageCanvas({
    super.key,
    this.sideButtonService,
    this.inputActionGate,
    this.imageRepository,
    this.keyboardStateReader,
  });

  /// 注入侧键服务，便于测试或替换默认实现。
  final SideButtonService? sideButtonService;

  /// 注入输入去重门控器，便于测试或替换默认实现。
  final InputActionGate? inputActionGate;

  /// 注入图片仓库，便于测试或替换默认文件系统实现。
  final ImageRepository? imageRepository;

  /// 注入键盘状态读取器，便于测试或替换默认实现。
  final KeyboardStateReader? keyboardStateReader;

  @override
  State<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends State<ImageCanvas>
    with
        WidgetsBindingObserver,
        _ImageCanvasAccessors,
        _ImageCanvasImageOps,
        _ImageCanvasTransform,
        _ImageCanvasInput,
        _ImageCanvasLabelOps {
  /// 输入事件分发控制器（键盘/鼠标/侧键统一调度）。
  late final _ImageCanvasInputController _inputController;
  // ==================== 生命周期 ====================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transformationController.addListener(_onTransformationChange);
    _paintListenable =
        Listenable.merge([_transformationController, _localMousePosition]);
    _focusNode = FocusNode();
    final services = context.read<AppServices>();
    _imageRepository = widget.imageRepository ?? services.imageRepository;
    _keyboardStateReader =
        widget.keyboardStateReader ?? services.keyboardStateReader;
    _inputActionGate = widget.inputActionGate ?? services.inputActionGate;
    _inputController = _ImageCanvasInputController(this);
    final sideButtonService =
        widget.sideButtonService ?? services.sideButtonService;
    _sideButtonSub = sideButtonService.stream
        .listen(_inputController.handleSideButtonStream);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoPanTimer?.cancel();
    _sideButtonSub?.cancel();
    _transformationController.removeListener(_onTransformationChange);
    _localMousePosition.dispose();
    _screenMousePosition.dispose();
    _transformationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _image != null) {
        _centerImage();
      }
    });
  }

  /// 测试辅助：直接调用关键点移动逻辑，便于覆盖关键分支。
  @visibleForTesting
  void debugMoveKeypoint(
    Offset normalized,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    _handleMoveKeypoint(normalized, canvasProvider, projectProvider);
  }

  // ==================== 构建方法 ====================

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final canvasProvider = context.watch<CanvasProvider>();
    final imagePath = projectProvider.currentImagePath;

    if (imagePath != _currentImagePath) {
      _currentImagePath = imagePath;
      _loadImage(imagePath);
    }

    if (imagePath == null) {
      return _buildEmptyState();
    }

    if (_imageLoadError != null) {
      return _buildErrorState(_imageLoadError!);
    }

    if (_imageLoading || _image == null) {
      return _buildLoadingState();
    }

    return _buildCanvas(context, projectProvider, canvasProvider);
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppTheme.getBackground(context),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 64,
              color: AppTheme.getTextMuted(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noImage,
              style: TextStyle(
                color: AppTheme.getTextMuted(context),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.openFolderToStart,
              style: TextStyle(
                color: AppTheme.getTextMuted(context).withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    return Container(
      color: AppTheme.getBackground(context),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// 构建错误状态
  Widget _buildErrorState(AppError error) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('imageCanvasError'),
      color: AppTheme.getBackground(context),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 56,
              color: AppTheme.getTextMuted(context).withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              error.message(l10n),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.getTextMuted(context),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建主画布
  Widget _buildCanvas(
    BuildContext context,
    ProjectProvider projectProvider,
    CanvasProvider canvasProvider,
  ) {
    final settingsProvider = context.watch<SettingsProvider>();
    final keyBindings = context.read<KeyBindingsProvider>();

    return Container(
      color: AppTheme.getBackground(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageSize =
              Size(_image!.width.toDouble(), _image!.height.toDouble());

          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            onHover: (event) {
              _screenMousePosition.value = event.localPosition;
            },
            onExit: (event) {
              _screenMousePosition.value = null;
            },
            child: Stack(
              children: [
                _buildInteractiveViewer(
                  imageSize,
                  settingsProvider,
                  keyBindings,
                  canvasProvider,
                  projectProvider,
                ),
                if (!canvasProvider.isLabelingMode)
                  _buildEditPointerOverlay(
                    canvasProvider,
                    projectProvider,
                    settingsProvider,
                    keyBindings,
                  ),
                if (canvasProvider.isLabelingMode) _buildCrosshairOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建可交互视图
  Widget _buildInteractiveViewer(
    Size imageSize,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  ) {
    return InteractiveViewer(
      key: _viewportKey,
      transformationController: _transformationController,
      minScale: settingsProvider.minScale,
      maxScale: settingsProvider.maxScale,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      constrained: false,
      panEnabled: false,
      alignment: Alignment.topLeft,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          final isCtrl = _keyboardStateReader.isControlPressed;
          if (isCtrl != _isCtrlPressed) {
            _isCtrlPressed = isCtrl;
          }
          return _inputController.handleKeyEvent(
              event, canvasProvider, projectProvider);
        },
        child: _buildGestureLayer(
          imageSize,
          canvasProvider,
          projectProvider,
          settingsProvider,
          keyBindings,
        ),
      ),
    );
  }

  /// 构建手势层
  Widget _buildGestureLayer(
    Size imageSize,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _inputController.onPointerDown(
        event,
        canvasProvider,
        projectProvider,
        settingsProvider,
        keyBindings,
      ),
      onPointerMove: (event) => _inputController.onPointerMove(
        event,
        canvasProvider,
        projectProvider,
        settingsProvider,
        keyBindings,
      ),
      onPointerUp: (event) {
        _inputController.onPointerUp(
          event,
          canvasProvider,
          projectProvider,
          settingsProvider,
          keyBindings,
        );
      },
      onPointerHover: (event) => _inputController.onHover(
        event,
        canvasProvider,
        projectProvider,
        settingsProvider,
        keyBindings,
      ),
      onPointerCancel: (event) => _inputController.onPointerCancel(
        event,
        projectProvider,
        canvasProvider,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _inputController.onPanStart(
          details,
          canvasProvider,
          projectProvider,
          settingsProvider,
          keyBindings,
        ),
        onPanUpdate: (details) => _inputController.onPanUpdate(
          details,
          canvasProvider,
          projectProvider,
        ),
        onPanEnd: (details) => _inputController.onPanEnd(
          details,
          canvasProvider,
          projectProvider,
        ),
        child: _buildCanvasContent(
            imageSize, canvasProvider, projectProvider, settingsProvider),
      ),
    );
  }

  Widget _buildEditPointerOverlay(
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
    KeyBindingsProvider keyBindings,
  ) {
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => _inputController.onOverlayPointerDown(
          event,
          canvasProvider,
          projectProvider,
          settingsProvider,
          keyBindings,
        ),
        onPointerMove: (event) => _inputController.onOverlayPointerMove(
          event,
          canvasProvider,
          projectProvider,
          settingsProvider,
          keyBindings,
        ),
        onPointerUp: (event) => _inputController.onOverlayPointerUp(
          event,
          canvasProvider,
          projectProvider,
          settingsProvider,
          keyBindings,
        ),
        onPointerCancel: (event) => _inputController.onOverlayPointerCancel(
          event,
          projectProvider,
          canvasProvider,
        ),
        onPointerHover: (event) => _inputController.onOverlayPointerHover(
          event,
          canvasProvider,
          projectProvider,
          settingsProvider,
          keyBindings,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  /// 构建画布内容
  Widget _buildCanvasContent(
    Size imageSize,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
    SettingsProvider settingsProvider,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.precise,
      child: SizedBox(
        width: imageSize.width,
        height: imageSize.height,
        child: Stack(
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: imageSize,
                painter: ImagePainter(
                  image: _image!,
                  filterQuality: settingsProvider.imageInterpolation
                      ? ui.FilterQuality.high
                      : ui.FilterQuality.none,
                  colorFilter: canvasProvider.enhanceDark
                      ? const ColorFilter.matrix([
                          1.5,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1.5,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1.5,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ])
                      : null,
                ),
                isComplex: true,
              ),
            ),
            AnimatedBuilder(
              animation: _paintListenable,
              builder: (context, child) {
                return CustomPaint(
                  size: imageSize,
                  painter: LabelPainter(
                    labels: projectProvider.labels,
                    selectedIndex: canvasProvider.selectedLabelIndex,
                    activeKeypointIndex: canvasProvider.activeKeypointIndex,
                    hoveredIndex: canvasProvider.hoveredLabelIndex,
                    drawingRect: _getDrawingRect(canvasProvider),
                    currentClassId: canvasProvider.currentClassId,
                    definitions: projectProvider.labelDefinitions,
                    activeHandle: canvasProvider.activeHandle,
                    isLabelingMode: canvasProvider.isLabelingMode,
                    showCrosshair: false,
                    mousePosition: _localMousePosition.value,
                    polygonPoints: canvasProvider.currentPolygonPoints,
                    hoveredHandle: canvasProvider.hoveredHandle,
                    hoveredKeypointIndex: canvasProvider.hoveredKeypointIndex,
                    hoveredKeypointLabelIndex:
                        canvasProvider.hoveredKeypointLabelIndex,
                    hoveredVertexIndex: canvasProvider.hoveredVertexIndex,
                    pointSize: settingsProvider.pointSize,
                    pointHitRadius: settingsProvider.pointHitRadius,
                    currentScale: _transformationController.value.entry(0, 0),
                    fillShape: settingsProvider.fillShape,
                    showUnlabeledPoints: settingsProvider.showUnlabeledPoints,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建十字准星覆盖层
  Widget _buildCrosshairOverlay() {
    return ValueListenableBuilder<Offset?>(
      valueListenable: _screenMousePosition,
      builder: (context, screenPos, child) {
        if (screenPos == null) return const SizedBox.shrink();
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: screenPos.dy - 1,
                height: 2,
                child: const ColoredBox(color: Colors.black),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: screenPos.dx - 1,
                width: 2,
                child: const ColoredBox(color: Colors.black),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== 辅助方法 ====================

  /// 获取绘制矩形
  Rect? _getDrawingRect(CanvasProvider canvasProvider) {
    if (!canvasProvider.isDrawing) return null;
    final start = canvasProvider.drawStart;
    final current = canvasProvider.drawCurrent;
    if (start == null || current == null) return null;
    return Rect.fromPoints(start, current);
  }

  /// 获取当前标签类型
  @override
  LabelType _getCurrentLabelType(
      ProjectProvider projectProvider, CanvasProvider canvasProvider) {
    if (projectProvider.labelDefinitions.isEmpty) return LabelType.box;
    final def =
        projectProvider.getLabelDefinition(canvasProvider.currentClassId);
    return def?.type ?? LabelType.box;
  }
}
