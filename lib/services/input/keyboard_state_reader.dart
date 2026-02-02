import 'package:flutter/services.dart';

/// 键盘状态读取接口
abstract class KeyboardStateReader {
  /// 是否按下 Control。
  bool get isControlPressed;

  /// 是否按下 Meta（Command/Windows）。
  bool get isMetaPressed;

  /// 是否按下 Shift。
  bool get isShiftPressed;

  /// 是否按下 Alt。
  bool get isAltPressed;

  /// 当前按下的逻辑键集合。
  Set<LogicalKeyboardKey> get logicalKeysPressed;
}

/// 使用 [HardwareKeyboard] 的默认实现
class HardwareKeyboardStateReader implements KeyboardStateReader {
  const HardwareKeyboardStateReader();

  @override
  bool get isControlPressed => HardwareKeyboard.instance.isControlPressed;

  @override
  bool get isMetaPressed => HardwareKeyboard.instance.isMetaPressed;

  @override
  bool get isShiftPressed => HardwareKeyboard.instance.isShiftPressed;

  @override
  bool get isAltPressed => HardwareKeyboard.instance.isAltPressed;

  @override
  Set<LogicalKeyboardKey> get logicalKeysPressed =>
      HardwareKeyboard.instance.logicalKeysPressed;
}
