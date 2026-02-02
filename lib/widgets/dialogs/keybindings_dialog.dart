import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../providers/keybindings_provider.dart';
import '../../services/input/side_button_service.dart';
import '../../services/input/keyboard_state_reader.dart';
import '../../services/app/app_services.dart';

/// 快捷键绑定对话框
///
/// 允许用户自定义键盘和鼠标快捷键绑定。
class KeyBindingsDialog extends StatefulWidget {
  const KeyBindingsDialog({
    super.key,
    this.sideButtonService,
    this.keyboardStateReader,
  });

  /// 注入侧键事件源，便于测试或替换默认实现。
  final SideButtonService? sideButtonService;

  /// 注入键盘状态读取器，便于测试或替换默认实现。
  final KeyboardStateReader? keyboardStateReader;

  @override
  State<KeyBindingsDialog> createState() => _KeyBindingsDialogState();
}

class _KeyBindingsDialogState extends State<KeyBindingsDialog> {
  /// 当前正在监听的动作（为 null 表示未处于监听状态）。
  BindableAction? _listeningAction;

  /// 保持键盘焦点以接收按键事件。
  final FocusNode _focusNode = FocusNode();

  /// 最近一次绑定时间，用于抑制重复触发。
  DateTime? _lastBindingTime;

  /// 用于避免清空后立即重新进入监听状态。
  bool _suppressNextListen = false;

  /// 用于忽略“取消”按钮触发的下一次鼠标按下事件。
  bool _ignoreNextPointerDown = false;

  /// 侧键事件流订阅。
  StreamSubscription<SideButtonEvent>? _sideButtonSub;

  /// 键盘状态读取器，提供修饰键状态。
  late final KeyboardStateReader _keyboardStateReader;

  @override
  void dispose() {
    _sideButtonSub?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    _keyboardStateReader =
        widget.keyboardStateReader ?? services.keyboardStateReader;
    final service = widget.sideButtonService ?? services.sideButtonService;
    _sideButtonSub = service.stream.listen(_handleSideButtonStream);
  }

  /// 开始监听按键输入
  void _startListening(BindableAction action) {
    if (_suppressNextListen) {
      _suppressNextListen = false;
      return;
    }
    // 防止鼠标绑定后立即重新触发
    if (_lastBindingTime != null) {
      final elapsed = DateTime.now().difference(_lastBindingTime!);
      if (elapsed.inMilliseconds < 300) {
        return;
      }
    }
    setState(() {
      _listeningAction = action;
    });
    _focusNode.requestFocus();
  }

  /// 停止监听
  void _stopListening() {
    setState(() {
      _listeningAction = null;
    });
  }

  /// 检查是否为修饰键（不允许直接绑定）。
  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt;
  }

  /// 检查是否为锁定类按键（应忽略）。
  bool _isLockKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.numLock ||
        key == LogicalKeyboardKey.capsLock ||
        key == LogicalKeyboardKey.scrollLock;
  }

  /// 处理键盘事件（捕获并写入绑定）。
  void _handleKeyEvent(KeyEvent event) {
    if (_listeningAction == null) return;

    if (event is! KeyDownEvent) return;

    final action = _listeningAction!;
    final sideButton = KeyBindingsProvider.sideButtonFromKey(event.logicalKey);
    if (sideButton != null) {
      final provider = context.read<KeyBindingsProvider>();
      provider.setBinding(action, KeyBinding.mouse(sideButton));
      _lastBindingTime = DateTime.now();
      _stopListening();
      return;
    }

    // 忽略单独的修饰键和锁定键
    if (_isModifierKey(event.logicalKey) || _isLockKey(event.logicalKey)) {
      return;
    }

    final isCtrl = _keyboardStateReader.isControlPressed ||
        _keyboardStateReader.isMetaPressed;
    final isShift = _keyboardStateReader.isShiftPressed;
    final isAlt = _keyboardStateReader.isAltPressed;

    final binding = KeyBinding(
      key: event.logicalKey,
      ctrl: isCtrl,
      shift: isShift,
      alt: isAlt,
    );

    final provider = context.read<KeyBindingsProvider>();
    provider.setBinding(action, binding);
    _stopListening();
  }

  /// 处理鼠标点击事件（用于绑定鼠标按键）。
  void _handlePointerDown(PointerDownEvent event) {
    if (_listeningAction == null) return;
    if (_ignoreNextPointerDown) {
      _ignoreNextPointerDown = false;
      return;
    }

    final action = _listeningAction!;
    final button = KeyBindingsProvider.mouseButtonFromButtons(event.buttons);
    if (button == null) return;

    final provider = context.read<KeyBindingsProvider>();
    provider.setBinding(action, KeyBinding.mouse(button));
    _lastBindingTime = DateTime.now();
    _stopListening();
  }

  /// 处理侧键事件流。
  void _handleSideButtonStream(SideButtonEvent event) {
    if (!event.isDown) return;
    final action = _listeningAction;
    if (action == null) return;
    final provider = context.read<KeyBindingsProvider>();
    provider.setBinding(action, KeyBinding.mouse(event.button));
    _lastBindingTime = DateTime.now();
    _stopListening();
  }

  /// 处理滚轮事件
  void _handleScroll(PointerSignalEvent event) {
    if (_listeningAction == null) return;
    if (event is! PointerScrollEvent) return;

    // 仅处理缩放操作绑定
    final action = _listeningAction!;
    if (action != BindableAction.zoomIn && action != BindableAction.zoomOut) {
      return;
    }

    ScrollActionType scrollAction;
    if (event.scrollDelta.dy < 0) {
      scrollAction = ScrollActionType.scrollUp;
    } else {
      scrollAction = ScrollActionType.scrollDown;
    }

    final provider = context.read<KeyBindingsProvider>();
    provider.setBinding(action, KeyBinding.scroll(scrollAction));
    _stopListening();
  }

  @override
  Widget build(BuildContext context) {
    final keyBindingsProvider = context.watch<KeyBindingsProvider>();

    final l10n = AppLocalizations.of(context)!;

    // 按类别分组
    final Map<String, List<BindableAction>> categories = {};
    for (final action in BindableAction.values) {
      final category = KeyBindingsProvider.getActionCategory(action, l10n);
      categories.putIfAbsent(category, () => []).add(action);
    }

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerSignal: _handleScroll,
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Dialog(
          backgroundColor: AppTheme.getCardColor(context),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 550,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(keyBindingsProvider),
                _buildContent(categories, keyBindingsProvider),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(KeyBindingsProvider keyBindingsProvider) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Icon(Icons.keyboard, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(
            l10n.keyBindingsTitle,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // 重置按钮
          TextButton.icon(
            onPressed: () => _showResetConfirmDialog(keyBindingsProvider),
            icon: const Icon(Icons.restore, size: 18),
            label: Text(l10n.resetToDefault),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  /// 显示重置确认对话框
  Future<void> _showResetConfirmDialog(
      KeyBindingsProvider keyBindingsProvider) async {
    final l10n = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text(l10n.resetKeyBindingsTitle,
            style: TextStyle(color: AppTheme.getTextPrimary(context))),
        content: Text(l10n.resetKeyBindingsMsg,
            style: TextStyle(color: AppTheme.getTextSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(l10n.reset, style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await keyBindingsProvider.resetToDefault();
    }
  }

  /// 构建绑定列表内容
  Widget _buildContent(Map<String, List<BindableAction>> categories,
      KeyBindingsProvider keyBindingsProvider) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in categories.entries) ...[
              _buildCategorySection(
                  entry.key, entry.value, keyBindingsProvider),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  /// 获取监听提示文本
  String _getListeningHint(BindableAction action, AppLocalizations l10n) {
    if (action == BindableAction.zoomIn || action == BindableAction.zoomOut) {
      return l10n.scrollOrPressKey;
    }
    return l10n.pressKeyOrMouseButton;
  }

  /// 构建类别区域
  Widget _buildCategorySection(String category, List<BindableAction> actions,
      KeyBindingsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.getElevatedColor(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.getBorderColor(context)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: AppTheme.getBorderColor(context)),
                _buildBindingRow(actions[i], provider),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 构建绑定行
  Widget _buildBindingRow(BindableAction action, KeyBindingsProvider provider) {
    final binding = provider.getBinding(action);
    final isListening = _listeningAction == action;
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: () => _startListening(action),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: isListening
            ? BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    KeyBindingsProvider.getActionDescription(action, l10n),
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  ),
                  // 监听时显示提示
                  if (isListening)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _getListeningHint(action, l10n),
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // 绑定显示或取消按钮
            if (isListening)
              _buildListeningIndicator(l10n)
            else
              _buildBindingDisplay(binding, provider, action, l10n),
          ],
        ),
      ),
    );
  }

  /// 构建监听中指示器
  Widget _buildListeningIndicator(AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Listener(
          onPointerDown: (_) {
            _ignoreNextPointerDown = true;
          },
          child: TextButton(
            onPressed: _stopListening,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: Text(l10n.cancel),
          ),
        ),
      ],
    );
  }

  /// 构建绑定显示
  Widget _buildBindingDisplay(KeyBinding binding, KeyBindingsProvider provider,
      BindableAction action, AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.getBackground(context),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.getBorderColor(context)),
          ),
          child: Text(
            binding.getDisplayName(l10n),
            style: TextStyle(
              color: binding.isNone
                  ? AppTheme.getTextMuted(context)
                  : AppTheme.getTextPrimary(context),
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 8),
        // 清除按钮
        IconButton(
          onPressed: () {
            _suppressNextListen = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _suppressNextListen = false;
            });
            provider.clearBinding(action);
          },
          icon: Icon(
            Icons.close,
            size: 18,
            color: binding.isNone
                ? AppTheme.getTextMuted(context).withValues(alpha: 0.3)
                : AppTheme.getTextMuted(context),
          ),
          tooltip: l10n.clearBinding,
          splashRadius: 16,
        ),
      ],
    );
  }
}
