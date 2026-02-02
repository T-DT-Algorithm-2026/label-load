import 'dart:async';

import 'package:flutter/services.dart';

import '../../providers/keybindings_provider.dart';

/// 侧键事件（浏览器后退/前进）
class SideButtonEvent {
  final MouseButton button;
  final bool isDown;

  const SideButtonEvent(this.button, this.isDown);
}

/// 侧键事件流服务
///
/// 通过 MethodChannel 接收原生侧键消息并转换为 [SideButtonEvent]。
class SideButtonService {
  SideButtonService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static final SideButtonService instance = SideButtonService._();

  final MethodChannel _channel = const MethodChannel('side_buttons');
  final StreamController<SideButtonEvent> _controller =
      StreamController<SideButtonEvent>.broadcast();

  /// 侧键事件流（广播）
  Stream<SideButtonEvent> get stream => _controller.stream;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'sideButton') return;
    final arg = call.arguments;
    if (arg is String) {
      if (arg == 'back') {
        _controller.add(const SideButtonEvent(MouseButton.back, true));
      } else if (arg == 'forward') {
        _controller.add(const SideButtonEvent(MouseButton.forward, true));
      }
      return;
    }
    if (arg is! Map) return;
    final button = arg['button'];
    final state = arg['state'];
    if (button is! String || state is! String) return;
    final isDown = state == 'down';
    if (button == 'back') {
      _controller.add(SideButtonEvent(MouseButton.back, isDown));
    } else if (button == 'forward') {
      _controller.add(SideButtonEvent(MouseButton.forward, isDown));
    }
  }
}
