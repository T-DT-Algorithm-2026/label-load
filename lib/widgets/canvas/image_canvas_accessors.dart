part of 'image_canvas.dart';

/// ImageCanvas 内部状态与辅助接口集合。
///
/// 将状态字段和核心辅助方法统一抽取，便于分文件维护。
mixin _ImageCanvasAccessors on State<ImageCanvas> {
  // ==================== 状态变量 ====================
  /// 当前已解码的图像资源。
  ui.Image? _image;

  /// 是否处于加载中（控制加载态 UI）。
  bool _imageLoading = false;

  /// 最近一次加载错误（用于错误态 UI）。
  AppError? _imageLoadError;

  /// 递增的加载令牌，用于丢弃过期加载结果。
  int _imageLoadId = 0;

  /// 画布变换控制器（缩放/平移矩阵）。
  final TransformationController _transformationController =
      TransformationController();

  /// 绘制相关的合并监听器（变换 + 鼠标）。
  late final Listenable _paintListenable;

  /// 捕获键盘事件的焦点节点。
  late FocusNode _focusNode;

  /// 当前展示的图像路径（用于变更检测）。
  String? _currentImagePath;

  /// 指针拖拽追踪器。
  final PointerDragTracker _pointerTracker = PointerDragTracker();

  /// 图片读写仓库（可注入）。
  late final ImageRepository _imageRepository;

  // 自动平移状态
  final GlobalKey _viewportKey = GlobalKey();
  Timer? _autoPanTimer;

  /// 自动平移时的最近一次指针坐标（用于同步拖拽）。
  Offset? _lastGlobalPosition;

  /// 约束修正标记（避免递归触发变换监听）。
  bool _isCorrecting = false;

  /// 自动平移的当前速度向量。
  Offset _autoPanVelocity = Offset.zero;

  /// 缩放起始矩形（用于拖拽手柄计算）。
  Rect? _resizeStartRect;

  // 两次点击模式状态
  /// 两次点击模式下的第一点坐标（归一化）。
  Offset? _twoClickFirstPoint;

  // 鼠标状态
  /// 手动创建拖拽是否激活。
  bool _manualCreateDragActive = false;

  /// 透明层指针是否按下。
  bool _overlayPointerDown = false;

  /// 透明层是否正在拖拽。
  bool _overlayPanActive = false;

  /// 键盘驱动的指针动作状态。
  final KeyboardPointerActionState _keyboardPointerState =
      KeyboardPointerActionState();

  // 本地鼠标位置（绕过Provider重建）
  /// 图像归一化坐标下的鼠标位置。
  final ValueNotifier<Offset?> _localMousePosition = ValueNotifier(null);

  /// 屏幕坐标下的鼠标位置（用于跨坐标系同步）。
  final ValueNotifier<Offset?> _screenMousePosition = ValueNotifier(null);

  // Ctrl键状态
  /// Ctrl/Meta 是否按下（用于父框移动逻辑）。
  bool _isCtrlPressed = false;
  StreamSubscription<SideButtonEvent>? _sideButtonSub;

  /// 输入去重门控器。
  late final InputActionGate _inputActionGate;

  /// 键盘状态读取器。
  late final KeyboardStateReader _keyboardStateReader;

  Offset _globalToImageLocal(Offset globalPosition);
  Offset _imageLocalToViewport(Offset localPosition);
  Offset _normalizePosition(Offset localPosition, {bool clamp = true});

  bool _isNormalizedInImage(Offset normalized);

  void _handleMove(
    Offset current,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider, {
    bool parentOnly = false,
  });

  void _handleResize(
    Offset current,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  );

  void _handleMoveKeypoint(
    Offset current,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  );

  void _resetResizeState();

  int? _findHandleAt(Offset localPos, Label label, Size imageSize);
  HitKeypoint? _findKeypointAt(Offset normalized, List<Label> labels);
  int? _findEdgeAt(Offset localPos, Label label, Size imageSize);
  int? _findLabelAt(Offset normalized, List<Label> labels);

  void _finalizePolygon(
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  );

  void _addKeypointToBox(
    Offset normalized,
    CanvasProvider canvasProvider,
    ProjectProvider projectProvider,
  );

  LabelType _getCurrentLabelType(
    ProjectProvider projectProvider,
    CanvasProvider canvasProvider,
  );
}
