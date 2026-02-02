import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/app/app_error.dart';
import '../services/app/error_reporter.dart';

/// 交互模式枚举
enum InteractionMode {
  /// 无交互
  none,

  /// 绘制中
  drawing,

  /// 移动标签
  moving,

  /// 调整大小
  resizing,

  /// 移动关键点
  movingKeypoint,

  /// 平移画布
  panning,
}

extension InteractionModeX on InteractionMode {
  /// 当前模式是否属于编辑类交互。
  bool get isEditing =>
      this == InteractionMode.moving ||
      this == InteractionMode.resizing ||
      this == InteractionMode.movingKeypoint;
}

extension InteractionModeSetX on Set<InteractionMode> {
  /// 便于调试的集合字符串描述。
  String toDebugString() {
    return '{${map((e) => e.name).join(', ')}}';
  }
}

/// 画布交互状态约束
///
/// 仅用于约束状态迁移，避免交互模式与标注/编辑模式交织。
/// CanvasProvider 对非法迁移会在调试态断言并直接忽略（保持状态不变）。
/// 交互入口建议使用 tryStartDrawing/tryStartInteraction 以获得运行时返回值。
class CanvasInteractionPolicy {
  static const Set<InteractionMode> _labelingAllowed = {
    InteractionMode.drawing,
    InteractionMode.panning,
  };

  static const Set<InteractionMode> _editingAllowed = {
    InteractionMode.moving,
    InteractionMode.resizing,
    InteractionMode.movingKeypoint,
    InteractionMode.panning,
  };

  /// 允许进入的交互集合（按模式区分）
  static Set<InteractionMode> allowedFor(bool isLabelingMode) {
    return isLabelingMode ? _labelingAllowed : _editingAllowed;
  }

  /// 允许的状态迁移：
  /// - none -> drawing (仅标注模式)
  /// - none -> moving/resizing/movingKeypoint (仅编辑模式)
  /// - none -> panning (任意模式)
  /// - * -> none 由结束/取消交互完成
  static InteractionValidation validateStart(
    InteractionMode current,
    InteractionMode next, {
    required bool isLabelingMode,
  }) {
    if (current != InteractionMode.none) {
      return InteractionValidation.denied(
        'Invalid transition: $current -> $next (already interacting)',
      );
    }
    if (next == InteractionMode.none) {
      return InteractionValidation.denied(
        'Invalid transition: $current -> none',
      );
    }

    final allowed = isLabelingMode ? _labelingAllowed : _editingAllowed;
    if (!allowed.contains(next)) {
      final reason = isLabelingMode
          ? 'Invalid transition: $current -> $next (labeling=true)'
          : 'Invalid transition: $current -> $next (labeling=false)';
      return InteractionValidation.denied(reason);
    }

    return const InteractionValidation.allowed();
  }

  /// 是否允许从当前状态进入目标交互模式
  static bool canStart(
    InteractionMode current,
    InteractionMode next, {
    required bool isLabelingMode,
  }) {
    return validateStart(
      current,
      next,
      isLabelingMode: isLabelingMode,
    ).allowed;
  }

  /// 是否允许结束当前交互
  static bool canEnd(InteractionMode current) {
    return current != InteractionMode.none;
  }
}

/// 状态迁移校验结果。
class InteractionValidation {
  final bool allowed;
  final String? reason;

  const InteractionValidation._(this.allowed, [this.reason]);

  /// 允许状态迁移。
  const InteractionValidation.allowed() : this._(true);

  /// 拒绝状态迁移并附带原因。
  factory InteractionValidation.denied(String reason) {
    return InteractionValidation._(false, reason);
  }
}

/// 画布状态管理
///
/// 管理标注画布的交互状态，包括绘制、选择、悬停、缩放等。
class CanvasProvider extends ChangeNotifier {
  /// 交互状态机约束摘要（用于调试与文档同步）
  ///
  /// - Labeling 模式：允许 drawing / panning
  /// - Editing 模式：允许 moving / resizing / movingKeypoint / panning
  /// - 任意模式：通过 cancelInteraction 结束，回到 none
  /// - 入口建议：tryStartDrawing / tryStartInteraction
  static String interactionPolicySummary() {
    return 'labeling=${CanvasInteractionPolicy.allowedFor(true).toDebugString()}, '
        'editing=${CanvasInteractionPolicy.allowedFor(false).toDebugString()}';
  }

  // 交互状态
  InteractionMode _interactionMode = InteractionMode.none;
  Offset? _dragCurrentPoint;

  // 绘制状态
  Offset? _drawStart;

  // 选择状态
  int? _selectedLabelIndex;
  int? _hoveredLabelIndex;
  int? _activeHandle; // 0-7: 八个调整手柄
  int? _activeKeypointIndex;

  // 悬停状态
  int? _hoveredHandle;
  int? _hoveredKeypointIndex;
  int? _hoveredVertexIndex;
  int? _hoveredKeypointLabelIndex;

  // 标签类型
  int _labelType = 0; // 0=边界框, 1=关键点, 2=多边形
  int _currentClassId = 0;

  // 十字准星
  Offset? _mousePosition;
  bool _showCrosshair = true;

  // 暗部增强
  bool _enhanceDark = false;

  // 多边形绘制状态
  List<Offset> _currentPolygonPoints = [];

  // 关键点绑定状态
  List<int> _bindingCandidates = [];
  int _currentCandidateIndex = 0;
  String? _lastInteractionIssue;

  // 标注模式（与编辑模式相对）
  bool _isLabelingMode = false;

  // ============ Getters ============

  /// 当前交互模式。
  InteractionMode get interactionMode => _interactionMode;

  /// 是否处于绘制状态。
  bool get isDrawing => _interactionMode == InteractionMode.drawing;

  /// 绘制起点（仅绘制中有效）。
  Offset? get drawStart => _drawStart;

  /// 当前拖拽位置（绘制/编辑中更新）。
  Offset? get drawCurrent => _dragCurrentPoint;

  /// 选中的标签索引（无选中时为 null）。
  int? get selectedLabelIndex => _selectedLabelIndex;

  /// 悬停的标签索引（无悬停时为 null）。
  int? get hoveredLabelIndex => _hoveredLabelIndex;

  /// 激活的调整手柄索引。
  int? get activeHandle => _activeHandle;

  /// 激活的关键点索引。
  int? get activeKeypointIndex => _activeKeypointIndex;

  /// 悬停的调整手柄索引。
  int? get hoveredHandle => _hoveredHandle;

  /// 悬停的关键点索引。
  int? get hoveredKeypointIndex => _hoveredKeypointIndex;

  /// 悬停的多边形顶点索引。
  int? get hoveredVertexIndex => _hoveredVertexIndex;

  /// 悬停关键点所属标签的索引。
  int? get hoveredKeypointLabelIndex => _hoveredKeypointLabelIndex;

  /// 当前鼠标位置（用于十字准星绘制）。
  Offset? get mousePosition => _mousePosition;

  /// 当前标签类型：0=边界框, 1=关键点, 2=多边形。
  int get labelType => _labelType;

  /// 当前类别 ID。
  int get currentClassId => _currentClassId;

  /// 是否显示十字准星。
  bool get showCrosshair => _showCrosshair;

  /// 是否启用暗部增强。
  bool get enhanceDark => _enhanceDark;

  /// 是否处于标注模式（与编辑模式互斥）。
  bool get isLabelingMode => _isLabelingMode;

  /// 是否正在绘制多边形。
  bool get isCreatingPolygon => _currentPolygonPoints.isNotEmpty;

  /// 当前多边形顶点列表（归一化坐标）。
  List<Offset> get currentPolygonPoints => _currentPolygonPoints;

  /// 是否正在进行关键点绑定。
  bool get isBindingKeypoint => _bindingCandidates.isNotEmpty;

  /// 当前关键点绑定候选索引。
  int? get currentBindingCandidate => _bindingCandidates.isNotEmpty
      ? _bindingCandidates[_currentCandidateIndex]
      : null;

  /// 调试用快照，便于定位交互状态问题
  CanvasInteractionSnapshot debugSnapshot() {
    return CanvasInteractionSnapshot(
      interactionMode: _interactionMode,
      isLabelingMode: _isLabelingMode,
      drawStart: _drawStart,
      dragCurrentPoint: _dragCurrentPoint,
      selectedLabelIndex: _selectedLabelIndex,
      hoveredLabelIndex: _hoveredLabelIndex,
      activeHandle: _activeHandle,
      activeKeypointIndex: _activeKeypointIndex,
      hoveredHandle: _hoveredHandle,
      hoveredKeypointIndex: _hoveredKeypointIndex,
      hoveredKeypointLabelIndex: _hoveredKeypointLabelIndex,
      polygonPointCount: _currentPolygonPoints.length,
      bindingCandidateCount: _bindingCandidates.length,
      bindingCandidateIndex: _currentCandidateIndex,
    );
  }

  // ============ 标注模式 ============

  /// 设置标注模式
  void setLabelingMode(bool value) {
    if (_isLabelingMode != value) {
      _isLabelingMode = value;
      _applyModeChange();
      _assertInteractionState();
      notifyListeners();
    }
  }

  /// 切换标注模式
  void toggleLabelingMode() {
    setLabelingMode(!_isLabelingMode);
  }

  // ============ 绘制交互 ============

  /// 开始绘制新边界框
  void startDrawing(Offset point) {
    _tryStartInteraction(
      InteractionMode.drawing,
      point,
      assertOnFail: true,
    );
  }

  /// 尝试开始绘制（不会触发断言，失败返回false）
  bool tryStartDrawing(Offset point) {
    return _tryStartInteraction(
      InteractionMode.drawing,
      point,
      assertOnFail: false,
    );
  }

  /// 更新拖动位置
  void updateDrag(Offset point, {bool notify = true}) {
    if (_interactionMode == InteractionMode.none) return;
    _dragCurrentPoint = point;
    _assertInteractionState();
    if (notify) {
      notifyListeners();
    }
  }

  /// 开始移动/调整大小等交互
  void startInteraction(InteractionMode mode, Offset point) {
    _tryStartInteraction(mode, point, assertOnFail: true);
  }

  /// 尝试开始交互（不会触发断言，失败返回false）
  bool tryStartInteraction(InteractionMode mode, Offset point) {
    return _tryStartInteraction(mode, point, assertOnFail: false);
  }

  /// 结束交互并返回结果
  Rect? endInteraction() {
    final mode = _interactionMode;
    final start = _drawStart;
    final end = _dragCurrentPoint;

    _resetInteractionState();
    _assertInteractionState();
    notifyListeners();

    if (mode == InteractionMode.drawing && start != null && end != null) {
      final rect = Rect.fromPoints(start, end);
      return (rect.width > 0.01 && rect.height > 0.01) ? rect : null;
    }
    return null;
  }

  /// 取消交互
  void cancelInteraction() {
    _resetInteractionState();
    _assertInteractionState();
    notifyListeners();
  }

  // ============ 选择状态 ============

  /// 选择标签
  void selectLabel(int? index) {
    _selectedLabelIndex = index;
    notifyListeners();
  }

  /// 设置悬停标签
  void hoverLabel(int? index) {
    if (_hoveredLabelIndex != index) {
      _hoveredLabelIndex = index;
      notifyListeners();
    }
  }

  /// 设置激活的调整手柄
  void setActiveHandle(int? handle) {
    if (_activeHandle != handle) {
      _activeHandle = handle;
      notifyListeners();
    }
  }

  /// 设置激活的关键点
  void setActiveKeypoint(int? index) {
    _activeKeypointIndex = index;
    notifyListeners();
  }

  // ============ 悬停状态 ============

  /// 设置悬停的调整手柄
  void setHoveredHandle(int? handle) {
    if (_hoveredHandle != handle) {
      _hoveredHandle = handle;
      notifyListeners();
    }
  }

  /// 设置悬停的关键点
  void setHoveredKeypoint(int? labelIndex, int? pointIndex) {
    if (_hoveredKeypointLabelIndex != labelIndex ||
        _hoveredKeypointIndex != pointIndex) {
      _hoveredKeypointLabelIndex = labelIndex;
      _hoveredKeypointIndex = pointIndex;
      notifyListeners();
    }
  }

  /// 设置悬停的多边形顶点
  void setHoveredVertexIndex(int? index) {
    if (_hoveredVertexIndex != index) {
      _hoveredVertexIndex = index;
      notifyListeners();
    }
  }

  /// 清除所有悬停状态
  void clearHoverState() {
    _hoveredHandle = null;
    _hoveredKeypointIndex = null;
    _hoveredKeypointLabelIndex = null;
    _hoveredVertexIndex = null;
    notifyListeners();
  }

  // ============ 标签类型 ============

  /// 设置标签类型
  void setLabelType(int type) {
    if (_labelType != type) {
      _labelType = type;
      notifyListeners();
    }
  }

  /// 循环切换标签类型
  void cycleLabelType() {
    _labelType = (_labelType + 1) % 3;
    notifyListeners();
  }

  /// 设置当前类别ID
  void setCurrentClassId(int classId) {
    _currentClassId = classId;
    notifyListeners();
  }

  // ============ 视图控制 ============

  /// 更新鼠标位置（用于十字准星）
  void updateMousePosition(Offset? position) {
    _mousePosition = position;
    notifyListeners();
  }

  /// 切换十字准星显示
  void toggleCrosshair() {
    _showCrosshair = !_showCrosshair;
    notifyListeners();
  }

  /// 切换暗部增强
  void toggleDarkEnhancement() {
    _enhanceDark = !_enhanceDark;
    notifyListeners();
  }

  // ============ 清除状态 ============

  /// 清除选择状态（切换图片时调用）
  void clearSelection() {
    _selectedLabelIndex = null;
    _hoveredLabelIndex = null;
    _activeHandle = null;
    _activeKeypointIndex = null;
    _hoveredHandle = null;
    _hoveredKeypointIndex = null;
    _hoveredKeypointLabelIndex = null;
    _hoveredVertexIndex = null;
    _resetInteractionState();
    _assertInteractionState();
    notifyListeners();
  }

  // ============ 多边形绘制 ============

  /// 添加多边形顶点
  void addPolygonPoint(Offset normalized) {
    _currentPolygonPoints = [..._currentPolygonPoints, normalized];
    _assertInteractionState();
    notifyListeners();
  }

  /// 重置多边形绘制状态
  void resetPolygon() {
    _currentPolygonPoints = [];
    _assertInteractionState();
    notifyListeners();
  }

  // ============ 关键点绑定 ============

  /// 设置绑定候选标签列表
  void setBindingCandidates(List<int> candidates) {
    _bindingCandidates = candidates;
    _currentCandidateIndex = 0;
    _assertInteractionState();
    notifyListeners();
  }

  /// 循环切换绑定候选
  void cycleBindingCandidate() {
    if (_bindingCandidates.isEmpty) return;
    _currentCandidateIndex =
        (_currentCandidateIndex + 1) % _bindingCandidates.length;
    final candidateIndex = _bindingCandidates[_currentCandidateIndex];
    selectLabel(candidateIndex);
    _assertInteractionState();
    notifyListeners();
  }

  /// 清除绑定候选
  void clearBindingCandidates() {
    _bindingCandidates = [];
    _currentCandidateIndex = 0;
    _assertInteractionState();
    notifyListeners();
  }

  List<String> _validateInteractionState() {
    final issues = <String>[];

    if (_interactionMode == InteractionMode.drawing) {
      if (_drawStart == null || _dragCurrentPoint == null) {
        issues.add('drawing without points');
      }
    } else {
      if (_drawStart != null) {
        issues.add('drawStart not cleared when not drawing');
      }
    }

    if (_interactionMode == InteractionMode.none && _dragCurrentPoint != null) {
      issues.add('dragCurrentPoint set while idle');
    }

    if (_isLabelingMode &&
        (_interactionMode == InteractionMode.moving ||
            _interactionMode == InteractionMode.resizing ||
            _interactionMode == InteractionMode.movingKeypoint)) {
      issues.add('edit interaction while labeling');
    }

    if (!_isLabelingMode && _interactionMode == InteractionMode.drawing) {
      issues.add('drawing while not labeling');
    }

    if (_bindingCandidates.isNotEmpty) {
      if (_currentCandidateIndex < 0 ||
          _currentCandidateIndex >= _bindingCandidates.length) {
        issues.add('binding index out of range');
      }
    }

    final hasHoverKeypoint = _hoveredKeypointIndex != null;
    final hasHoverLabel = _hoveredKeypointLabelIndex != null;
    if (hasHoverKeypoint != hasHoverLabel) {
      issues.add('hovered keypoint label mismatch');
    }

    return issues;
  }

  void _assertInteractionState() {
    final issues = _validateInteractionState();
    assert(() {
      if (issues.isNotEmpty) {
        throw AssertionError(
          'CanvasProvider invalid state: ${issues.join(', ')} | '
          '${debugSnapshot().toDebugString()}',
        );
      }
      return true;
    }());

    if (issues.isEmpty) {
      _lastInteractionIssue = null;
      return;
    }

    if (!kDebugMode) {
      final issueKey = issues.join(', ');
      if (_lastInteractionIssue != issueKey) {
        _lastInteractionIssue = issueKey;
        final details =
            'CanvasProvider invalid state: $issueKey | ${debugSnapshot().toDebugString()}';
        ErrorReporter.report(
          AppError(AppErrorCode.unexpected, details: details),
          AppErrorCode.unexpected,
          stackTrace: StackTrace.current,
          details: details,
        );
      }
    }
  }

  void _applyModeChange() {
    final mode = _interactionMode;
    final isEditInteraction = mode.isEditing;

    if (_isLabelingMode) {
      if (isEditInteraction) {
        _resetInteractionState();
      }
      _activeHandle = null;
      _hoveredHandle = null;
      _hoveredKeypointIndex = null;
      _hoveredKeypointLabelIndex = null;
      _hoveredVertexIndex = null;
    } else {
      if (mode == InteractionMode.drawing) {
        _resetInteractionState();
      }
      _currentPolygonPoints = [];
    }
  }

  bool _tryStartInteraction(
    InteractionMode mode,
    Offset point, {
    required bool assertOnFail,
  }) {
    final validation = CanvasInteractionPolicy.validateStart(
      _interactionMode,
      mode,
      isLabelingMode: _isLabelingMode,
    );
    assert(!assertOnFail || validation.allowed, validation.reason);
    if (!validation.allowed) return false;

    if (mode == InteractionMode.drawing) {
      _startDrawingInternal(point);
    } else {
      _startInteractionInternal(mode, point);
    }
    return true;
  }

  void _resetInteractionState() {
    _interactionMode = InteractionMode.none;
    _drawStart = null;
    _dragCurrentPoint = null;
  }

  void _startDrawingInternal(Offset point) {
    _interactionMode = InteractionMode.drawing;
    _drawStart = point;
    _dragCurrentPoint = point;
    _assertInteractionState();
    notifyListeners();
  }

  void _startInteractionInternal(InteractionMode mode, Offset point) {
    _interactionMode = mode;
    _dragCurrentPoint = point;
    _assertInteractionState();
    notifyListeners();
  }
}

/// CanvasProvider 交互状态快照（用于调试/日志）。
class CanvasInteractionSnapshot {
  final InteractionMode interactionMode;
  final bool isLabelingMode;
  final Offset? drawStart;
  final Offset? dragCurrentPoint;
  final int? selectedLabelIndex;
  final int? hoveredLabelIndex;
  final int? activeHandle;
  final int? activeKeypointIndex;
  final int? hoveredHandle;
  final int? hoveredKeypointIndex;
  final int? hoveredKeypointLabelIndex;
  final int polygonPointCount;
  final int bindingCandidateCount;
  final int bindingCandidateIndex;

  const CanvasInteractionSnapshot({
    required this.interactionMode,
    required this.isLabelingMode,
    required this.drawStart,
    required this.dragCurrentPoint,
    required this.selectedLabelIndex,
    required this.hoveredLabelIndex,
    required this.activeHandle,
    required this.activeKeypointIndex,
    required this.hoveredHandle,
    required this.hoveredKeypointIndex,
    required this.hoveredKeypointLabelIndex,
    required this.polygonPointCount,
    required this.bindingCandidateCount,
    required this.bindingCandidateIndex,
  });

  /// 将快照格式化为可读字符串。
  String toDebugString() {
    return 'mode=$interactionMode'
        ', labeling=$isLabelingMode'
        ', drawStart=$drawStart'
        ', dragCurrent=$dragCurrentPoint'
        ', selected=$selectedLabelIndex'
        ', hovered=$hoveredLabelIndex'
        ', activeHandle=$activeHandle'
        ', activeKeypoint=$activeKeypointIndex'
        ', hoveredHandle=$hoveredHandle'
        ', hoveredKeypoint=$hoveredKeypointIndex'
        ', hoveredKeypointLabel=$hoveredKeypointLabelIndex'
        ', polygonPoints=$polygonPointCount'
        ', bindingCount=$bindingCandidateCount'
        ', bindingIndex=$bindingCandidateIndex';
  }
}
