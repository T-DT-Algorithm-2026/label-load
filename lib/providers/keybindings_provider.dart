import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/app/app_error.dart';
import '../services/input/keybindings_store.dart';
import '../services/input/keyboard_state_reader.dart';
import 'app_error_state.dart';

/// 鼠标按键类型
enum MouseButton {
  /// 左键（通常用于创建）
  left,

  /// 右键（通常用于删除）
  right,

  /// 中键（通常用于平移）
  middle,

  /// 侧键后退
  back,

  /// 侧键前进
  forward,
}

/// 滚轮动作类型
enum ScrollActionType {
  /// 上滚（放大）
  scrollUp,

  /// 下滚（缩小）
  scrollDown,
}

/// 按键绑定
///
/// 支持键盘按键、鼠标按键和滚轮动作三种类型。
class KeyBinding {
  final LogicalKeyboardKey? key;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final MouseButton? mouseButton;
  final ScrollActionType? scrollAction;

  const KeyBinding({
    this.key,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
    this.mouseButton,
    this.scrollAction,
  });

  /// 创建键盘绑定
  const KeyBinding.keyboard(this.key,
      {this.ctrl = false, this.shift = false, this.alt = false})
      : mouseButton = null,
        scrollAction = null;

  /// 创建鼠标绑定
  const KeyBinding.mouse(MouseButton button)
      : mouseButton = button,
        key = null,
        ctrl = false,
        shift = false,
        alt = false,
        scrollAction = null;

  /// 创建滚轮绑定
  const KeyBinding.scroll(ScrollActionType action)
      : scrollAction = action,
        key = null,
        ctrl = false,
        shift = false,
        alt = false,
        mouseButton = null;

  /// 空绑定
  static const KeyBinding none = KeyBinding();

  /// 是否为键盘绑定。
  bool get isKeyboard => key != null;

  /// 是否为鼠标绑定。
  bool get isMouse => mouseButton != null;

  /// 是否为滚轮绑定。
  bool get isScroll => scrollAction != null;

  /// 是否为空绑定。
  bool get isNone => key == null && mouseButton == null && scrollAction == null;

  /// 获取显示名称
  String getDisplayName([AppLocalizations? l10n]) {
    if (isNone) return l10n?.noBinding ?? '(无)';

    final parts = <String>[];
    if (ctrl) parts.add('Ctrl');
    if (shift) parts.add('Shift');
    if (alt) parts.add('Alt');

    if (key != null) {
      parts.add(_getKeyName(key!, l10n));
    } else if (mouseButton != null) {
      parts.add(_getMouseButtonName(mouseButton!, l10n));
    } else if (scrollAction != null) {
      parts.add(_getScrollActionTypeName(scrollAction!, l10n));
    }

    return parts.join(' + ');
  }

  static String _getKeyName(LogicalKeyboardKey key, [AppLocalizations? l10n]) {
    // 特殊按键需要本地化
    if (key == LogicalKeyboardKey.space) return l10n?.keySpace ?? '空格';
    if (key == LogicalKeyboardKey.backspace) return l10n?.keyBackspace ?? '退格';
    if (key == LogicalKeyboardKey.arrowUp) return l10n?.keyArrowUp ?? '↑';
    if (key == LogicalKeyboardKey.arrowDown) return l10n?.keyArrowDown ?? '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return l10n?.keyArrowLeft ?? '←';
    if (key == LogicalKeyboardKey.arrowRight) return l10n?.keyArrowRight ?? '→';

    // 通用按键映射
    final keyNames = <int, String>{
      LogicalKeyboardKey.keyA.keyId: 'A',
      LogicalKeyboardKey.keyB.keyId: 'B',
      LogicalKeyboardKey.keyC.keyId: 'C',
      LogicalKeyboardKey.keyD.keyId: 'D',
      LogicalKeyboardKey.keyE.keyId: 'E',
      LogicalKeyboardKey.keyF.keyId: 'F',
      LogicalKeyboardKey.keyG.keyId: 'G',
      LogicalKeyboardKey.keyH.keyId: 'H',
      LogicalKeyboardKey.keyI.keyId: 'I',
      LogicalKeyboardKey.keyJ.keyId: 'J',
      LogicalKeyboardKey.keyK.keyId: 'K',
      LogicalKeyboardKey.keyL.keyId: 'L',
      LogicalKeyboardKey.keyM.keyId: 'M',
      LogicalKeyboardKey.keyN.keyId: 'N',
      LogicalKeyboardKey.keyO.keyId: 'O',
      LogicalKeyboardKey.keyP.keyId: 'P',
      LogicalKeyboardKey.keyQ.keyId: 'Q',
      LogicalKeyboardKey.keyR.keyId: 'R',
      LogicalKeyboardKey.keyS.keyId: 'S',
      LogicalKeyboardKey.keyT.keyId: 'T',
      LogicalKeyboardKey.keyU.keyId: 'U',
      LogicalKeyboardKey.keyV.keyId: 'V',
      LogicalKeyboardKey.keyW.keyId: 'W',
      LogicalKeyboardKey.keyX.keyId: 'X',
      LogicalKeyboardKey.keyY.keyId: 'Y',
      LogicalKeyboardKey.keyZ.keyId: 'Z',
      LogicalKeyboardKey.digit0.keyId: '0',
      LogicalKeyboardKey.digit1.keyId: '1',
      LogicalKeyboardKey.digit2.keyId: '2',
      LogicalKeyboardKey.digit3.keyId: '3',
      LogicalKeyboardKey.digit4.keyId: '4',
      LogicalKeyboardKey.digit5.keyId: '5',
      LogicalKeyboardKey.digit6.keyId: '6',
      LogicalKeyboardKey.digit7.keyId: '7',
      LogicalKeyboardKey.digit8.keyId: '8',
      LogicalKeyboardKey.digit9.keyId: '9',
      LogicalKeyboardKey.enter.keyId: 'Enter',
      LogicalKeyboardKey.escape.keyId: 'Esc',
      LogicalKeyboardKey.tab.keyId: 'Tab',
      LogicalKeyboardKey.backquote.keyId: '`',
      LogicalKeyboardKey.delete.keyId: 'Delete',
      LogicalKeyboardKey.f1.keyId: 'F1',
      LogicalKeyboardKey.f2.keyId: 'F2',
      LogicalKeyboardKey.f3.keyId: 'F3',
      LogicalKeyboardKey.f4.keyId: 'F4',
      LogicalKeyboardKey.f5.keyId: 'F5',
      LogicalKeyboardKey.f6.keyId: 'F6',
      LogicalKeyboardKey.f7.keyId: 'F7',
      LogicalKeyboardKey.f8.keyId: 'F8',
      LogicalKeyboardKey.f9.keyId: 'F9',
      LogicalKeyboardKey.f10.keyId: 'F10',
      LogicalKeyboardKey.f11.keyId: 'F11',
      LogicalKeyboardKey.f12.keyId: 'F12',
      LogicalKeyboardKey.alt.keyId: 'Alt',
      LogicalKeyboardKey.altLeft.keyId: 'Alt',
      LogicalKeyboardKey.altRight.keyId: 'Alt',
    };
    return keyNames[key.keyId] ?? key.keyLabel;
  }

  static String _getMouseButtonName(MouseButton button,
      [AppLocalizations? l10n]) {
    switch (button) {
      case MouseButton.left:
        return l10n?.mouseLeft ?? '鼠标左键';
      case MouseButton.right:
        return l10n?.mouseRight ?? '鼠标右键';
      case MouseButton.middle:
        return l10n?.mouseMiddle ?? '鼠标中键';
      case MouseButton.back:
        return l10n?.mouseBack ?? '鼠标后退键';
      case MouseButton.forward:
        return l10n?.mouseForward ?? '鼠标前进键';
    }
  }

  static String _getScrollActionTypeName(ScrollActionType action,
      [AppLocalizations? l10n]) {
    switch (action) {
      case ScrollActionType.scrollUp:
        return l10n?.scrollUp ?? '滚轮上滚';
      case ScrollActionType.scrollDown:
        return l10n?.scrollDown ?? '滚轮下滚';
    }
  }

  /// 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'keyId': key?.keyId,
      'ctrl': ctrl,
      'shift': shift,
      'alt': alt,
      'mouseButton': mouseButton?.index,
      'scrollAction': scrollAction?.index,
    };
  }

  /// 从JSON反序列化
  factory KeyBinding.fromJson(Map<String, dynamic> json) {
    LogicalKeyboardKey? key;
    if (json['keyId'] != null) {
      key = LogicalKeyboardKey.findKeyByKeyId(json['keyId'] as int);
    }

    MouseButton? mouseButton;
    if (json['mouseButton'] != null) {
      final idx = json['mouseButton'] as int;
      if (idx >= 0 && idx < MouseButton.values.length) {
        mouseButton = MouseButton.values[idx];
      }
    }

    ScrollActionType? scrollAction;
    if (json['scrollAction'] != null) {
      final idx = json['scrollAction'] as int;
      if (idx >= 0 && idx < ScrollActionType.values.length) {
        scrollAction = ScrollActionType.values[idx];
      }
    }

    return KeyBinding(
      key: key,
      ctrl: json['ctrl'] ?? false,
      shift: json['shift'] ?? false,
      alt: json['alt'] ?? false,
      mouseButton: mouseButton,
      scrollAction: scrollAction,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeyBinding &&
        other.key == key &&
        other.ctrl == ctrl &&
        other.shift == shift &&
        other.alt == alt &&
        other.mouseButton == mouseButton &&
        other.scrollAction == scrollAction;
  }

  @override
  int get hashCode =>
      Object.hash(key, ctrl, shift, alt, mouseButton, scrollAction);
}

/// 可绑定动作枚举
enum BindableAction {
  // 导航
  prevImage,
  nextImage,

  // 标签切换
  prevLabel,
  nextLabel,

  // 模式
  toggleMode,
  nextClass,

  // 编辑
  deleteSelected,
  save,
  undo,
  redo,
  toggleDarkEnhance,
  cancelOperation,
  cycleBinding,
  aiInference,
  toggleVisibility,

  // 鼠标操作
  mouseCreate,
  mouseDelete,
  mouseMove,

  // 缩放
  zoomIn,
  zoomOut,
}

/// 按键绑定状态管理
///
/// 管理所有可绑定动作的快捷键设置，支持键盘、鼠标和滚轮绑定。
class KeyBindingsProvider extends ChangeNotifier with AppErrorState {
  static const String _storageKey = 'key_bindings';
  final KeyBindingsStore _store;

  /// 默认按键绑定
  static final Map<BindableAction, KeyBinding> defaultBindings = {
    // 导航
    BindableAction.prevImage:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyA),
    BindableAction.nextImage:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyD),

    // 标签切换
    BindableAction.prevLabel:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyQ),
    BindableAction.nextLabel:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyE),

    // 模式
    BindableAction.toggleMode:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyW),
    BindableAction.nextClass:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyC),

    // 编辑
    BindableAction.deleteSelected:
        const KeyBinding.keyboard(LogicalKeyboardKey.delete),
    BindableAction.save: const KeyBinding.keyboard(LogicalKeyboardKey.keyS),
    BindableAction.undo:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyZ, ctrl: true),
    BindableAction.redo: const KeyBinding.keyboard(LogicalKeyboardKey.keyZ,
        ctrl: true, shift: true),
    BindableAction.toggleDarkEnhance:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyX),
    BindableAction.cancelOperation:
        const KeyBinding.keyboard(LogicalKeyboardKey.escape),
    BindableAction.cycleBinding:
        const KeyBinding.keyboard(LogicalKeyboardKey.backquote),
    BindableAction.aiInference:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyR),
    BindableAction.toggleVisibility:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyV),

    // 鼠标操作
    BindableAction.mouseCreate: const KeyBinding.mouse(MouseButton.left),
    BindableAction.mouseDelete: const KeyBinding.mouse(MouseButton.right),
    BindableAction.mouseMove: const KeyBinding.mouse(MouseButton.middle),

    // 缩放
    BindableAction.zoomIn: const KeyBinding.scroll(ScrollActionType.scrollUp),
    BindableAction.zoomOut:
        const KeyBinding.scroll(ScrollActionType.scrollDown),
  };

  /// 获取动作描述
  static String getActionDescription(BindableAction action,
      [AppLocalizations? l10n]) {
    switch (action) {
      case BindableAction.prevImage:
        return l10n?.actionPrevImage ?? '上一张图片';
      case BindableAction.nextImage:
        return l10n?.actionNextImage ?? '下一张图片';
      case BindableAction.prevLabel:
        return l10n?.actionPrevLabel ?? '上一个标签';
      case BindableAction.nextLabel:
        return l10n?.actionNextLabel ?? '下一个标签';
      case BindableAction.toggleMode:
        return l10n?.actionToggleMode ?? '切换模式（创建/编辑）';
      case BindableAction.nextClass:
        return l10n?.actionNextClass ?? '下一个类别';
      case BindableAction.deleteSelected:
        return l10n?.actionDeleteSelected ?? '删除选中';
      case BindableAction.save:
        return l10n?.actionSave ?? '保存标签';
      case BindableAction.undo:
        return l10n?.actionUndo ?? '撤销';
      case BindableAction.redo:
        return l10n?.actionRedo ?? '重做';
      case BindableAction.toggleDarkEnhance:
        return l10n?.actionToggleDarkEnhance ?? '切换暗部增强';
      case BindableAction.cancelOperation:
        return l10n?.actionCancelOperation ?? '取消操作';
      case BindableAction.cycleBinding:
        return l10n?.actionCycleBinding ?? '循环切换绑定';
      case BindableAction.aiInference:
        return l10n?.actionAiInference ?? 'AI推理';
      case BindableAction.toggleVisibility:
        return l10n?.actionToggleVisibility ?? '切换关键点可见性';
      case BindableAction.mouseCreate:
        return l10n?.actionMouseCreate ?? '创建（鼠标）';
      case BindableAction.mouseDelete:
        return l10n?.actionMouseDelete ?? '删除（鼠标）';
      case BindableAction.mouseMove:
        return l10n?.actionMouseMove ?? '移动/拖拽（鼠标）';
      case BindableAction.zoomIn:
        return l10n?.actionZoomIn ?? '放大';
      case BindableAction.zoomOut:
        return l10n?.actionZoomOut ?? '缩小';
    }
  }

  /// 获取动作分类
  static String getActionCategory(BindableAction action,
      [AppLocalizations? l10n]) {
    switch (action) {
      case BindableAction.prevImage:
      case BindableAction.nextImage:
        return l10n?.categoryNavigation ?? '导航';
      case BindableAction.prevLabel:
      case BindableAction.nextLabel:
        return l10n?.categoryLabelSwitch ?? '标签切换';
      case BindableAction.toggleMode:
      case BindableAction.nextClass:
        return l10n?.categoryMode ?? '模式';
      case BindableAction.deleteSelected:
      case BindableAction.save:
      case BindableAction.undo:
      case BindableAction.redo:
      case BindableAction.toggleDarkEnhance:
      case BindableAction.cancelOperation:
      case BindableAction.cycleBinding:
      case BindableAction.aiInference:
      case BindableAction.toggleVisibility:
        return l10n?.categoryEdit ?? '编辑';
      case BindableAction.mouseCreate:
      case BindableAction.mouseDelete:
      case BindableAction.mouseMove:
        return l10n?.categoryMouse ?? '鼠标操作';
      case BindableAction.zoomIn:
      case BindableAction.zoomOut:
        return l10n?.categoryZoom ?? '缩放';
    }
  }

  Map<BindableAction, KeyBinding> _bindings = Map.from(defaultBindings);
  bool _isInitialized = false;
  final KeyboardStateReader _keyboardStateReader;

  /// 当前绑定映射（只读快照）。
  Map<BindableAction, KeyBinding> get bindings => Map.unmodifiable(_bindings);

  /// 是否已完成加载。
  bool get isInitialized => _isInitialized;

  KeyBindingsProvider({
    KeyBindingsStore? store,
    KeyboardStateReader? keyboardStateReader,
  })  : _store = store ?? SharedPreferencesKeyBindingsStore(key: _storageKey),
        _keyboardStateReader =
            keyboardStateReader ?? const HardwareKeyboardStateReader() {
    _loadBindings();
  }

  /// 获取动作的绑定
  KeyBinding getBinding(BindableAction action) {
    return _bindings[action] ?? defaultBindings[action]!;
  }

  /// 设置动作的绑定（自动清除冲突的绑定）
  Future<void> setBinding(BindableAction action, KeyBinding binding) async {
    // 跳过空绑定的冲突检查
    if (!binding.isNone) {
      // 查找并清除使用相同绑定的其他动作
      for (final entry in _bindings.entries) {
        if (entry.key != action && _bindingsEqual(entry.value, binding)) {
          _bindings[entry.key] = KeyBinding.none;
        }
      }
      // 同时检查默认绑定（未被覆盖的）
      for (final entry in defaultBindings.entries) {
        if (entry.key != action &&
            !_bindings.containsKey(entry.key) &&
            _bindingsEqual(entry.value, binding)) {
          _bindings[entry.key] = KeyBinding.none;
        }
      }
    }

    _bindings[action] = binding;
    notifyListeners();
    await _saveBindings();
  }

  /// 检查两个绑定是否相同
  bool _bindingsEqual(KeyBinding a, KeyBinding b) {
    if (a.isNone || b.isNone) return false;

    if (a.isKeyboard && b.isKeyboard) {
      return a.key == b.key &&
          a.ctrl == b.ctrl &&
          a.shift == b.shift &&
          a.alt == b.alt;
    }
    if (a.isMouse && b.isMouse) {
      return a.mouseButton == b.mouseButton;
    }
    if (a.isScroll && b.isScroll) {
      return a.scrollAction == b.scrollAction;
    }
    return false;
  }

  /// 清除动作的绑定
  Future<void> clearBinding(BindableAction action) async {
    _bindings[action] = KeyBinding.none;
    notifyListeners();
    await _saveBindings();
  }

  /// 重置为默认绑定
  Future<void> resetToDefault() async {
    _bindings = Map.from(defaultBindings);
    notifyListeners();
    await _saveBindings();
  }

  bool _isAltKey(LogicalKeyboardKey? key) {
    return key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight;
  }

  bool _matchesAltOnlyBinding(
    KeyBinding binding,
    LogicalKeyboardKey eventKey,
    bool isAlt,
  ) {
    return binding.key == null && binding.alt && (isAlt || _isAltKey(eventKey));
  }

  bool _matchesKeyboardBinding(
    KeyBinding binding,
    LogicalKeyboardKey eventKey, {
    required bool isCtrl,
    required bool isShift,
    required bool isAlt,
    bool treatAltKeyBindingAsAltKey = false,
  }) {
    if (!binding.isKeyboard) return false;

    if (treatAltKeyBindingAsAltKey && _isAltKey(binding.key)) {
      return _isAltKey(eventKey);
    }

    if (_matchesAltOnlyBinding(binding, eventKey, isAlt)) {
      return true;
    }

    return eventKey == binding.key &&
        (binding.ctrl == isCtrl) &&
        (binding.shift == isShift) &&
        (binding.alt == isAlt);
  }

  /// 检查键盘事件是否匹配动作（严格匹配键与修饰键状态）。
  bool matchesKeyboard(BindableAction action, KeyEvent event) {
    final binding = getBinding(action);
    if (!binding.isKeyboard) return false;

    final isCtrl = _keyboardStateReader.isControlPressed ||
        _keyboardStateReader.isMetaPressed;
    final isShift = _keyboardStateReader.isShiftPressed;
    final isAlt = _keyboardStateReader.isAltPressed;

    return _matchesKeyboardBinding(
      binding,
      event.logicalKey,
      isCtrl: isCtrl,
      isShift: isShift,
      isAlt: isAlt,
    );
  }

  /// 检查键盘事件是否匹配动作（允许 Alt 绑定映射到 Alt 键事件）。
  bool matchesKeyEvent(BindableAction action, KeyEvent event) {
    final binding = getBinding(action);
    if (!binding.isKeyboard) return false;

    final isCtrl = _keyboardStateReader.isControlPressed ||
        _keyboardStateReader.isMetaPressed;
    final isShift = _keyboardStateReader.isShiftPressed;
    final isAlt = _keyboardStateReader.isAltPressed;

    return _matchesKeyboardBinding(
      binding,
      event.logicalKey,
      isCtrl: isCtrl,
      isShift: isShift,
      isAlt: isAlt,
      treatAltKeyBindingAsAltKey: true,
    );
  }

  /// 检查当前键盘按下状态是否匹配动作
  bool matchesKeyboardState(BindableAction action) {
    final binding = getBinding(action);
    if (!binding.isKeyboard) return false;
    if (binding.key == null) return false;

    final pressed = _keyboardStateReader.logicalKeysPressed;
    final isCtrl = _keyboardStateReader.isControlPressed ||
        _keyboardStateReader.isMetaPressed;
    final isShift = _keyboardStateReader.isShiftPressed;
    final isAlt = _keyboardStateReader.isAltPressed;

    if (_isAltKey(binding.key)) {
      return isAlt;
    }

    return pressed.contains(binding.key) &&
        (binding.ctrl == isCtrl) &&
        (binding.shift == isShift) &&
        (binding.alt == isAlt);
  }

  /// 获取动作的鼠标按键
  MouseButton? getMouseButton(BindableAction action) {
    final binding = getBinding(action);
    return binding.mouseButton;
  }

  /// 获取动作的原始指针按键值
  int? getPointerButton(BindableAction action) {
    final mouseButton = getMouseButton(action);
    if (mouseButton == null) return null;
    switch (mouseButton) {
      case MouseButton.left:
        return kPrimaryMouseButton;
      case MouseButton.right:
        return kSecondaryMouseButton;
      case MouseButton.middle:
        return kMiddleMouseButton;
      case MouseButton.back:
        return kBackMouseButton;
      case MouseButton.forward:
        return kForwardMouseButton;
    }
  }

  /// 仅解析鼠标侧键
  static MouseButton? sideButtonFromButtons(int buttons) {
    final button = mouseButtonFromButtons(buttons);
    if (button == MouseButton.back || button == MouseButton.forward) {
      return button;
    }
    return null;
  }

  /// 解析任意鼠标按键
  static MouseButton? mouseButtonFromButtons(int buttons) {
    if ((buttons & kBackMouseButton) != 0) return MouseButton.back;
    if ((buttons & kForwardMouseButton) != 0) return MouseButton.forward;
    if ((buttons & kMiddleMouseButton) != 0) return MouseButton.middle;
    if ((buttons & kSecondaryMouseButton) != 0) return MouseButton.right;
    if ((buttons & kPrimaryMouseButton) != 0) return MouseButton.left;
    return null;
  }

  /// 从键盘事件解析鼠标侧键（部分平台会把侧键映射为浏览器前进/后退键）
  static MouseButton? sideButtonFromKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.browserBack) return MouseButton.back;
    if (key == LogicalKeyboardKey.browserForward) return MouseButton.forward;
    return null;
  }

  /// 根据鼠标侧键查找绑定动作
  BindableAction? getActionForSideButton(int buttons) {
    final button = sideButtonFromButtons(buttons);
    if (button == null) return null;
    return getActionForMouseButtonType(button);
  }

  /// 根据鼠标按键查找绑定动作
  BindableAction? getActionForMouseButtons(int buttons) {
    final button = mouseButtonFromButtons(buttons);
    if (button == null) return null;
    return getActionForMouseButtonType(button);
  }

  /// 根据键盘侧键查找绑定动作
  BindableAction? getActionForSideButtonKey(LogicalKeyboardKey key) {
    final button = sideButtonFromKey(key);
    if (button == null) return null;
    return getActionForMouseButtonType(button);
  }

  /// 根据鼠标按键类型查找绑定动作
  BindableAction? getActionForMouseButtonType(MouseButton button) {
    for (final action in BindableAction.values) {
      final binding = getBinding(action);
      if (binding.isMouse && binding.mouseButton == button) {
        return action;
      }
    }
    return null;
  }

  /// 检查滚轮动作是否匹配
  bool matchesScroll(BindableAction action, double scrollDelta) {
    final binding = getBinding(action);
    if (!binding.isScroll) return false;

    if (binding.scrollAction == ScrollActionType.scrollUp) {
      return scrollDelta < 0;
    } else if (binding.scrollAction == ScrollActionType.scrollDown) {
      return scrollDelta > 0;
    }
    return false;
  }

  /// 获取鼠标动作的显示名称
  String getMouseActionDisplayName(BindableAction action,
      [AppLocalizations? l10n]) {
    final binding = getBinding(action);
    if (binding.isMouse) {
      switch (binding.mouseButton!) {
        case MouseButton.left:
          return l10n?.mouseLeft ?? '左键';
        case MouseButton.right:
          return l10n?.mouseRight ?? '右键';
        case MouseButton.middle:
          return l10n?.mouseMiddle ?? '中键';
        case MouseButton.back:
          return l10n?.mouseBack ?? '后退键';
        case MouseButton.forward:
          return l10n?.mouseForward ?? '前进键';
      }
    } else if (binding.isKeyboard) {
      return binding.getDisplayName(l10n);
    }
    return l10n?.noBinding ?? '(未绑定)';
  }

  /// 从本地存储加载绑定
  Future<void> _loadBindings() async {
    try {
      final jsonStr = await _store.read();
      if (jsonStr != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
        for (final entry in jsonMap.entries) {
          final actionIndex = int.tryParse(entry.key);
          if (actionIndex != null &&
              actionIndex >= 0 &&
              actionIndex < BindableAction.values.length) {
            final action = BindableAction.values[actionIndex];
            _bindings[action] = KeyBinding.fromJson(entry.value);
          }
        }
      }
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.ioOperationFailed,
        stackTrace: stack,
        details: 'load keybindings: $e',
        notify: false,
      );
      _bindings = Map.from(defaultBindings);
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// 保存绑定到本地存储
  Future<void> _saveBindings() async {
    try {
      final Map<String, dynamic> jsonMap = {};
      for (final entry in _bindings.entries) {
        jsonMap[entry.key.index.toString()] = entry.value.toJson();
      }
      await _store.write(jsonEncode(jsonMap));
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.ioOperationFailed,
        stackTrace: stack,
        details: 'save keybindings: $e',
        notify: false,
      );
    }
  }
}
